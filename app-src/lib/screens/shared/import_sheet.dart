// "Already have a list?" on every list page: the administrator picks an Excel or CSV file, the app matches its columns,
// shows a preview, and adds all the rows at once. What each row becomes is in import_specs.dart.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../services/doc_files.dart';
import '../../widgets/widgets.dart';
import 'import_specs.dart';

/// A card at the top of a list page. [ids] are the lists that can be imported there (see importSpecs).
class ImportBar extends StatelessWidget {
  final List<String> ids;
  const ImportBar(this.ids, {super.key});

  @override
  Widget build(BuildContext context) {
    return RCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const IconBadge(Icons.upload_file_rounded),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Already have a list? Import it from Excel or CSV instead of typing each row.',
                  style: TextStyle(color: muted(context), fontSize: 13.5, height: 1.35, fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final id in ids)
              OutlinedButton.icon(
                onPressed: () => showImportSheet(context, id),
                icon: const Icon(Icons.upload_file_rounded, size: 18),
                label: Text('Import ${importSpecs[id]!.label}'),
              ),
          ]),
        ],
      ),
    );
  }
}

void showImportSheet(BuildContext context, String id) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ImportSheet(spec: importSpecs[id]!),
  );
}

String _nk(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

String _csvCell(String s) => RegExp(r'[",\n]').hasMatch(s) ? '"${s.replaceAll('"', '""')}"' : s;

String _csv(List<List<String>> rows) => rows.map((r) => r.map(_csvCell).join(',')).join('\r\n');

class _ImportSheet extends StatefulWidget {
  final ImportSpec spec;
  const _ImportSheet({required this.spec});

  @override
  State<_ImportSheet> createState() => _ImportSheetState();
}

class _ImportSheetState extends State<_ImportSheet> {
  ImportedFile? file;
  List<String> headers = [];
  List<List<String>> body = [];
  final Map<String, int> map = {}; // column key -> index in the file, -1 for none
  String? error;
  bool busy = false;
  int? added;
  List<String> skipped = [];
  final run = ImportRun();

  ImportSpec get spec => widget.spec;

  Future<void> _pick() async {
    setState(() => error = null);
    try {
      final f = await pickDocument(allowed: const ['xlsx', 'csv']);
      if (f == null) return;
      final rows = [
        for (final r in f.table)
          if (r.any((c) => c.trim().isNotEmpty)) r,
      ];
      if (rows.length < 2) {
        setState(() => error = 'This file has no rows under the column names. Check that the first row has the names, like the template.');
        return;
      }
      // The row with the most recognisable column names is the header (the file may start with a title).
      var best = 0, bestScore = -1;
      for (var i = 0; i < rows.length && i < 8; i++) {
        final s = _score(rows[i]);
        if (s > bestScore) {
          best = i;
          bestScore = s;
        }
      }
      headers = [for (final c in rows[best]) c.trim()];
      body = rows.sublist(best + 1);
      map.clear();
      final used = <int>{};
      for (final c in spec.cols) {
        final names = {_nk(c.label), _nk(c.key), for (final a in c.al) _nk(a)};
        var found = -1;
        for (var i = 0; i < headers.length; i++) {
          if (!used.contains(i) && names.contains(_nk(headers[i]))) {
            found = i;
            break;
          }
        }
        if (found >= 0) used.add(found);
        map[c.key] = found;
      }
      setState(() => file = f);
    } on FormatException catch (e) {
      setState(() => error = e.message);
    } catch (_) {
      setState(() => error = 'Could not open that file.');
    }
  }

  int _score(List<String> row) {
    var n = 0;
    for (final c in spec.cols) {
      final names = {_nk(c.label), _nk(c.key), for (final a in c.al) _nk(a)};
      if (row.any((h) => names.contains(_nk(h)))) n++;
    }
    return n;
  }

  String _cell(List<String> r, int i) => i < 0 || i >= r.length ? '' : r[i].trim();

  Map<String, String> _values(List<String> r) => {for (final c in spec.cols) c.key: _cell(r, map[c.key] ?? -1)};

  bool get _mappedOk => spec.cols.where((c) => c.req).every((c) => (map[c.key] ?? -1) >= 0);

  List<List<String>> get _rows => [
        for (final r in body)
          if (spec.cols.any((c) => _cell(r, map[c.key] ?? -1).isNotEmpty)) r,
      ];

  String _show(String key, String v) {
    if ((key == 'date' || key == 'due' || key == 'warranty') && RegExp(r'^\d{4,6}(\.\d+)?$').hasMatch(v)) {
      final d = importDate(v);
      if (d != null) return shortDate(d);
    }
    return v;
  }

  Future<void> _go() async {
    final rows = _rows;
    if (rows.isEmpty) return;
    setState(() => busy = true);
    var n = 0;
    final why = <String>[];
    for (var i = 0; i < rows.length; i++) {
      String? r;
      try {
        r = await spec.add(_values(rows[i]), run);
      } catch (_) {
        r = 'Could not be added';
      }
      if (r == null) {
        n++;
      } else {
        why.add('Row ${i + 1}: $r');
      }
    }
    if (!mounted) return;
    setState(() {
      busy = false;
      added = n;
      skipped = why;
    });
  }

  Future<void> _template() async {
    final rows = [
      [for (final c in spec.cols) c.label],
      ...spec.sample,
    ];
    await saveBytes('ResidentHub_${spec.id}_template.csv', Uint8List.fromList(utf8.encode('\uFEFF${_csv(rows)}')));
  }

  Future<void> _passwords() async {
    final rows = [
      ['Name', 'Unit', 'Email', 'Temporary password'],
      ...run.passwords,
    ];
    await saveBytes('ResidentHub_temporary_passwords.csv', Uint8List.fromList(utf8.encode('\uFEFF${_csv(rows)}')));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Import ${spec.label}', style: hd(22)),
            const SizedBox(height: 4),
            Text('Use an Excel (.xlsx) or CSV file. The first row holds the column names.',
                style: TextStyle(color: muted(context), fontSize: 13)),
            if (spec.note.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(spec.note, style: TextStyle(color: muted(context), fontSize: 12.5, height: 1.4)),
            ],
            const SizedBox(height: 14),
            if (added != null) ..._done(context) else if (file == null) ..._start(context) else ..._review(context),
            if (error != null)
              Padding(padding: const EdgeInsets.only(top: 10), child: Text(error!, style: const TextStyle(color: danger, fontSize: 13))),
          ],
        ),
      ),
    );
  }

  List<Widget> _start(BuildContext context) => [
        Text('Columns the file can have', style: TextStyle(color: muted(context), fontSize: 12.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        for (final c in spec.cols)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text('• ${c.label}${c.req ? '  (needed)' : ''}', style: const TextStyle(fontSize: 13.5)),
          ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(onPressed: _pick, icon: const Icon(Icons.folder_open_rounded), label: const Text('Choose Excel or CSV file')),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(onPressed: _template, icon: const Icon(Icons.download_rounded), label: const Text('Download a template to fill in')),
        ),
      ];

  List<Widget> _review(BuildContext context) {
    final rows = _rows;
    final shown = rows.take(5).toList();
    return [
      Row(children: [
        const Icon(Icons.description_outlined, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text('${file!.name}.${file!.ext} · ${rows.length} row${rows.length == 1 ? '' : 's'}', style: const TextStyle(fontWeight: FontWeight.w700))),
        TextButton(onPressed: _pick, child: const Text('Change file')),
      ]),
      const SizedBox(height: 10),
      Text('Match the columns', style: TextStyle(color: muted(context), fontSize: 12.5, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      for (final c in spec.cols)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: DropdownButtonFormField<int>(
            key: ValueKey('${file!.name}-${c.key}-${map[c.key]}'),
            initialValue: map[c.key] ?? -1,
            isExpanded: true,
            decoration: InputDecoration(labelText: '${c.label}${c.req ? ' *' : ''}'),
            items: [
              const DropdownMenuItem(value: -1, child: Text('— not in the file —')),
              for (var i = 0; i < headers.length; i++)
                if (headers[i].isNotEmpty) DropdownMenuItem(value: i, child: Text(headers[i], overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => setState(() => map[c.key] = v ?? -1),
          ),
        ),
      if (!_mappedOk)
        Text('Choose a column for each one marked *.', style: const TextStyle(color: danger, fontSize: 13))
      else ...[
        const SizedBox(height: 4),
        Text(rows.length > shown.length ? 'Preview (first ${shown.length} of ${rows.length})' : 'Preview',
            style: TextStyle(color: muted(context), fontSize: 12.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        for (final r in shown)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(border: Border.all(color: muted(context).withAlpha(60)), borderRadius: BorderRadius.circular(12)),
            width: double.infinity,
            child: Text(
              [
                for (final c in spec.cols)
                  if (_cell(r, map[c.key] ?? -1).isNotEmpty) _show(c.key, _cell(r, map[c.key] ?? -1)),
              ].join('  ·  '),
              style: const TextStyle(fontSize: 13, height: 1.35),
            ),
          ),
      ],
      const SizedBox(height: 14),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: busy || !_mappedOk || rows.isEmpty ? null : _go,
          child: busy
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4))
              : Text('Add ${rows.length} row${rows.length == 1 ? '' : 's'}'),
        ),
      ),
      const SizedBox(height: 6),
      Text('Rows that cannot be added (for example a unit that is not on record) are skipped, and you will see why.',
          style: TextStyle(color: muted(context), fontSize: 12.5, height: 1.4)),
    ];
  }

  List<Widget> _done(BuildContext context) => [
        Row(children: [
          Icon(added! > 0 ? Icons.check_circle_rounded : Icons.info_outline_rounded, color: added! > 0 ? lavDeep : danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              added == 0
                  ? 'Nothing was added.'
                  : '$added row${added == 1 ? '' : 's'} added${skipped.isEmpty ? '.' : ', ${skipped.length} skipped.'}',
              style: hd(17),
            ),
          ),
        ]),
        if (skipped.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('Skipped', style: TextStyle(color: muted(context), fontSize: 12.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          for (final s in skipped.take(30)) Padding(padding: const EdgeInsets.only(bottom: 3), child: Text(s, style: const TextStyle(fontSize: 13))),
          if (skipped.length > 30) Text('…and ${skipped.length - 30} more.', style: TextStyle(color: muted(context), fontSize: 13)),
        ],
        if (run.passwords.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text('${run.passwords.length} account${run.passwords.length == 1 ? '' : 's'} created with a temporary password. Download the list now; the passwords cannot be shown again.',
              style: const TextStyle(fontSize: 13, height: 1.4)),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(onPressed: _passwords, icon: const Icon(Icons.download_rounded), label: const Text('Download passwords (CSV)')),
          ),
        ],
        const SizedBox(height: 14),
        SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))),
      ];
}
