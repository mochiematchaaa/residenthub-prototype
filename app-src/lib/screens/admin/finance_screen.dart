// ADMIN page: Finance (dues, payments, payment proofs).

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../core/doc_seed.dart';
import '../../services/doc_files.dart';
import '../../widgets/widgets.dart';
import '../shared/import_sheet.dart';
import '../shared/document_viewer_screen.dart';
import '../shared/payment_widgets.dart';
import 'admin_screens.dart';

class AdminFinance extends StatefulWidget {
  const AdminFinance({super.key});

  @override
  State<AdminFinance> createState() => _AdminFinanceState();
}

class _AdminFinanceState extends State<AdminFinance> {
  String filter = 'Unpaid';
  static const _pageSize = 10;
  int page = 0;
  String q = '';
  late final rate = TextEditingController(text: app.motorRate.toStringAsFixed(0));
  late final rateDay = TextEditingController(text: app.motorRateDay == 0 ? '' : app.motorRateDay.toStringAsFixed(0));
  late final duesRate = TextEditingController(text: app.duesRate == 0 ? '' : app.duesRate.toStringAsFixed(0));

  @override
  void dispose() {
    rate.dispose();
    rateDay.dispose();
    duesRate.dispose();
    super.dispose();
  }

  Future<void> _importPayments() async {
    ImportedFile? picked;
    try {
      picked = await pickDocument(allowed: const ['xlsx', 'csv']);
    } on FormatException catch (e) {
      if (mounted) msg(context, e.message);
      return;
    } catch (_) {
      if (mounted) msg(context, 'Could not open that file.');
      return;
    }
    if (picked == null || !mounted) return;
    final rows = picked.table;
    String norm(String s) => s.toLowerCase().replaceAll('unit', '').replaceAll(RegExp(r'[^a-z0-9]'), '');
    final hits = <Due>[
      for (final d in app.dues)
        if (!d.paid && rows.any((r) => r.any((c) => norm(c) == norm(d.unit)))) d,
    ];
    if (hits.isEmpty) {
      msg(context, 'No unpaid units from this file were found. The file needs a column with unit names like "Unit 12A".');
      return;
    }
    final ok = await confirmDialog(
      context,
      'Record ${hits.length} payment${hits.length > 1 ? 's' : ''}?',
      hits.map((d) => '${d.unit} - ${peso(d.amt)}').join('\n'),
      confirm: 'Record',
    );
    if (!ok || !mounted) return;
    for (final d in hits) {
      app.payDue(d.id, method: 'Imported payment list', reference: picked.name);
    }
    if (mounted) msg(context, '${hits.length} payment${hits.length > 1 ? 's' : ''} recorded from the file.');
  }

  /// Another submission (any unit) that used the same payment method and reference number, or null.
  PaymentProof? _duplicateOf(PaymentProof p) {
    if (p.reference.trim().isEmpty || p.reference == '—') return null;
    for (final o in app.proofs) {
      if (o.id != p.id && o.status != 'Rejected' && o.method == p.method && o.reference.toLowerCase() == p.reference.toLowerCase()) return o;
    }
    return null;
  }

  /// Rejects a submission: the administrator gives the reason, and the resident sees it.
  void _reject(PaymentProof p) {
    showFormSheet(
      context,
      title: 'Reject payment details',
      subtitle: '${p.unit} · ${p.method} · Ref. ${p.reference}. Tell the resident what is wrong. They can send the correct details. The rejected submission stays in the record with your reason and gets no receipt.',
      fields: const [FieldSpec('reason', 'Reason', hint: 'e.g. Reference number not found. Please check it.', lines: 3)],
      submit: 'Reject',
      onSubmit: (v) {
        final reason = (v['reason'] as String).trim();
        if (reason.isEmpty) return 'Enter the reason so the resident knows what to correct.';
        app.rejectProof(p, reason);
        return null;
      },
    );
  }

  void _recordPayment(Due d) {
    final methods = [for (final m in app.payMethods) m.name];
    showFormSheet(
      context,
      title: 'Record payment',
      subtitle: '${d.unit} · ${d.name} · ${peso(d.amt)}',
      choices: [ChoiceSpec('method', 'Paid through', methods, methods.first)],
      fields: const [FieldSpec('ref', 'Reference no. (optional)', hint: 'From the payment receipt')],
      submit: 'Record and issue receipt',
      onSubmit: (v) {
        final rec = app.payDue(d.id, method: v['method'] as String, reference: v['ref'] as String);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && rec != null) msg(context, 'Payment recorded. Receipt ${rec.receiptNo} issued.');
        });
        return null;
      },
    );
  }

  void _billDues() {
    final now = DateTime.now();
    showFormSheet(
      context,
      title: 'Bill monthly dues',
      subtitle: 'Adds one charge of ${peso(app.duesRate)} to every unit that has not been billed for this month yet.',
      fields: [
        FieldSpec('period', 'Month', hint: 'e.g. October 2026', initial: app.monthLabel(now)),
        FieldSpec('due', 'Due date (optional)', hint: 'e.g. Oct 15, 2026'),
      ],
      submit: 'Bill all units',
      onSubmit: (v) {
        final err = app.billMonthlyDues(v['period'] as String, v['due'] as String);
        if (err == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => filter = 'Unpaid');
              msg(context, app.lastBilledCount == 0 ? 'Every unit was already billed for that month.' : 'Billed ${app.lastBilledCount} unit${app.lastBilledCount == 1 ? '' : 's'}.');
            }
          });
        }
        return err;
      },
    );
  }

  void _editMethod(PayMethod m) {
    showFormSheet(
      context,
      title: m.name,
      subtitle: 'What residents see under Dues & payment.',
      fields: [FieldSpec('details', 'Account / instructions', lines: 4, initial: m.details)],
      toggles: [ToggleSpec('on', 'Show to residents', m.enabled)],
      submit: 'Save',
      onSubmit: (v) {
        app.updatePayMethod(m, v['details'] as String, v['on'] == true);
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final paid = app.dues.where((d) => d.paid).toList();
    final unpaid = app.dues.where((d) => !d.paid).toList();
    final through = _paidThrough(paid);
    final s = q.trim().toLowerCase();
    final found = [
      for (final d in (filter == 'Paid' ? paid : unpaid))
        if (s.isEmpty || '${d.unit} ${d.name} ${d.label}'.toLowerCase().contains(s)) d,
    ];
    final foundReceipts = [
      for (final p in app.payments)
        if (s.isEmpty || '${p.unit} ${p.payer} ${p.receiptNo}'.toLowerCase().contains(s)) p,
    ];
    final total = filter == 'Receipts' ? foundReceipts.length : found.length;
    final pages = total == 0 ? 1 : (total + _pageSize - 1) ~/ _pageSize;
    final pg = page < 0 ? 0 : (page > pages - 1 ? pages - 1 : page);
    final from = pg * _pageSize, to = (from + _pageSize) > total ? total : from + _pageSize;
    final rows = found.sublist(filter == 'Receipts' ? 0 : from, filter == 'Receipts' ? 0 : to);
    final receiptRows = foundReceipts.sublist(filter == 'Receipts' ? from : 0, filter == 'Receipts' ? to : 0);
    final pendingProofs = app.proofs.where((p) => p.status == 'Pending').toList();
    final counts = {'Unpaid': unpaid.length, 'Paid': paid.length, 'Receipts': app.payments.length};
    return TabPage(
      title: 'Finance',
      subtitle: 'Dues, charges, payment status and payment history.',
      children: [
        const ImportBar(['charges', 'payments']),
        PastelCard(
          color: Pastel.lavender,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('COLLECTED THIS MONTH', style: TextStyle(color: inkSoft, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
              const SizedBox(height: 4),
              Text(peso(app.collectedThisMonth), style: hd(32, color: ink)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 28,
                runSpacing: 8,
                children: [
                  _heroStat('Unpaid units', '${unpaid.length}'),
                  _heroStat('Total recorded', peso(app.totalCollected)),
                  _heroStat('Spent this month', peso(app.spentThisMonth)),
                ],
              ),
            ],
          ),
        ),
        RCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const IconBadge(Icons.table_chart_outlined, accent: true),
                const SizedBox(width: 12),
                Expanded(child: Text('Reports and files', style: hd(17))),
              ]),
              const SizedBox(height: 8),
              Text('Export the dues report, or import an Excel/CSV list of paid units (a column with unit names such as "Unit 12A") to record payments in one go.',
                  style: TextStyle(color: muted(context), fontSize: 12.5, height: 1.4)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => runSave(context, 'Excel report', () => exportXlsx('Dues collection report', collectionReport())),
                    icon: const Icon(Icons.table_chart_outlined),
                    label: const Text('Export Excel'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => runSave(context, 'Word report', () => exportDocx('Dues collection report', collectionReport())),
                    icon: const Icon(Icons.description_outlined),
                    label: const Text('Export Word'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => runSave(context, 'Excel file', () => exportXlsx('Payment history', paymentHistoryBlocks('Payment history', app.payments))),
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('Payments (Excel)'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => runSave(context, 'Word file', () => exportDocx('Payment history', paymentHistoryBlocks('Payment history', app.payments))),
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('Payments (Word)'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => go(context, const AdminFinanceDocs()),
                    icon: const Icon(Icons.lock_outline_rounded),
                    label: const Text('Finance documents'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _importPayments,
                    icon: const Icon(Icons.upload_file_rounded),
                    label: const Text('Import payments'),
                  ),
                ],
              ),
            ],
          ),
        ),
        RCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const IconBadge(Icons.north_east_rounded, accent: true),
                const SizedBox(width: 12),
                Expanded(child: Text('Expenses', style: hd(17))),
              ]),
              const SizedBox(height: 8),
              Text('Record everything the corporation buys. The monthly expense report for the client is made from these records.',
                  style: TextStyle(color: muted(context), fontSize: 12.5, height: 1.4)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => go(context, const AdminExpenses()),
                    icon: const Icon(Icons.north_east_rounded),
                    label: Text('Expenses and monthly report (${app.expenses.length})'),
                  ),
                ],
              ),
            ],
          ),
        ),
        RCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const IconBadge(Icons.request_quote_outlined, accent: true),
                const SizedBox(width: 12),
                Expanded(child: Text('Monthly association dues', style: hd(17))),
              ]),
              const SizedBox(height: 8),
              Text('Set what each unit pays every month, then bill all units for a month in one tap. Each unit sees its own charge under Dues.',
                  style: TextStyle(color: muted(context), fontSize: 12.5, height: 1.4)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: duesRate,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Dues per unit per month (₱)'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: () {
                      final err = app.setDuesRate(duesRate.text);
                      msg(context, err ?? 'Monthly dues set to ${peso(app.duesRate)} per unit.');
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: app.duesRate > 0 && app.units.isNotEmpty ? _billDues : null,
                  icon: const Icon(Icons.playlist_add_check_rounded),
                  label: Text(app.units.isEmpty ? 'Add units first' : (app.duesRate > 0 ? 'Bill monthly dues' : 'Save the dues amount first')),
                ),
              ),
            ],
          ),
        ),
        if (pendingProofs.isNotEmpty)
          RCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const IconBadge(Icons.fact_check_outlined, accent: true),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Payments to verify', style: hd(17))),
                ]),
                const SizedBox(height: 4),
                for (final p in pendingProofs) ...[
                  const Divider(height: 22),
                  Text('${p.unit} · ${p.payer}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('${p.method} · Ref. ${p.reference} · ${p.date}', style: TextStyle(color: muted(context), fontSize: 12.5)),
                  if (_duplicateOf(p) != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Duplicate reference: also sent by ${_duplicateOf(p)!.unit}', style: const TextStyle(color: Color(0xFF8A6D00), fontSize: 12.5, fontWeight: FontWeight.w700)),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(peso(p.amount), style: hd(17)),
                      const Spacer(),
                      TextButton(
                        onPressed: () => _reject(p),
                        child: const Text('Reject'),
                      ),
                      const SizedBox(width: 6),
                      FilledButton(
                        style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                        onPressed: () {
                          final rec = app.confirmProof(p);
                          final slot = p.forText == parkingPayFor ? app.slotOf(p.unit) : null;
                          msg(context, slot != null ? 'Payment verified. ${slot.id} is now assigned to ${p.unit}. Receipt ${rec.receiptNo} issued.' : 'Payment verified. Receipt ${rec.receiptNo} issued.');
                        },
                        child: const Text('Verify'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        RCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const IconBadge(Icons.account_balance_wallet_outlined, accent: true),
                const SizedBox(width: 12),
                Expanded(child: Text('Payment options', style: hd(17))),
              ]),
              const SizedBox(height: 6),
              Text('Where residents can pay. Add your real bank and e-wallet details here - residents see them under Dues & payment.',
                  style: TextStyle(color: muted(context), fontSize: 12.5, height: 1.4)),
              for (final m in app.payMethods) ...[
                const Divider(height: 22),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(payIcon(m.name), size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(m.details, style: TextStyle(color: muted(context), fontSize: 12.5, height: 1.4)),
                          if (!m.enabled) const Padding(padding: EdgeInsets.only(top: 4), child: Pill('Hidden', tone: Tone.warn)),
                        ],
                      ),
                    ),
                    IconButton(onPressed: () => _editMethod(m), icon: const Icon(Icons.edit_outlined)),
                  ],
                ),
              ],
            ],
          ),
        ),
        RCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const IconBadge(Icons.two_wheeler_rounded, accent: true),
                const SizedBox(width: 12),
                Expanded(child: Text('Motor parking rental', style: hd(17))),
              ]),
              const SizedBox(height: 8),
              Text("Residents rent a motor/motorcycle slot for one month or by the day. Set a rate for each. The board can adjust them as needed.",
                  style: TextStyle(color: muted(context), fontSize: 12.5, height: 1.4)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: rate,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Monthly rate (₱)'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: () {
                      final err = app.setRate(rate.text);
                      msg(context, err ?? 'Monthly parking rate updated to ${peso(app.motorRate)}/month.');
                    },
                    child: const Text('Update'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Current monthly rate: ${peso(app.motorRate)}/month', style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: rateDay,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Daily rate (₱ per day)'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: () {
                      final err = app.setDailyRate(rateDay.text);
                      msg(context, err ?? 'Daily parking rate updated to ${peso(app.motorRateDay)}/day.');
                    },
                    child: const Text('Update'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(app.motorRateDay > 0 ? 'Current daily rate: ${peso(app.motorRateDay)}/day' : 'Daily rate not set (the daily option is hidden)', style: const TextStyle(fontWeight: FontWeight.w700)),
              if (app.parking.isNotEmpty) ...[
                const Divider(height: 24),
                Text('Slot requests', style: TextStyle(color: muted(context), fontWeight: FontWeight.w700)),
                for (final p in app.parking)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${p.unit} · ${p.name}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: app.slotOf(p.unit) == null ? null : Text('Slot ${app.slotOf(p.unit)!.id}'),
                    trailing: p.confirmed
                        ? const Pill('Confirmed')
                        : FilledButton(
                            style: FilledButton.styleFrom(minimumSize: const Size(0, 38)),
                            onPressed: () {
                              final err = app.assignRequest(p);
                              if (err != null) msg(context, err);
                            },
                            child: const Text('Confirm'),
                          ),
                  ),
              ],
            ],
          ),
        ),
        Row(
          children: [
            Expanded(
              child: FilterRow(
                options: ['Unpaid (${counts['Unpaid']})', 'Paid (${counts['Paid']})', 'Receipts (${counts['Receipts']})'],
                selected: '$filter (${counts[filter]})',
                onSelect: (v) => setState(() {
                  filter = v.startsWith('Paid') ? 'Paid' : v.startsWith('Receipts') ? 'Receipts' : 'Unpaid';
                  page = 0;
                }),
              ),
            ),
            TextButton.icon(
              onPressed: () => showFormSheet(
                context,
                title: 'Add finance charge',
                fields: const [
                  FieldSpec('unit', 'Unit', hint: 'e.g. Unit 12A'),
                  FieldSpec('amount', 'Amount (₱)', type: TextInputType.number),
                  FieldSpec('note', 'Description', hint: 'e.g. Facility damage fee'),
                ],
                submit: 'Add charge',
                onSubmit: (v) {
                  final err = app.addCharge(v['unit'] as String, v['amount'] as String, v['note'] as String);
                  if (err == null) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() {
                          filter = 'Unpaid';
                          page = 0;
                        });
                        msg(context, 'Charge added to ${(v['unit'] as String).trim()}.');
                      }
                    });
                  }
                  return err;
                },
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Charge'),
            ),
          ],
        ),
        TextField(
          onChanged: (v) => setState(() {
            q = v;
            page = 0;
          }),
          decoration: const InputDecoration(hintText: 'Search unit or description…', prefixIcon: Icon(Icons.search_rounded)),
        ),
        if (filter == 'Receipts') ReceiptList(receiptRows, showUnit: true),
        if (filter != 'Receipts' && rows.isEmpty) EmptyBox(s.isEmpty ? 'Nothing here yet.' : 'Nothing matches your search.', icon: Icons.payments_outlined),
        if (filter != 'Receipts')
          for (final d in rows)
          RCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${d.unit} · ${d.name}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(d.label, style: TextStyle(color: muted(context), fontSize: 12.5)),
                      if (d.paid && through[d.id] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Paid through ${through[d.id]!.method}${through[d.id]!.reference == '—' ? '' : ' · Ref ${through[d.id]!.reference}'} · ${through[d.id]!.date}',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: lavDeep),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(peso(d.amt), style: hd(17)),
                    ],
                  ),
                ),
                d.paid
                    ? const Pill('Paid')
                    : OutlinedButton(
                        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                        onPressed: () => _recordPayment(d),
                        child: const Text('Record payment'),
                      ),
              ],
            ),
          ),
        if (total > _pageSize)
          Row(
            children: [
              IconButton(
                onPressed: pg == 0 ? null : () => setState(() => page = pg - 1),
                icon: const Icon(Icons.chevron_left_rounded),
                tooltip: 'Previous page',
              ),
              Expanded(
                child: Text('Showing ${from + 1}–$to of $total · page ${pg + 1} of $pages',
                    textAlign: TextAlign.center, style: TextStyle(color: muted(context), fontSize: 12.5, fontWeight: FontWeight.w600)),
              ),
              IconButton(
                onPressed: pg >= pages - 1 ? null : () => setState(() => page = pg + 1),
                icon: const Icon(Icons.chevron_right_rounded),
                tooltip: 'Next page',
              ),
            ],
          ),
      ],
    );
  }

  /// Which payment (type, reference, date) settled each paid charge: a unit's charges and payments with the same text and amount are paired oldest to oldest.
  Map<int, PaymentRecord> _paidThrough(List<Due> paid) {
    final byKey = <String, List<PaymentRecord>>{};
    final pays = [...app.payments]..sort((a, b) => a.id.compareTo(b.id));
    for (final p in pays) {
      byKey.putIfAbsent('${p.unit}|${p.forText}|${p.amount.toDouble()}', () => []).add(p);
    }
    final out = <int, PaymentRecord>{};
    final dues = [...paid]..sort((a, b) => a.id.compareTo(b.id));
    for (final d in dues) {
      final list = byKey['${d.unit}|${d.note}|${d.amount.toDouble()}'];
      if (list != null && list.isNotEmpty) out[d.id] = list.removeAt(0);
    }
    return out;
  }

  Widget _heroStat(String k, String v) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(v, style: hd(17, color: ink)),
          Text(k, style: const TextStyle(color: inkSoft, fontSize: 12)),
        ],
      );
}
