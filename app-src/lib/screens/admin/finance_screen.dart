// ADMIN page: Finance (dues, payments, payment proofs).

import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../core/doc_seed.dart';
import '../../services/doc_files.dart';
import '../../services/texting.dart';
import '../../widgets/widgets.dart';
import '../shared/import_sheet.dart';
import '../shared/document_viewer_screen.dart';
import '../shared/payment_widgets.dart';
import 'admin_screens.dart';
import 'finance_cards.dart';
import 'pay_check.dart';
import 'verify_panel.dart';
import 'parking_rates_card.dart';
import 'price_calculator.dart';

/// What the reminder says until the office edits it.
const kReminderDefault = 'Please settle your dues when you can. Thank you!';

/// Another screen (the dashboard) asks Finance to open on a tab: 'Verify' or 'Check' (Did they pay?).
final ValueNotifier<String?> financeTabRequest = ValueNotifier<String?>(null);

class AdminFinance extends StatefulWidget {
  const AdminFinance({super.key});

  @override
  State<AdminFinance> createState() => _AdminFinanceState();
}

class _AdminFinanceState extends State<AdminFinance> {
  String tab = 'Overview';

  void _onTabRequest() {
    final t = financeTabRequest.value;
    if (t == null) return;
    financeTabRequest.value = null;
    if (mounted) setState(() => tab = t);
  }

  @override
  void initState() {
    super.initState();
    final t = financeTabRequest.value;
    if (t != null) {
      tab = t;
      financeTabRequest.value = null;
    }
    financeTabRequest.addListener(_onTabRequest);
  }

  String filter = 'Unpaid';
  static const _pageSize = 10;
  int page = 0;
  String q = '';
  bool recalcOnSave = true;
  late final rate = TextEditingController(text: app.motorRate.toStringAsFixed(0));
  late final rateDay = TextEditingController(text: app.motorRateDay == 0 ? '' : app.motorRateDay.toStringAsFixed(0));
  late final duesRate = TextEditingController(text: app.duesRate == 0 ? '' : app.duesRate.toStringAsFixed(0));

  @override
  void dispose() {
    financeTabRequest.removeListener(_onTabRequest);
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
    final phone = app.phoneOfUnit(d.unit);
    showFormSheet(
      context,
      title: 'Record payment',
      subtitle: '${d.unit} · ${d.name} · ${peso(d.amt)}',
      photo: const PhotoSpec('photo', 'Photo of proof (optional)', hint: 'A picture of the receipt, deposit slip or screenshot.'),
      choices: [ChoiceSpec('method', 'Paid through', methods, methods.first)],
      fields: [
        const FieldSpec('ref', 'Reference no. (optional)', hint: 'From the payment receipt'),
        if (phone != null)
          FieldSpec('smsText', 'Text message to the resident', lines: 4, initial: app.smsPaymentText, hint: 'Words in { } are filled in: {name} {unit} {amount} {items} {receipt} {date}'),
      ],
      toggles: [
        if (phone != null) ToggleSpec('sms', 'Also prepare a text message for $phone', true),
        if (phone != null) const ToggleSpec('saveTpl', 'Save this wording as the standard message', false),
      ],
      submit: 'Record and issue receipt',
      onSubmit: (v) {
        final pic = v['photo'];
        final rec = app.payDue(d.id, method: v['method'] as String, reference: v['ref'] as String, image: pic is Uint8List ? proofImageText(pic) : '');
        final text = ((v['smsText'] as String?) ?? '').trim();
        if (rec != null && phone != null && text.isNotEmpty) {
          if (v['saveTpl'] == true) app.setSmsPayment(text);
          if (v['sms'] == true) {
            final first = d.name.trim().split(RegExp(r'\s+')).first;
            final filled = remFill(text, {
              'name': d.name.trim().isEmpty || d.name == '—' || d.name == d.unit ? 'Resident' : first,
              'unit': d.unit,
              'amount': peso(d.amt),
              'items': d.note,
              'receipt': rec.receiptNo,
              'date': shortDate(DateTime.now()),
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) textNumbers(context, [phone], filled, '');
            });
          }
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && rec != null) msg(context, 'Payment recorded. Receipt ${rec.receiptNo} issued.');
        });
        return null;
      },
    );
  }

  /// Add a charge for one unit, or for every unit at once (type "All units").
  void _addChargeSheet() {
    showFormSheet(
      context,
      title: 'Add finance charge',
      fields: const [
        FieldSpec('unit', 'Unit', hint: 'e.g. Unit 12A, or type All units to bill everyone', initial: ''),
        FieldSpec('amount', 'Amount (₱) for each unit', type: TextInputType.number),
        FieldSpec('note', 'Description', hint: 'e.g. Facility damage fee'),
        FieldSpec('due', 'Due date (optional)', hint: 'e.g. Oct 30, 2026'),
      ],
      submit: 'Add charge',
      onSubmit: (v) {
        final err = app.addCharge(v['unit'] as String, v['amount'] as String, v['note'] as String, dueRaw: v['due'] as String);
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
    );
  }

  /// One line for each kind of charge (same description), so a whole kind can be changed or removed in one go.
  Widget _chargeTypes(BuildContext context) {
    final groups = <String, List<Due>>{};
    for (final d in app.dues) {
      groups.putIfAbsent(d.note, () => []).add(d);
    }
    final rows = [
      for (final e in groups.entries)
        if (e.value.any((d) => !d.paid)) e,
    ]..sort((a, b) => b.value.where((d) => !d.paid).length.compareTo(a.value.where((d) => !d.paid).length));
    if (rows.isEmpty) return const SizedBox.shrink();
    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const IconBadge(Icons.tune_rounded, accent: true),
            const SizedBox(width: 12),
            Expanded(child: Text('All charges, edit as a whole', style: hd(17))),
            TextButton.icon(onPressed: _addChargeSheet, icon: const Icon(Icons.add_rounded), label: const Text('New kind')),
          ]),
          const SizedBox(height: 8),
          Text(
              'One line for each kind of charge. "Edit all" changes the description, amount or due date for every unit\'s unpaid charge of that kind at once. Paid charges are never touched. To change just one unit, use the pencil on its row below.',
              style: TextStyle(color: muted(context), fontSize: 12.5, height: 1.4)),
          const SizedBox(height: 8),
          for (final e in rows)
            Builder(builder: (context) {
              final unpaid = e.value.where((d) => !d.paid).toList();
              final amts = {for (final d in unpaid) d.amt};
              final dues = {for (final d in unpaid) d.dueDate.isEmpty ? 'On receipt' : d.dueDate};
              return Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: Theme.of(context).colorScheme.outlineVariant)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.key, style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(
                      '${{for (final d in e.value) d.unit}.length} units · ${unpaid.length} unpaid${e.value.length > unpaid.length ? ' · ${e.value.length - unpaid.length} paid' : ''}\n'
                      '${amts.length == 1 ? peso(amts.first) : 'Different amounts (${amts.length})'} · ${dues.length == 1 ? 'due ${dues.first}' : 'different due dates (${dues.length})'}',
                      style: TextStyle(color: muted(context), fontSize: 12.5, height: 1.4),
                    ),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, children: [
                      FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 36)), onPressed: () => _editCharge(unpaid.first, all: true), child: const Text('Edit all')),
                      OutlinedButton(style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36)), onPressed: () => _removeAll(e.key), child: const Text('Remove unpaid')),
                    ]),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  void _removeAll(String note) {
    final n = app.dues.where((d) => !d.paid && d.note == note).length;
    if (n == 0) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove “$note”?'),
        content: Text('This removes $n unpaid charge${n == 1 ? '' : 's'} from the residents\' dues. Paid ones stay.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              app.editCharge(app.dues.firstWhere((d) => !d.paid && d.note == note), '', remove: true);
              Navigator.pop(ctx);
              if (mounted) msg(context, 'Removed $n unpaid charge${n == 1 ? '' : 's'}.');
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _remindAll() {
    final n7 = app.needReminder();
    final skipped = app.dues.where((d) => !d.paid && d.remindedWithin(24)).length;
    showFormSheet(
      context,
      title: 'Send reminders',
      subtitle:
          'Right now ${n7.length} unpaid charge${n7.length == 1 ? ' is' : 's are'} overdue or due within 7 days and not reminded in the last 24 hours.${skipped == 0 ? '' : ' $skipped already reminded today ${skipped == 1 ? 'is' : 'are'} skipped, so nobody gets the same message twice.'} Change the number of days to include more or fewer. Each resident sees the reminder under Notifications.',
      fields: [
        const FieldSpec('days', 'Include charges overdue or due within this many days', type: TextInputType.number, initial: '7'),
        const FieldSpec('msg', 'Message to the residents (you can edit it)', lines: 3, initial: kReminderDefault),
      ],
      submit: 'Send reminders',
      onSubmit: (v) {
        final days = int.tryParse((v['days'] as String).trim());
        if (days == null || days < 0 || days > 365) return 'Enter the number of days, from 0 to 365.';
        final list = app.needReminder(days);
        if (list.isEmpty) return 'No unpaid charge is overdue or due within $days day${days == 1 ? '' : 's'}.';
        final n = app.remindAll(days: days, message: v['msg'] as String);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) msg(context, 'Reminders sent to $n unit${n == 1 ? '' : 's'} (${list.length} charge${list.length == 1 ? '' : 's'}).');
        });
        return null;
      },
    );
  }

  void _editCharge(Due d, {bool all = false}) {
    final same = app.dues.where((x) => !x.paid && x.note == d.note).length;
    const one = 'This unit only', rm = 'Remove it from all units (unpaid ones)';
    final many = 'All units: $same unpaid charge${same == 1 ? '' : 's'} named this';
    showFormSheet(
      context,
      title: 'Change charge',
      subtitle: '${d.unit}${d.area > 0 && d.rate > 0 ? '\nWorked out as ${d.area} sqm × ${peso(d.rate)} = ${peso(d.area * d.rate)}.' : ''}\nChange the description, amount or due date. Pick "All units" to change every unit\'s unpaid charge with this description in one go. Paid ones are never touched.${same > 1 && app.dues.where((x) => !x.paid && x.note == d.note).any((x) => (x.amount - d.amount).abs() > 0.005) ? '\nThese units pay different amounts. Leave the amount as it is to keep each unit\'s own amount; type a new amount only if everyone should pay that same amount.' : ''}',
      fields: [
        FieldSpec('note', 'Description', initial: d.note),
        FieldSpec('amount', 'Amount (₱)', type: const TextInputType.numberWithOptions(decimal: true), initial: d.amt.toString()),
        FieldSpec('due', 'Due date (optional)', hint: 'e.g. Oct 30, 2026', initial: d.dueDate),
      ],
      choices: [ChoiceSpec('scope', 'Apply to', same > 1 ? [one, many, rm] : [one, rm], all && same > 1 ? many : one)],
      submit: 'Save',
      onSubmit: (v) {
        final scope = v['scope'] as String;
        return app.editCharge(d, v['amount'] as String,
            note: v['note'] as String, dueRaw: v['due'] as String, allUnits: scope == many, remove: scope == rm);
      },
    );
  }

  void _billDues() {
    final now = DateTime.now();
    showFormSheet(
      context,
      title: 'Bill monthly dues',
      subtitle: 'Adds one charge to every unit that has not been billed for this month yet. Each charge is worked out automatically: the unit\'s floor area × ${peso(app.duesRate)} per sqm.',
      fields: [
        FieldSpec('period', 'Month', hint: 'e.g. October 2026', initial: app.monthLabel(now)),
        FieldSpec('due', 'Due date for units without a due day (optional)', hint: 'e.g. Oct 15, 2026'),
      ],
      submit: 'Bill all units',
      onSubmit: (v) {
        final err = app.billMonthlyDues(v['period'] as String, v['due'] as String);
        if (err == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => filter = 'Unpaid');
              final noArea = app.lastNoAreaCount;
              msg(
                context,
                (app.lastBilledCount == 0
                        ? 'Nobody new to bill for that month.'
                        : 'Billed ${app.lastBilledCount} unit${app.lastBilledCount == 1 ? '' : 's'}. Each resident is notified under Notifications and Dues.') +
                    (noArea == 0 ? '' : ' $noArea unit${noArea == 1 ? ' has' : 's have'} no floor area yet; add it under Units.'),
              );
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
    const tabs = ['Overview', 'Verify', 'Check', 'Charges', 'Daily', 'Units', 'Settings'];
    final checkCount = app.payCheckList.length;
    final tabLabels = [
      'Overview',
      pendingProofs.isEmpty ? 'To verify' : 'To verify (${pendingProofs.length})',
      checkCount == 0 ? 'Did they pay?' : 'Did they pay? ($checkCount)',
      'Charges (${unpaid.length})',
      'Daily',
      'Unit dues',
      'Settings',
    ];
    return TabPage(
      title: 'Finance',
      subtitle: 'Dues, charges, payment status and payment history.',
      children: [
        FilterRow(
          options: tabLabels,
          selected: tabLabels[tabs.indexOf(tab)],
          onSelect: (v) => setState(() => tab = tabs[tabLabels.indexOf(v)]),
        ),
        if (tab == 'Overview') ...[
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
          if (pendingProofs.isNotEmpty || checkCount > 0)
            RCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Needs your attention', style: hd(17)),
                  const SizedBox(height: 8),
                  if (pendingProofs.isNotEmpty)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const IconBadge(Icons.fact_check_outlined, accent: true),
                      title: Text('${pendingProofs.length} payment${pendingProofs.length == 1 ? '' : 's'} to verify', style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: const Text('Residents sent their payment details.'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => setState(() => tab = 'Verify'),
                    ),
                  if (checkCount > 0)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const IconBadge(Icons.help_outline_rounded, accent: true),
                      title: Text('$checkCount charge${checkCount == 1 ? '' : 's'}: did they pay?', style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: const Text('Due or past due with no payment on record.'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => setState(() => tab = 'Check'),
                    ),
                ],
              ),
            ),
          const DailyCollectionsCard(),
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
        ],
        if (tab == 'Verify')
          (pendingProofs.isEmpty
              ? const EmptyBox('No payments to verify right now.', icon: Icons.fact_check_outlined)
              : VerifyPanel(
                  proofs: pendingProofs,
                  onReject: _reject,
                  onChangeSettings: () => go(context, const AdminSettings()),
                )),
        if (tab == 'Check')
          (checkCount == 0
              ? const EmptyBox('Nothing to check. Every charge that is due has a payment, or the resident already sent their details.', icon: Icons.help_outline_rounded)
              : const PayCheckCard()),
        if (tab == 'Charges') ...[
          const ImportBar(['charges', 'payments']),
          _chargeTypes(context),
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
                Text('Set the monthly dues per square meter. Each unit pays its floor area × that rate. Bill all units for a month in one tap; each resident is notified and sees the charge under Dues.',
                    style: TextStyle(color: muted(context), fontSize: 12.5, height: 1.4)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: duesRate,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Monthly dues per sqm (₱)'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: () {
                        final err = app.setDuesRate(duesRate.text, recalc: recalcOnSave);
                        final k = app.lastRecalcCount;
                        msg(context, err ?? 'Monthly dues set to ${peso(app.duesRate)} per sqm.${k > 0 ? ' $k unpaid monthly charge${k == 1 ? '' : 's'} updated to the new rate.' : ''}');
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                  value: recalcOnSave,
                  onChanged: (v) => setState(() => recalcOnSave = v ?? true),
                  title: const Text('When I save a new rate, also update the unpaid monthly dues to it', style: TextStyle(fontSize: 13)),
                ),
                PriceCalculator(
                  monthlyRate: () {
                    final d = double.tryParse(duesRate.text.trim().replaceAll(',', ''));
                    return d != null && d > 0 ? d : app.duesRate.toDouble();
                  },
                  onUseRate: (v) {
                    setState(() => duesRate.text = v.toStringAsFixed(2));
                    msg(context, 'Rate of ${peso(v)} per sqm per month is ready. Tap Save to keep it.');
                  },
                ),
                const SizedBox(height: 12),
                _pricePreview(context),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _remindAll,
                    icon: const Icon(Icons.notifications_active_outlined),
                    label: const Text('Send reminders'),
                  ),
                ),
                const SizedBox(height: 8),
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
                onPressed: _addChargeSheet,
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
          if (filter == 'Unpaid')
            Builder(builder: (context) {
              final over = unpaid.where((d) => d.overdue).toList();
              if (over.isEmpty) return const SizedBox.shrink();
              final sum = over.fold<num>(0, (a, d) => a + d.amt);
              final fresh = over.where((d) => !d.remindedWithin(24)).length;
              final fees = over.where((d) => d.lateFeeId > 0).length;
              final t = toneOf(context, Tone.bad);
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(16), border: Border.all(color: t.fg.withValues(alpha: 0.35))),
                child: Row(children: [
                  Icon(Icons.warning_amber_rounded, color: t.fg),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${over.length} overdue charge${over.length == 1 ? '' : 's'} (${peso(sum)})', style: TextStyle(color: t.fg, fontWeight: FontWeight.w800)),
                      Text('${fees > 0 ? '$fees already got a late charge. ' : ''}${fresh > 0 ? '$fresh not reminded in the last 24 hours.' : 'Everyone overdue was reminded today.'}',
                          style: TextStyle(color: t.fg, fontSize: 12.5)),
                    ]),
                  ),
                  if (fresh > 0) FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 36)), onPressed: _remindAll, child: const Text('Remind')),
                ]),
              );
            }),
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
                        if (d.billed.isNotEmpty || d.dueDate.isNotEmpty)
                          Text(
                            [if (d.billed.isNotEmpty) 'Billed ${d.billed}', if (d.dueDate.isNotEmpty) 'Due ${d.dueDate}'].join(' · '),
                            style: TextStyle(color: muted(context), fontSize: 12),
                          ),
                        if (d.paid && through[d.id] != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Paid through ${through[d.id]!.method}${through[d.id]!.reference == '—' ? '' : ' · Ref ${through[d.id]!.reference}'} · ${through[d.id]!.date}',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: lavDeep),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(peso(d.amt), style: hd(17)),
                        const SizedBox(height: 4),
                        Wrap(spacing: 6, runSpacing: 4, children: [
                          if (d.paid)
                            const Pill('Paid', tone: Tone.good)
                          else if (d.overdue)
                            Pill('⚠ Overdue by ${d.daysLate ?? 0} day${d.daysLate == 1 ? '' : 's'}', tone: Tone.bad)
                          else if (d.daysLate == 0)
                            const Pill('⚠ Due today', tone: Tone.warn)
                          else
                            const Pill('Open', tone: Tone.info),
                          if (!d.paid && d.lateFeeId > 0) const Pill('Late charge added', tone: Tone.bad),
                          if (!d.paid && d.note.startsWith('Late charge')) const Pill('Late charge', tone: Tone.bad),
                          if (!d.paid && d.remindedLabel.isNotEmpty) Pill(d.remindedLabel, tone: d.remindedWithin(24) ? Tone.good : Tone.info),
                        ]),
                      ],
                    ),
                  ),
                  if (!d.paid) ...[
                    IconButton(onPressed: () => _editCharge(d), icon: const Icon(Icons.edit_outlined), tooltip: 'Change the amount'),
                    IconButton(
                      onPressed: () => showFormSheet(
                        context,
                        title: 'Remind ${d.unit}',
                        subtitle: '${d.note} · ${peso(d.amt)}. The resident sees this under Notifications.'
                            '${d.remindedLabel.isEmpty ? '' : '\n${d.remindedLabel}.${d.remindedWithin(24) ? ' They were reminded less than a day ago, so you may not need to send another.' : ''}'}',
                        fields: [FieldSpec('msg', 'Message to the resident (you can edit it)', lines: 3, initial: d.remindMsg.isEmpty ? kReminderDefault : d.remindMsg)],
                        submit: 'Send reminder',
                        onSubmit: (v) {
                          app.remindDue(d, message: v['msg'] as String);
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) msg(context, 'Reminder sent to ${d.unit}. They will see it under Notifications.');
                          });
                          return null;
                        },
                      ),
                      icon: const Icon(Icons.notifications_active_outlined),
                      tooltip: d.remindedLabel.isEmpty ? 'Remind this unit' : '${d.remindedLabel}. Tap to remind again',
                    ),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                      onPressed: () => _recordPayment(d),
                      child: const Text('Record payment'),
                    ),
                  ],
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
        if (tab == 'Daily') ...[
          const DayByDayCard(),
          const DailyExpensesCard(),
        ],
        if (tab == 'Units') ...[
          const UnitDuesCard(),
        ],
        if (tab == 'Settings') ...[
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
          const ParkingRatesCard(),
          if (app.parking.isNotEmpty)
          RCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
            ),
          ),
        ],
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

  /// The price calculator: what a unit of each size pays at the rate being typed (floor area × rate).
  Widget _pricePreview(BuildContext context) {
    final rate = double.tryParse(duesRate.text.trim().replaceAll(',', '')) ?? 0;
    if (rate <= 0) {
      return Text('Type the price per square meter to see what every unit size will pay. It is worked out automatically (floor area × price).',
          style: TextStyle(color: muted(context), fontSize: 12.5, height: 1.4));
    }
    final t = app.priceTable(rate);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: Theme.of(context).colorScheme.outlineVariant)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dues by unit size · ${peso(rate)} per sqm per month', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(height: 6),
          if (t.rows.isEmpty) Text('No unit has a floor area yet. Set it with "Edit size" in Unit dues and payments.', style: TextStyle(color: muted(context), fontSize: 12.5)),
          for (final r in t.rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(child: Text('${r.$1} sqm × ${peso(rate)}', style: const TextStyle(fontSize: 13))),
                  Text('${r.$2} unit${r.$2 == 1 ? '' : 's'}', style: TextStyle(color: muted(context), fontSize: 12)),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${peso(r.$3)} / month', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                      Text('${peso((r.$3 * 12 / 365 * 100).round() / 100)} / day · ${peso((r.$3 * 12 * 100).round() / 100)} / year', style: TextStyle(color: muted(context), fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
          const Divider(height: 16),
          Text('All units: ${peso(t.total)} per month · ${peso((t.total * 12 * 100).round() / 100)} per year · ${peso((t.total * 12 / 365 * 100).round() / 100)} per day${t.noSize > 0 ? ' · ${t.noSize} unit${t.noSize == 1 ? ' has' : 's have'} no size yet' : ''}', style: TextStyle(color: muted(context), fontSize: 12.5)),
        ],
      ),
    );
  }

  Widget _heroStat(String k, String v) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(v, style: hd(17, color: ink)),
          Text(k, style: const TextStyle(color: inkSoft, fontSize: 12)),
        ],
      );
}
