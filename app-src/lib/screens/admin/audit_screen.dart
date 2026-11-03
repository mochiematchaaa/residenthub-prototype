// ADMIN page: Audit trail.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../services/audit_trail.dart';
import '../../services/doc_files.dart';
import '../../widgets/widgets.dart';
import '../shared/document_viewer_screen.dart';

/// Administrator: a locked record of who added, changed or deleted what, and when.
/// Entries are written by the database and cannot be edited or removed from the app.
class AdminAudit extends StatefulWidget {
  const AdminAudit({super.key});

  @override
  State<AdminAudit> createState() => _AdminAuditState();
}

class _AdminAuditState extends State<AdminAudit> {
  static const _size = 20;
  final _who = TextEditingController();
  Timer? _debounce;
  String _kind = '';
  DateTime? _from, _to;
  int _page = 0;
  bool _loading = true;
  String? _error;
  List<AuditEntry> _rows = [];
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _who.dispose();
    super.dispose();
  }

  DateTime? get _toEnd => _to == null ? null : DateTime(_to!.year, _to!.month, _to!.day, 23, 59, 59, 999);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await loadAudit(kind: _kind, who: _who.text, from: _from, to: _toEnd, page: _page, size: _size);
      if (!mounted) return;
      final pages = pageCount(r.total, _size);
      if (_page > pages - 1 && r.total > 0) {
        _page = pages - 1;
        await _load();
        return;
      }
      setState(() {
        _rows = r.rows;
        _total = r.total;
        _loading = false;
      });
    } catch (e) {
      debugPrint('ResidentHub audit trail: $e');
      if (!mounted) return;
      setState(() {
        _error = 'Could not load the audit trail. Check your connection and try again.';
        _loading = false;
      });
    }
  }

  void _filterChanged() {
    _page = 0;
    _load();
  }

  Future<void> _pickDate(bool from) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: (from ? _from : _to) ?? now,
      firstDate: DateTime(2024),
      lastDate: DateTime(now.year + 1),
    );
    if (d == null) return;
    _from = from ? d : _from;
    _to = from ? _to : d;
    _filterChanged();
  }

  Future<bool> _export() async {
    final r = await loadAudit(kind: _kind, who: _who.text, from: _from, to: _toEnd, page: 0, size: 2000);
    return exportXlsx('Audit trail', [
      const DocBlock.h1('Audit trail'),
      const DocBlock.p('City Residences Condominium Corporation'),
      DocBlock.table([
        const ['When', 'Who', 'Role', 'Action', 'Type', 'Record', 'Changes'],
        for (final e in r.rows)
          [
            '${shortDate(e.at)} ${TimeOfDay.fromDateTime(e.at).format(context)}',
            e.actor,
            e.role,
            e.verb,
            e.kindLabel,
            e.where,
            e.changes.map((c) => c.before == null ? '${c.field}: ${c.after}' : '${c.field}: ${c.before} -> ${c.after}').join('; '),
          ],
      ]),
    ]);
  }

  void _details(AuditEntry e) {
    String pretty(Map<String, dynamic>? v) => v == null ? '—' : const JsonEncoder.withIndent('  ').convert(v);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (ctx, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          children: [
            Text('${e.verb} · ${e.kindLabel}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 4),
            Text('${e.actor.isEmpty ? '—' : e.actor}${e.role.isEmpty ? '' : ' (${e.role})'} · ${shortDate(e.at)} ${TimeOfDay.fromDateTime(e.at).format(ctx)}',
                style: TextStyle(color: muted(ctx))),
            if (e.where.isNotEmpty) Text(e.where, style: TextStyle(color: muted(ctx))),
            const SizedBox(height: 14),
            if (e.changes.isNotEmpty) ...[
              const Text('What changed', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              for (final c in e.changes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(c.before == null ? '${c.field}: ${c.after}' : '${c.field}: ${c.before}  →  ${c.after}'),
                ),
              const SizedBox(height: 12),
            ],
            const Text('Before', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            SelectableText(pretty(e.oldValue), style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            const SizedBox(height: 12),
            const Text('After', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            SelectableText(pretty(e.newValue), style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            const SizedBox(height: 12),
            Text('Entry #${e.id}', style: TextStyle(color: muted(ctx), fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Tone _tone(String action) => switch (action) {
        'INSERT' => Tone.good,
        'DELETE' => Tone.bad,
        _ => Tone.warn,
      };

  @override
  Widget build(BuildContext context) {
    final kinds = auditKinds.keys.toList()..sort((a, b) => auditKindLabel(a).compareTo(auditKindLabel(b)));
    final filtered = _kind.isNotEmpty || _who.text.trim().isNotEmpty || _from != null || _to != null;
    return SubPage(
      title: 'Audit trail',
      subtitle: 'A locked record of who added, changed or deleted what, and when. No one can edit or remove an entry.',
      children: [
        RCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                key: ValueKey(_kind),
                initialValue: _kind,
                decoration: const InputDecoration(labelText: 'What'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('Everything')),
                  for (final k in kinds) DropdownMenuItem(value: k, child: Text(auditKindLabel(k))),
                ],
                onChanged: (v) {
                  _kind = v ?? '';
                  _filterChanged();
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _who,
                decoration: const InputDecoration(labelText: 'Who', hintText: 'Name of the person'),
                onChanged: (_) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 350), _filterChanged);
                },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDate(true),
                      icon: const Icon(Icons.event_rounded, size: 18),
                      label: Text(_from == null ? 'From' : shortDate(_from!)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDate(false),
                      icon: const Icon(Icons.event_rounded, size: 18),
                      label: Text(_to == null ? 'To' : shortDate(_to!)),
                    ),
                  ),
                ],
              ),
              if (filtered)
                TextButton(
                  onPressed: () {
                    _who.clear();
                    _kind = '';
                    _from = null;
                    _to = null;
                    _filterChanged();
                  },
                  child: const Text('Clear filters'),
                ),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(child: Text('$_total entries', style: TextStyle(color: muted(context), fontSize: 13))),
            IconButton(tooltip: 'Refresh', onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
          ],
        ),
        if (_error != null)
          RCard(child: Text(_error!, style: const TextStyle(color: Color(0xFFA02B1D), fontWeight: FontWeight.w600)))
        else if (_loading && _rows.isEmpty)
          const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
        else if (_rows.isEmpty)
          EmptyBox(filtered ? 'Nothing matches those filters.' : 'Nothing has been recorded yet.', icon: Icons.shield_outlined)
        else ...[
          OutlinedButton.icon(
            onPressed: () => runSave(context, 'Excel file', _export),
            icon: const Icon(Icons.download_rounded),
            label: const Text('Export to Excel'),
          ),
          Opacity(
            opacity: _loading ? 0.5 : 1,
            child: RCard(
              child: Column(
                children: [
                  for (final e in _rows)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      onTap: () => _details(e),
                      title: Row(
                        children: [
                          Pill(e.verb, tone: _tone(e.action)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(e.kindLabel, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text('${e.actor.isEmpty ? '—' : e.actor} · ${AppState.ago(e.at)}${e.where.isEmpty ? '' : ' · ${e.where}'}'),
                          for (final c in e.changes.take(2))
                            Text(c.before == null ? '${c.field}: ${c.after}' : '${c.field}: ${c.before} → ${c.after}',
                                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5)),
                        ],
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                    ),
                ],
              ),
            ),
          ),
          PagerBar(
            page: _page,
            per: _size,
            total: _total,
            onPage: (p) {
              _page = p;
              _load();
            },
          ),
        ],
      ],
    );
  }
}
