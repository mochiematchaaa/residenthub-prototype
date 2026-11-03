// Audit trail: a locked record of who added, changed or deleted what, and when.
//
// On the real system the DATABASE writes every line (triggers on the records and accounts tables), so nothing in the app
// can skip, edit or delete an entry. The app only reads them, one page at a time, and only for the administrator.
// In the demo and the prototype there is no database, so DemoAudit keeps the same kind of list in memory.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/core.dart';
import 'demo.dart' show kDemo;

/// Plain-words names for the kinds of records.
const Map<String, String> auditKinds = {
  'account': 'Resident account',
  'unit': 'Unit',
  'due': 'Charge / due',
  'proof': 'Payment',
  'payment': 'Payment',
  'slot': 'Facility slot',
  'booking': 'Facility booking',
  'announcement': 'Announcement',
  'request': 'Parking request',
  'renewal': 'Parking renewal',
  'grievance': 'Complaint',
  'equipment': 'Equipment',
  'poll': 'Poll',
  'vote': 'Vote',
  'mtype': 'Maintenance type',
  'mtask': 'Maintenance task',
  'mnotice': 'Maintenance notice',
  'mclosure': 'Maintenance closure',
  'statusUpdate': 'Unit status update',
  'expense': 'Expense',
  'staff': 'Staff',
  'fblock': 'Facility block',
  'event': 'Event',
  'rsvp': 'RSVP',
  'walkin': 'Walk-in',
  'doc': 'Document',
  'setting': 'Setting',
};

String auditKindLabel(String k) => auditKinds[k] ?? (k.isEmpty ? 'Record' : '${k[0].toUpperCase()}${k.substring(1)}');

const _hidden = {'id', 'updated_at', 'at', 'createdAt'};
const _secret = ['image', 'photo', 'proofImage', 'pw', 'password'];

/// One changed field: [before] is null for a new or deleted record.
class AuditChange {
  final String field;
  final String? before;
  final String after;
  const AuditChange(this.field, this.before, this.after);
}

class AuditEntry {
  final int id;
  final DateTime at;
  final String actor, role, action, kind, recordId, unit;
  final Map<String, dynamic>? oldValue, newValue;
  const AuditEntry({
    required this.id,
    required this.at,
    required this.actor,
    required this.role,
    required this.action,
    required this.kind,
    required this.recordId,
    required this.unit,
    this.oldValue,
    this.newValue,
  });

  factory AuditEntry.fromJson(Map<String, dynamic> j) {
    Map<String, dynamic>? m(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : null;
    String s(dynamic v) => v == null ? '' : '$v';
    return AuditEntry(
      id: (j['id'] as num?)?.toInt() ?? 0,
      at: DateTime.tryParse(s(j['at']))?.toLocal() ?? DateTime.now(),
      actor: s(j['actor_name']),
      role: s(j['actor_role']),
      action: s(j['action']),
      kind: s(j['kind']),
      recordId: s(j['record_id']),
      unit: s(j['unit']),
      oldValue: m(j['old_value']),
      newValue: m(j['new_value']),
    );
  }

  String get verb => switch (action) {
        'INSERT' => 'Added',
        'UPDATE' => 'Changed',
        'DELETE' => 'Deleted',
        _ => action,
      };

  String get kindLabel => auditKindLabel(kind);

  /// "Unit 3B · 1042", without the parts that are empty.
  String get where => [
        if (unit.isNotEmpty && unit != '__admin') unit,
        if (kind != 'account' && recordId.isNotEmpty) recordId,
      ].join(' · ');

  static String _label(String k) {
    final s = k.replaceAll('_', ' ').replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}').toLowerCase();
    return s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
  }

  static String _val(dynamic v) {
    if (v == null || v == '') return '(empty)';
    final s = v is Map || v is List ? jsonEncode(v) : '$v';
    return s.length > 60 ? '${s.substring(0, 57)}…' : s;
  }

  /// The "Field: before → after" lines.
  List<AuditChange> get changes {
    final o = oldValue ?? const <String, dynamic>{}, n = newValue ?? const <String, dynamic>{};
    final out = <AuditChange>[];
    if (action == 'UPDATE') {
      for (final k in {...o.keys, ...n.keys}) {
        if (_hidden.contains(k)) continue;
        if (jsonEncode(o[k]) != jsonEncode(n[k])) out.add(AuditChange(_label(k), _val(o[k]), _val(n[k])));
      }
      return out;
    }
    final src = action == 'INSERT' ? n : o;
    for (final e in src.entries) {
      if (_hidden.contains(e.key) || e.value == null || e.value == '' || e.value is Map || e.value is List) continue;
      out.add(AuditChange(_label(e.key), null, _val(e.value)));
    }
    return out;
  }
}

class AuditPageData {
  final List<AuditEntry> rows;
  final int total;
  const AuditPageData(this.rows, this.total);
}

/// Reads one page of the audit trail. Real system: from the database (the administrator's sign-in decides what can be read).
Future<AuditPageData> loadAudit({String kind = '', String who = '', DateTime? from, DateTime? to, int page = 0, int size = 20}) async {
  if (kDemo) return DemoAudit.query(kind: kind, who: who, from: from, to: to, page: page, size: size);
  var q = Supabase.instance.client.from('audit_log').select();
  if (kind.isNotEmpty) q = q.eq('kind', kind);
  if (who.trim().isNotEmpty) q = q.ilike('actor_name', '%${who.trim()}%');
  if (from != null) q = q.gte('at', from.toUtc().toIso8601String());
  if (to != null) q = q.lte('at', to.toUtc().toIso8601String());
  final res = await q
      .order('at', ascending: false)
      .order('id', ascending: false)
      .range(page * size, page * size + size - 1)
      .count(CountOption.exact);
  final rows = [for (final r in res.data) AuditEntry.fromJson(Map<String, dynamic>.from(r))];
  return AuditPageData(rows, res.count);
}

/// Demo and prototype only: notices every change in the in-memory data and writes it down, like the database does.
class DemoAudit {
  static final List<AuditEntry> _entries = [];
  static Map<String, CRow> _snap = {};
  static VoidCallback? _listener;
  static const _skip = {'activity', 'tempcred'};

  /// Called when a demo session starts: the list starts empty and the current data is the starting point.
  static void begin() {
    _entries.clear();
    _snap = _take();
    if (_listener != null) app.removeListener(_listener!);
    _listener = _check;
    app.addListener(_listener!);
  }

  static Map<String, CRow> _take() => {for (final r in exportRows(app)) r.key: r};

  static Map<String, dynamic> _clean(Map<String, dynamic> v) {
    final c = Map<String, dynamic>.from(jsonDecode(jsonEncode(v)) as Map);
    for (final k in _secret) {
      c.remove(k);
    }
    return c;
  }

  static void _add(String action, CRow r, Map<String, dynamic>? o, Map<String, dynamic>? n) {
    final admin = app.role == Role.admin;
    _entries.insert(
      0,
      AuditEntry(
        id: (_entries.isEmpty ? 0 : _entries.first.id) + 1,
        at: DateTime.now(),
        actor: admin ? app.adminName : (app.me?.name ?? 'Resident'),
        role: admin ? 'admin' : 'resident',
        action: action,
        kind: r.kind,
        recordId: r.id,
        unit: r.unit,
        oldValue: o == null ? null : _clean(o),
        newValue: n == null ? null : _clean(n),
      ),
    );
    if (_entries.length > 1500) _entries.removeRange(1500, _entries.length);
  }

  static void _check() {
    final now = _take();
    for (final e in now.entries) {
      final r = e.value;
      if (_skip.contains(r.kind)) continue;
      final old = _snap[e.key];
      if (old == null) {
        _add('INSERT', r, null, r.value);
      } else if (canonJson(old.value) != canonJson(r.value) || old.unit != r.unit) {
        _add('UPDATE', r, old.value, r.value);
      }
    }
    for (final e in _snap.entries) {
      if (!now.containsKey(e.key) && !_skip.contains(e.value.kind)) _add('DELETE', e.value, e.value.value, null);
    }
    _snap = now;
  }

  static AuditPageData query({String kind = '', String who = '', DateTime? from, DateTime? to, int page = 0, int size = 20}) {
    final w = who.trim().toLowerCase();
    final all = _entries.where((e) {
      if (kind.isNotEmpty && e.kind != kind) return false;
      if (w.isNotEmpty && !e.actor.toLowerCase().contains(w)) return false;
      if (from != null && e.at.isBefore(from)) return false;
      if (to != null && e.at.isAfter(to)) return false;
      return true;
    }).toList();
    return AuditPageData(all.skip(page * size).take(size).toList(), all.length);
  }
}
