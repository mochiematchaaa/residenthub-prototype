// Shows a document: the tile in the list and the full viewer.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../services/doc_files.dart';
import '../../widgets/widgets.dart';

IconData docIcon(String cat) => switch (cat) {
      'Finance' => Icons.payments_outlined,
      'Form' => Icons.assignment_outlined,
      'Notice' => Icons.campaign_outlined,
      'Minutes' => Icons.event_note_outlined,
      'Policy' => Icons.gavel_rounded,
      _ => Icons.description_outlined,
    };

/// Runs a save/export action and tells the user how it went.
Future<void> runSave(BuildContext context, String label, Future<bool> Function() action) async {
  try {
    final ok = await action();
    if (context.mounted && ok) msg(context, '$label saved.');
  } catch (_) {
    if (context.mounted) msg(context, 'Could not save the file. Please try again.');
  }
}

/// One row in a document list (used by the resident and admin screens).
class DocTile extends StatelessWidget {
  final DocItem doc;
  final VoidCallback onTap;
  final Widget? trailing;
  const DocTile({super.key, required this.doc, required this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    return RCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: onTap,
      child: Row(
        children: [
          IconBadge(docIcon(doc.cat), accent: true),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doc.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('${doc.cat} · ${doc.date}',
                    style: TextStyle(color: muted(context), fontSize: 12.5)),
              ],
            ),
          ),
          trailing ?? const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

/// Opens a document: shows its content and lets the user download it as Word or Excel.
class DocViewer extends StatelessWidget {
  final DocItem doc;
  const DocViewer(this.doc, {super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final blocks = doc.blocks;
        final Uint8List? raw = doc.raw;
        return SubPage(
          title: 'Document',
          children: [
            PastelCard(
              color: doc.cat == 'Finance' ? Pastel.mint : Pastel.lavender,
              child: Row(
                children: [
                  IconBadge(docIcon(doc.cat), accent: true),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(doc.name, style: hd(20, color: ink)),
                        const SizedBox(height: 4),
                        Text('${doc.cat} · ${doc.date}',
                            style: const TextStyle(color: inkSoft, fontSize: 12.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            RCard(
              padding: const EdgeInsets.all(18),
              child: DocBody(blocks),
            ),
            RCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Download', style: hd(17)),
                  const SizedBox(height: 4),
                  Text('Save a copy to open in Word or Excel.', style: TextStyle(color: muted(context), fontSize: 12.5)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: () => runSave(context, 'Word file', () => exportDocx(doc.name, blocks)),
                        icon: const Icon(Icons.description_outlined),
                        label: const Text('Word (.docx)'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => runSave(context, 'Excel file', () => exportXlsx(doc.name, blocks)),
                        icon: const Icon(Icons.table_chart_outlined),
                        label: const Text('Excel (.xlsx)'),
                      ),
                      if (raw != null)
                        OutlinedButton.icon(
                          onPressed: () => runSave(
                              context, 'File', () => saveBytes('${safeFileName(doc.name)}.${doc.ext.isEmpty ? 'bin' : doc.ext}', raw)),
                          icon: const Icon(Icons.download_rounded),
                          label: Text('Original (.${doc.ext})'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Renders document blocks: headings, paragraphs, bullets and tables.
class DocBody extends StatelessWidget {
  final List<DocBlock> blocks;
  const DocBody(this.blocks, {super.key});

  @override
  Widget build(BuildContext context) {
    if (blocks.isEmpty) return const EmptyBox('This document is empty.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final b in blocks) _block(context, b),
      ],
    );
  }

  Widget _block(BuildContext context, DocBlock b) {
    switch (b.kind) {
      case BlockKind.h1:
        return Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(b.text, style: hd(22)));
      case BlockKind.h2:
        return Padding(padding: const EdgeInsets.only(top: 8, bottom: 8), child: Text(b.text, style: hd(16.5)));
      case BlockKind.p:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(b.text, style: const TextStyle(height: 1.5, fontSize: 14.5)),
        );
      case BlockKind.bullet:
        return Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Text('•  ', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
              ),
              Expanded(child: Text(b.text, style: const TextStyle(height: 1.45, fontSize: 14.5))),
            ],
          ),
        );
      case BlockKind.table:
        return Padding(padding: const EdgeInsets.only(bottom: 14), child: _table(context, b.rows));
    }
  }

  Widget _table(BuildContext context, List<List<String>> rows) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final cols = rows.fold<int>(0, (m, r) => math.max(m, r.length));
    final line = muted(context).withAlpha(70);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        border: TableBorder.all(color: line, borderRadius: BorderRadius.circular(10)),
        children: [
          for (var r = 0; r < rows.length; r++)
            TableRow(
              decoration: r == 0 ? BoxDecoration(color: lav.withAlpha(90)) : null,
              children: [
                for (var c = 0; c < cols; c++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: Text(
                        c < rows[r].length ? rows[r][c] : '',
                        style: TextStyle(fontWeight: r == 0 ? FontWeight.w800 : FontWeight.w500, fontSize: 13),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
