// ADMIN page: Documents (upload and list).

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../services/doc_files.dart';
import '../../widgets/widgets.dart';
import '../shared/document_viewer_screen.dart';

class AdminDocs extends StatefulWidget {
  const AdminDocs({super.key});

  @override
  State<AdminDocs> createState() => _AdminDocsState();
}

class _AdminDocsState extends State<AdminDocs> {
  String filter = 'All';

  Future<void> _import() async {
    ImportedFile? picked;
    try {
      picked = await pickDocument();
    } on FormatException catch (e) {
      if (mounted) msg(context, e.message);
      return;
    } catch (_) {
      if (mounted) msg(context, 'Could not open that file.');
      return;
    }
    if (picked == null || !mounted) return;
    final file = picked;
        showFormSheet(
      context,
      title: 'Add to documents',
      subtitle: 'Residents will be able to open "${file.name}.${file.ext}" and download it.',
      fields: [FieldSpec('name', 'Title', initial: file.name)],
      choices: [ChoiceSpec('cat', 'Category', communityCategories, 'Other')],
      submit: 'Add document',
      onSubmit: (v) {
        final n = (v['name'] as String).trim();
        if (n.isEmpty) return 'Enter a title.';
        return app.addDoc(DocItem(
          n,
          v['cat'] as String,
          'Added ${shortDate(DateTime.now()).split(',').first}',
          blocks: file.blocks,
          raw: file.bytes,
          ext: file.ext,
        ));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final all = app.communityDocs;
        final shown = filter == 'All' ? all : all.where((d) => d.cat == filter).toList();
        return SubPage(
          title: 'Community documents',
          subtitle: 'Rules, forms, notices and minutes. Finance records are kept separately under Finance documents.',
          fab: FloatingActionButton.extended(
            backgroundColor: lav,
            foregroundColor: ink,
            icon: const Icon(Icons.upload_file_rounded),
            label: const Text('Import file'),
            onPressed: _import,
          ),
          children: [
            FilterRow(
              options: const ['All', ...communityCategories],
              selected: filter,
              onSelect: (v) => setState(() => filter = v),
            ),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: () => runSave(context, 'Document list',
                      () => exportXlsx('Document list', docIndexBlocks(all))),
                  icon: const Icon(Icons.table_chart_outlined),
                  label: const Text('Export list (Excel)'),
                ),
                OutlinedButton.icon(
                  onPressed: () => runSave(context, 'Document list',
                      () => exportDocx('Document list', docIndexBlocks(all))),
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('Export list (Word)'),
                ),
              ],
            ),
            if (shown.isEmpty) EmptyBox('No $filter documents yet.', icon: Icons.folder_open_rounded),
            for (final d in shown)
              DocTile(
                doc: d,
                onTap: () => go(context, DocViewer(d)),
                trailing: PopupMenuButton<String>(
                  tooltip: 'More',
                  onSelected: (a) async {
                    if (a == 'word') {
                      runSave(context, 'Word file', () => exportDocx(d.name, d.blocks));
                    } else if (a == 'excel') {
                      runSave(context, 'Excel file', () => exportXlsx(d.name, d.blocks));
                    } else if (a == 'delete') {
                      final ok = await confirmDialog(context, 'Remove document?', '"${d.name}" will no longer be visible to residents.',
                          confirm: 'Remove', destructive: true);
                      if (ok) app.removeDoc(d);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'word', child: Text('Download as Word')),
                    PopupMenuItem(value: 'excel', child: Text('Download as Excel')),
                    PopupMenuItem(value: 'delete', child: Text('Remove')),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
