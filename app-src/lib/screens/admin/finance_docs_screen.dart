// ADMIN page: Finance documents (collection report, statement of account).

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../services/doc_files.dart';
import '../../widgets/widgets.dart';
import '../shared/document_viewer_screen.dart';
import '../shared/payment_widgets.dart';

/// Finance documents: kept apart from the community documents because they hold
/// client records (dues, payments, receipts and reports).
class AdminFinanceDocs extends StatelessWidget {
  const AdminFinanceDocs({super.key});

  Future<void> _import(BuildContext context) async {
    ImportedFile? picked;
    try {
      picked = await pickDocument();
    } on FormatException catch (e) {
      if (context.mounted) msg(context, e.message);
      return;
    } catch (_) {
      if (context.mounted) msg(context, 'Could not open that file.');
      return;
    }
    if (picked == null || !context.mounted) return;
    final file = picked;
    showFormSheet(
      context,
      title: 'Add finance document',
      subtitle: '"${file.name}.${file.ext}" is saved under Finance documents, apart from the community documents.',
      fields: [FieldSpec('name', 'Title', initial: file.name)],
      toggles: const [ToggleSpec('share', 'Also show to residents', false)],
      submit: 'Add document',
      onSubmit: (v) {
        final n = (v['name'] as String).trim();
        if (n.isEmpty) return 'Enter a title.';
        return app.addDoc(DocItem(
          n,
          'Finance',
          'Added ${shortDate(DateTime.now()).split(',').first}',
          audience: v['share'] == true ? 'all' : 'admin',
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
        final docs = app.financeDocs;
        return SubPage(
          title: 'Finance documents',
          subtitle: 'Client records, payments, receipts and reports. Kept separate from the community documents.',
          fab: FloatingActionButton.extended(
            backgroundColor: lav,
            foregroundColor: ink,
            icon: const Icon(Icons.upload_file_rounded),
            label: const Text('Import file'),
            onPressed: () => _import(context),
          ),
          children: [
            PastelCard(
              color: Pastel.mint,
              child: Row(
                children: [
                  const IconBadge(Icons.lock_outline_rounded, accent: true),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${docs.length} documents · ${app.payments.length} receipts', style: hd(18, color: ink)),
                        const SizedBox(height: 4),
                        const Text('Files you import here are for the administrator only, unless you choose to show them to residents.',
                            style: TextStyle(color: inkSoft, fontSize: 12.5, height: 1.4)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: () => runSave(context, 'Finance document list', () => exportXlsx('Finance document list', docIndexBlocks(docs))),
                  icon: const Icon(Icons.table_chart_outlined),
                  label: const Text('Export list (Excel)'),
                ),
                OutlinedButton.icon(
                  onPressed: () => runSave(context, 'Finance document list', () => exportDocx('Finance document list', docIndexBlocks(docs))),
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('Export list (Word)'),
                ),
              ],
            ),
            Text('Documents', style: hd(18)),
            if (docs.isEmpty) const EmptyBox('No finance documents yet.', icon: Icons.folder_open_rounded),
            for (final d in docs)
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
                      final ok = await confirmDialog(context, 'Remove document?', '"${d.name}" will be removed from Finance documents.',
                          confirm: 'Remove', destructive: true);
                      if (ok) app.removeDoc(d);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'word', child: Text('Download as Word')),
                    const PopupMenuItem(value: 'excel', child: Text('Download as Excel')),
                    if (!d.isLive) const PopupMenuItem(value: 'delete', child: Text('Remove')),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Text('Receipts', style: hd(18)),
            ReceiptList(app.payments, showUnit: true),
            if (app.payments.isNotEmpty)
              HistoryExportButtons(title: 'Payment history', list: () => app.payments),
          ],
        );
      },
    );
  }
}
