// Keeps AppState and the Supabase database in step: loads rows, saves changes, listens for live updates.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show
        PostgresChangeEvent,
        PostgresChangePayload,
        PostgrestException,
        RealtimeChannel,
        RealtimeSubscribeStatus,
        Supabase,
        SupabaseClient;

import '../core/core.dart';

/// Keeps everything the app shows the same as the shared database (and so the same as the website).
///
/// All the app's data lives in one table (`records`) in Supabase. After sign-in the app reads the
/// rows this account is allowed to see, then listens for changes. Whatever the person changes in
/// the app is sent as soon as it happens. The database decides who may read or write what, so a
/// resident can only ever touch their own unit.

enum CloudState { off, connecting, live, problem }

/// Used to show a short message from anywhere (for example "Not saved: ...").
final GlobalKey<ScaffoldMessengerState> rootMessengerKey = GlobalKey<ScaffoldMessengerState>();

const _kinds = [
  'unit', 'statusUpdate', 'booking', 'grievance', 'proof', 'request', 'rsvp', 'vote', 'activity',
  'due', 'payment', 'expense', 'announcement', 'event', 'poll', 'doc', 'slot', 'setting',
];

/// Loads and saves data to Supabase and listens for live changes.
class CloudSync extends ChangeNotifier {
  static const _table = 'records';

  CloudState state = CloudState.off;
  String detail = '';

  final Map<String, CRow> _known = {}; // what the database holds, as far as we know
  final Map<String, String> _synced = {}; // what the app and the database last agreed on
  RealtimeChannel? _channel;
  bool _ready = false, _pushing = false, _pushAgain = false, _dirtyRemote = false, _pulling = false;
  Timer? _pushTimer, _retryTimer, _refreshTimer;
  int _run = 0; // changes on every sign-in/out so late replies from an old session are ignored
  DateTime? _lastRejected; // stops a refused change from being retried in a loop

  SupabaseClient get _client => Supabase.instance.client;

  void _set(CloudState s, String text) {
    state = s;
    detail = text;
    notifyListeners();
  }

  // ------------------------------------------------------------ start / stop

  /// Called right after a person signed in.
  Future<void> begin() async {
    await end();
    final run = ++_run;
    _set(CloudState.connecting, 'Connecting…');
    app.addListener(_schedulePush);
    _channel = _client
        .channel('residenthub-records-$run')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: _table,
          callback: (p) => _onChange(run, p),
        )
        .subscribe((status, [error]) {
      if (run != _run) return;
      if (status == RealtimeSubscribeStatus.subscribed) {
        if (_ready) unawaited(_pull(run));
      } else if (status == RealtimeSubscribeStatus.channelError ||
          status == RealtimeSubscribeStatus.timedOut) {
        _set(CloudState.problem, 'Live updates paused. Reconnecting…');
      }
    });
    await _pull(run);
    _refreshTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (run == _run && _ready && _pushTimer?.isActive != true && !_pushing) unawaited(_pull(run));
    });
  }

  /// Called when the person signs out.
  Future<void> end() async {
    _run++;
    app.removeListener(_schedulePush);
    _pushTimer?.cancel();
    _retryTimer?.cancel();
    _refreshTimer?.cancel();
    final ch = _channel;
    _channel = null;
    _ready = false;
    _pushing = false;
    _pushAgain = false;
    _dirtyRemote = false;
    _pulling = false;
    _known.clear();
    _synced.clear();
    if (ch != null) {
      try {
        await _client.removeChannel(ch);
      } catch (_) {}
    }
    state = CloudState.off;
    detail = '';
    notifyListeners();
  }

  // ------------------------------------------------------------ reading

  Future<void> _pull(int run) async {
    if (_pulling || run != _run) return;
    // Never read over a change of our own that has not been sent yet.
    if (_pushTimer?.isActive == true || _pushing) {
      _dirtyRemote = true;
      return;
    }
    _pulling = true;
    try {
      final rows = <CRow>[];
      const page = 1000;
      for (var from = 0;; from += page) {
        final data = await _client
            .from(_table)
            .select('kind,id,unit,value')
            .inFilter('kind', _kinds)
            .order('kind')
            .order('id')
            .range(from, from + page - 1);
        for (final r in data) {
          final row = _fromDb(r);
          if (row != null) rows.add(row);
        }
        if (data.length < page) break;
      }
      if (run != _run) return;
      _known.clear();
      _synced.clear();
      for (final r in rows) {
        _known[r.key] = r;
        _synced[r.key] = canonJson(r.value);
      }
      importRows(app, rows);
      app.changed();
      _ready = true;
      _set(CloudState.live, 'Live · connected');
    } catch (e) {
      debugPrint('ResidentHub sync (read): $e');
      if (run != _run) return;
      _set(CloudState.problem, 'Could not read the shared records. Retrying…');
      _retryTimer?.cancel();
      _retryTimer = Timer(const Duration(seconds: 5), () => unawaited(_pull(run)));
    } finally {
      _pulling = false;
    }
  }

  CRow? _fromDb(Map<String, dynamic> r) {
    final kind = r['kind']?.toString();
    final id = r['id']?.toString();
    if (kind == null || id == null || !_kinds.contains(kind)) return null;
    final v = r['value'];
    return CRow(kind, id, (r['unit'] ?? '').toString(),
        v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{});
  }


  /// What a resident may change on a unit record (the database refuses anything else).
  static const _residentUnitKeys = [
    'usage', 'usageStatus', 'usageRemark', 'usageInfo', 'status', 'statusNote', 'statusDate',
    // the household details a resident keeps up to date themselves
    'residents', 'members', 'pets', 'vehicles', 'emergencyName', 'emergencyRelation', 'emergencyPhone', 'selfUpdated', 'selfBy', 'selfLog',
  ];

  /// A unit written on the website may leave out fields the app fills in with a default (name,
  /// contact, type...). Those are not changes, so leave the defaults out when comparing.
  String _unitField(String key, dynamic v) {
    if (v is Map || v is List) {
      final c = canonJson(v);
      return c == '{}' || c == '[]' ? '' : c;
    }
    final t = (v ?? '').toString();
    if (key == 'usage' && t == 'owner') return '';
    if (key == 'status' && t == 'Occupied') return '';
    return t;
  }

  /// The update a resident may send for their unit: what is in the database, plus only the
  /// fields they are allowed to change. Null when nothing they may change was changed.
  CRow? _residentUnitUpdate(CRow want) {
    final base = _known[want.key];
    if (base == null) return null; // a resident can never create a unit
    final changed = [
      for (final k in _residentUnitKeys)
        if (_unitField(k, want.value[k]) != _unitField(k, base.value[k])) k
    ];
    if (changed.isEmpty) return null;
    final merged = Map<String, dynamic>.from(base.value);
    for (final k in changed) {
      final v = want.value[k];
      if (_unitField(k, v).isEmpty) {
        merged.remove(k);
      } else {
        merged[k] = v;
      }
    }
    return CRow(want.kind, want.id, base.unit, merged);
  }

  void _onChange(int run, PostgresChangePayload p) {
    if (run != _run || !_ready) return;
    final isDelete = p.eventType == PostgresChangeEvent.delete;
    final row = _fromDb(isDelete ? p.oldRecord : p.newRecord);
    if (row == null) return;
    if (_pushTimer?.isActive == true || _pushing) {
      // We have a change of our own on its way: send it first, then read everything again.
      _dirtyRemote = true;
      return;
    }
    if (isDelete) {
      _known.remove(row.key);
      _synced.remove(row.key);
    } else {
      _known[row.key] = row;
      _synced[row.key] = canonJson(row.value);
    }
    importRows(app, _known.values);
    app.changed();
  }

  // ------------------------------------------------------------ writing

  void _schedulePush() {
    if (!_ready) return;
    _pushTimer?.cancel();
    _pushTimer = Timer(const Duration(milliseconds: 150), () => unawaited(_pushDiff()));
  }

  bool _canDelete(String kind) => app.role == Role.admin || residentDeletable.contains(kind);

  Future<void> _pushDiff() async {
    final run = _run;
    if (!_ready || app.role == null) return;
    if (_pushing) {
      _pushAgain = true;
      return;
    }
    _pushing = true;
    var rejected = false;
    var repeated = false; // refused twice in a row: do not keep retrying
    var offline = false;
    try {
      final admin = app.role == Role.admin;
      final want = {for (final r in exportRows(app)) r.key: r};
      final inserts = <CRow>[], updates = <CRow>[];
      for (final e in want.entries) {
        if (_synced[e.key] == canonJson(e.value.value)) continue;
        if (!admin && e.value.kind == 'unit') {
          final u = _residentUnitUpdate(e.value);
          if (u != null) updates.add(u);
          continue;
        }
        (_known.containsKey(e.key) ? updates : inserts).add(e.value);
      }
      final deletes = [
        for (final k in _synced.keys)
          if (!want.containsKey(k) && _canDelete(_known[k]?.kind ?? k.split('|').first)) k
      ];

      if (inserts.isNotEmpty) {
        for (var i = 0; i < inserts.length; i += 200) {
          final chunk = inserts.sublist(i, i + 200 > inserts.length ? inserts.length : i + 200);
          try {
            await _client.from(_table).insert([
              for (final r in chunk) {'kind': r.kind, 'id': r.id, 'unit': r.unit, 'value': r.value}
            ]);
            for (final r in chunk) {
              _known[r.key] = r;
              _synced[r.key] = canonJson(r.value);
            }
          } on PostgrestException catch (e) {
            if (e.code != '23505') rethrow;
            // Some of these rows already exist (another device was faster): save them one by one.
            for (final r in chunk) {
              try {
                await _client.from(_table).insert({'kind': r.kind, 'id': r.id, 'unit': r.unit, 'value': r.value});
                _known[r.key] = r;
                _synced[r.key] = canonJson(r.value);
              } on PostgrestException catch (e2) {
                if (e2.code != '23505') rethrow;
                updates.add(r);
              }
            }
          }
        }
      }
      for (final r in updates) {
        await _client.from(_table).update({'unit': r.unit, 'value': r.value}).eq('kind', r.kind).eq('id', r.id);
        _known[r.key] = r;
        _synced[r.key] = canonJson(r.value);
      }
      for (final k in deletes) {
        final i = k.indexOf('|');
        await _client.from(_table).delete().eq('kind', k.substring(0, i)).eq('id', k.substring(i + 1));
        _known.remove(k);
        _synced.remove(k);
      }
      if (run == _run && state != CloudState.live) _set(CloudState.live, 'Live · connected');
    } on PostgrestException catch (e) {
      rejected = true;
      debugPrint('ResidentHub sync (write): ${e.code} ${e.message}');
      final text = switch (e.code) {
        '23505' => 'Someone else already took that.',
        '42501' => 'You do not have permission to do that.',
        _ => e.message,
      };
      final again = _lastRejected != null && DateTime.now().difference(_lastRejected!).inSeconds < 10;
      _lastRejected = DateTime.now();
      if (!again) rootMessengerKey.currentState?.showSnackBar(SnackBar(content: Text('Not saved: $text')));
      if (run == _run) _set(CloudState.problem, 'Not saved · refreshing');
      repeated = again;
    } catch (e) {
      offline = true;
      debugPrint('ResidentHub sync (write): $e');
      if (run == _run) {
        _set(CloudState.problem, 'No connection · will retry');
        _retryTimer?.cancel();
        _retryTimer = Timer(const Duration(seconds: 4), () => unawaited(_pushDiff()));
      }
    } finally {
      _pushing = false;
      if (run == _run) {
        if (_pushAgain) {
          _pushAgain = false;
          unawaited(_pushDiff());
        } else if (rejected) {
          // The database refused the change: show what it really holds (once, so it cannot loop).
          _dirtyRemote = false;
          if (!repeated) unawaited(_pull(run));
        } else if (_dirtyRemote && !offline && _pushTimer?.isActive != true) {
          _dirtyRemote = false;
          unawaited(_pull(run));
        }
      }
    }
  }
}

final CloudSync cloud = CloudSync();

/// A small line that says whether live updates are working.
/// Shows nothing before sign-in.
class CloudStatusLine extends StatelessWidget {
  const CloudStatusLine({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: cloud,
      builder: (context, _) {
        if (cloud.state == CloudState.off) return const SizedBox.shrink();
        final good = cloud.state == CloudState.live;
        final bad = cloud.state == CloudState.problem;
        final color = good
            ? const Color(0xFF2E7D32)
            : bad
                ? const Color(0xFFC62828)
                : const Color(0xFF8A6D00);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(bad ? Icons.sync_problem_rounded : Icons.sync_rounded, size: 16, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text('Database: ${cloud.detail}',
                    style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );
      },
    );
  }
}
