// Receipt list and the export buttons, used by both admin and resident.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../services/doc_files.dart';
import '../../widgets/widgets.dart';
import 'document_viewer_screen.dart';

IconData payIcon(String method) {
  final m = method.toLowerCase();
  if (m.contains('bank')) return Icons.account_balance_outlined;
  if (m.contains('gcash') || m.contains('maya')) return Icons.smartphone_rounded;
  if (m.contains('office') || m.contains('cash') || m.contains('check')) return Icons.storefront_outlined;
  return Icons.payments_outlined;
}

/// Opens a receipt in the document viewer (download as Word or Excel from there).
void openReceipt(BuildContext context, PaymentRecord p) {
  go(
    context,
    DocViewer(DocItem(
      'Receipt ${p.receiptNo}',
      'Finance',
      p.date,
      live: () => receiptBlocks(p),
    )),
  );
}

/// A list of receipts; tapping one opens it.
class ReceiptList extends StatelessWidget {
  final List<PaymentRecord> list;
  final bool showUnit;
  const ReceiptList(this.list, {super.key, this.showUnit = false});

  @override
  Widget build(BuildContext context) {
    if (list.isEmpty) return const EmptyBox('No receipts yet.', icon: Icons.receipt_long_outlined);
    return Column(
      children: [
        for (final p in list)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: RCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              onTap: () => openReceipt(context, p),
              child: Row(
                children: [
                  const IconBadge(Icons.receipt_long_outlined, accent: true),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(showUnit ? '${p.unit} · ${p.payer}' : p.receiptNo,
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(
                          showUnit
                              ? '${p.receiptNo} · ${p.method} · ${p.date}'
                              : '${p.method} · ${p.date}',
                          style: TextStyle(color: muted(context), fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(peso(p.amount), style: hd(15)),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Download buttons for a whole payment history (Excel and Word).
class HistoryExportButtons extends StatelessWidget {
  final String title;
  final List<PaymentRecord> Function() list;
  const HistoryExportButtons({super.key, required this.title, required this.list});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        FilledButton.tonalIcon(
          onPressed: () => runSave(context, 'Excel file', () => exportXlsx(title, paymentHistoryBlocks(title, list()))),
          icon: const Icon(Icons.table_chart_outlined),
          label: const Text('History (Excel)'),
        ),
        FilledButton.tonalIcon(
          onPressed: () => runSave(context, 'Word file', () => exportDocx(title, paymentHistoryBlocks(title, list()))),
          icon: const Icon(Icons.description_outlined),
          label: const Text('History (Word)'),
        ),
      ],
    );
  }
}

/// The bytes of a payment photo kept as a "data:image/...;base64,..." text (null when it cannot be read).
Uint8List? proofImageBytes(String dataUrl) {
  if (dataUrl.isEmpty) return null;
  try {
    final i = dataUrl.indexOf(',');
    return base64Decode(i >= 0 ? dataUrl.substring(i + 1) : dataUrl);
  } catch (_) {
    return null;
  }
}

/// Turns a picture into the text kept with a payment (so the website can show it too).
String proofImageText(Uint8List bytes) {
  final jpeg = bytes.length > 2 && bytes[0] == 0xFF && bytes[1] == 0xD8;
  return 'data:image/${jpeg ? 'jpeg' : 'png'};base64,${base64Encode(bytes)}';
}

/// Opens the photo attached to a payment, full size.
void showProofImage(BuildContext context, PaymentProof p) {
  final b = proofImageBytes(p.image);
  if (b == null) return;
  showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
            child: Row(children: [
              Expanded(child: Text('Payment photo · ${p.unit}', style: const TextStyle(fontWeight: FontWeight.w800))),
              IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded)),
            ]),
          ),
          Flexible(child: InteractiveViewer(child: Image.memory(b, fit: BoxFit.contain))),
        ],
      ),
    ),
  );
}
