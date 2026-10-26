// RESIDENT page: Finance documents.

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../widgets/widgets.dart';
import '../shared/document_viewer_screen.dart';
import '../shared/payment_widgets.dart';

/// Finance documents: the resident's statement, payment history, receipts and the
/// association's dues schedule and budget. Kept apart from the community documents.
class ResFinanceDocs extends StatelessWidget {
  const ResFinanceDocs({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final docs = app.financeDocs;
        return SubPage(
          title: 'Finance documents',
          subtitle: 'Your statement, payments and receipts, plus the dues schedule and budget. Download any of them as Word or Excel.',
          children: [
            PastelCard(
              color: Pastel.mint,
              child: Row(
                children: [
                  const IconBadge(Icons.lock_outline_rounded, accent: true),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text('${docs.length} documents · ${app.myPayments.length} receipts', style: hd(18, color: ink)),
                  ),
                ],
              ),
            ),
            Text('Documents', style: hd(18)),
            if (docs.isEmpty) const EmptyBox('No finance documents yet.', icon: Icons.folder_open_rounded),
            for (final d in docs) DocTile(doc: d, onTap: () => go(context, DocViewer(d))),
            const SizedBox(height: 4),
            Text('My receipts', style: hd(18)),
            ReceiptList(app.myPayments),
          ],
        );
      },
    );
  }
}
