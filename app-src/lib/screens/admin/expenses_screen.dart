// ADMIN page: Expenses.

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../services/doc_files.dart';
import '../../widgets/widgets.dart';
import '../shared/import_sheet.dart';
import '../shared/document_viewer_screen.dart';

/// The "Add purchase" form. [day] is the date it starts with (today when null).
void showAddPurchase(BuildContext context, {DateTime? day}) {
  showFormSheet(
    context,
    title: 'Add purchase',
    subtitle: 'Record what the corporation bought. It goes into the monthly report.',
    choices: [
      ChoiceSpec('cat', 'Category', expenseCategories, expenseCategories[2]),
      ChoiceSpec('area', 'For which facility or area', expenseAreas, expenseAreas.first),
    ],
    fields: [
      const FieldSpec('item', 'What was bought', hint: 'e.g. LED bulbs, pool chlorine, elevator repair'),
      const FieldSpec('qty', 'Quantity', type: TextInputType.number, initial: '1'),
      const FieldSpec('price', 'Price of one (₱)', type: TextInputType.number),
      const FieldSpec('payee', 'Store or supplier', hint: 'Who was paid'),
      const FieldSpec('receipt', 'Official receipt no. (optional)'),
      FieldSpec('date', 'Date bought', initial: shortDate(day ?? DateTime.now()), hint: 'Oct 10, 2026'),
      const FieldSpec('note', 'Notes (optional)', lines: 2),
    ],
    submit: 'Save purchase',
    onSubmit: (v) => app.addExpense(
      category: v['cat'] as String,
      area: v['area'] as String,
      item: v['item'] as String,
      payee: v['payee'] as String,
      qtyRaw: v['qty'] as String,
      unitPriceRaw: v['price'] as String,
      receiptNo: v['receipt'] as String,
      note: v['note'] as String,
      dateRaw: v['date'] as String,
    ),
  );
}

/// Expenses: everything the corporation buys, encoded one purchase at a time.
/// The monthly report for the client is generated from these records.
class AdminExpenses extends StatefulWidget {
  const AdminExpenses({super.key});

  @override
  State<AdminExpenses> createState() => _AdminExpensesState();
}

class _AdminExpensesState extends State<AdminExpenses> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);

  bool get _isCurrentMonth {
    final n = DateTime.now();
    return _month.year == n.year && _month.month == n.month;
  }

  String _tab = 'Summary';
  static const _pageSize = 8;
  int _page = 0;

  void _shift(int by) => setState(() {
        _month = DateTime(_month.year, _month.month + by, 1);
        _page = 0;
      });

  void _budget(BuildContext context) {
  showFormSheet(
      context,
      title: 'Annual budget',
      subtitle: 'The approved yearly amount for each category, in pesos. Leave a line empty if it has no budget. The monthly report compares your spending with it.',
      fields: [
        for (final c in expenseCategories)
          FieldSpec(c, c, type: TextInputType.number, initial: annualBudget[c] == null ? '' : '${annualBudget[c]}'),
      ],
      submit: 'Save budget',
      onSubmit: (v) {
        final out = <String, int>{};
        for (final c in expenseCategories) {
          final raw = (v[c] as String).trim().replaceAll(',', '');
          if (raw.isEmpty) continue;
          final n = int.tryParse(raw);
          if (n == null || n < 0) return 'Enter whole pesos only for "$c".';
          if (n > 0) out[c] = n;
        }
        app.setBudget(out);
        return null;
      },
    );
  }

  void _add(BuildContext context) => showAddPurchase(context);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final y = _month.year, m = _month.month;
        final list = app.expenses.where((e) => e.date.year == y && e.date.month == m).toList();
        final spent = list.fold<num>(0, (s, e) => s + e.amount);
        final collected = app.collectedIn(y, m);
        final net = collected - spent;
        final label = monthYear(_month);
        List<DocBlock> report() => monthlyExpenseBlocks(app.expenses, _month, app.collectedIn(y, m));
        final reportName = 'Monthly expense report $label';

        // spending per category this month (only the ones with purchases)
        final byCat = <String, num>{};
        for (final e in list) {
          byCat[e.category] = (byCat[e.category] ?? 0) + e.amount;
        }
        final cats = byCat.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

        // purchases are shown one page at a time
        final pages = list.isEmpty ? 1 : (list.length + _pageSize - 1) ~/ _pageSize;
        final pg = _page < 0 ? 0 : (_page > pages - 1 ? pages - 1 : _page);
        final from = pg * _pageSize;
        final to = from + _pageSize > list.length ? list.length : from + _pageSize;
        final pageRows = list.sublist(from, to);

        return SubPage(
          title: 'Expenses',
          subtitle: 'Everything the corporation buys. Record each purchase, then get the monthly report for the client.',
          fab: FloatingActionButton.extended(
            backgroundColor: lav,
            foregroundColor: ink,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add purchase'),
            onPressed: () => _add(context),
          ),
          children: [
            // --- month picker
            RCard(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                children: [
                  IconButton(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left_rounded), tooltip: 'Earlier month'),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(label, textAlign: TextAlign.center, style: hd(17)),
                        Text(_isCurrentMonth ? 'This month' : 'Past month', style: TextStyle(color: muted(context), fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _isCurrentMonth ? null : () => _shift(1),
                    icon: const Icon(Icons.chevron_right_rounded),
                    tooltip: 'Later month',
                  ),
                ],
              ),
            ),
            FilterRow(
              options: const ['Summary', 'Purchases', 'Report and budget'],
              selected: _tab,
              onSelect: (v) => setState(() => _tab = v),
            ),
            if (_tab == 'Summary') ...[
              // --- hero
              PastelCard(
                color: Pastel.peach,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SPENT IN ${label.toUpperCase()}',
                        style: const TextStyle(color: inkSoft, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                    const SizedBox(height: 4),
                    Text(peso(spent), style: hd(32, color: ink)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 28,
                      runSpacing: 8,
                      children: [
                        _stat('Purchases', '${list.length}'),
                        _stat('Dues collected', peso(collected)),
                        _stat('Collected less spending', net < 0 ? '-${peso(-net)}' : peso(net)),
                      ],
                    ),
                  ],
                ),
              ),
              // --- where the money went
              if (cats.isNotEmpty)
                DashSection(
                  title: 'Where the money went',
                  child: RCard(
                    child: Column(
                      children: [
                        for (var i = 0; i < cats.length; i++)
                          Padding(
                            padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: Text(cats[i].key, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5))),
                                    Text(peso(cats[i].value), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(99),
                                  child: TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0, end: spent == 0 ? 0 : (cats[i].value / spent).toDouble()),
                                    duration: const Duration(milliseconds: 700),
                                    curve: Curves.easeOutCubic,
                                    builder: (_, v, __) => LinearProgressIndicator(
                                      value: v,
                                      minHeight: 8,
                                      color: lavDeep,
                                      backgroundColor: Theme.of(context).colorScheme.outlineVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

            ],
            if (_tab == 'Purchases') ...[
              // --- purchases of the month
              DashSection(
                title: 'Purchases in $label',
                child: Column(
                  children: [
                    if (list.isEmpty)
                      EmptyBox(
                        _isCurrentMonth ? 'No purchases yet this month. Tap Add purchase to record the first one.' : 'No purchases were recorded in $label.',
                        icon: Icons.receipt_long_outlined,
                      ),
                    for (final e in pageRows)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: RCard(
                          padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const IconBadge(Icons.shopping_bag_outlined, accent: true),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(e.item, style: const TextStyle(fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${e.qtyText} × ${peso(e.unitPrice)} · ${e.supplierText}\n'
                                      '${e.area} · ${e.category} · ${shortDate(e.date)}'
                                      '${e.note.isEmpty ? '' : '\n${e.note}'}',
                                      style: TextStyle(color: muted(context), fontSize: 12.5, height: 1.4),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(peso(e.amount), style: hd(15)),
                              ),
                              PopupMenuButton<String>(
                                tooltip: 'More',
                                onSelected: (a) async {
                                  if (a == 'delete') {
                                    final ok = await confirmDialog(context, 'Delete purchase?', '${e.item} · ${peso(e.amount)} will be removed from the records.',
                                        confirm: 'Delete', destructive: true);
                                    if (ok) app.removeExpense(e);
                                  }
                                },
                                itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('Delete'))],
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (list.length > _pageSize)
                      Row(
                        children: [
                          IconButton(
                            onPressed: pg == 0 ? null : () => setState(() => _page = pg - 1),
                            icon: const Icon(Icons.chevron_left_rounded),
                            tooltip: 'Previous page',
                          ),
                          Expanded(
                            child: Text('Showing ${from + 1}–$to of ${list.length} · page ${pg + 1} of $pages',
                                textAlign: TextAlign.center, style: TextStyle(color: muted(context), fontSize: 12.5, fontWeight: FontWeight.w600)),
                          ),
                          IconButton(
                            onPressed: pg >= pages - 1 ? null : () => setState(() => _page = pg + 1),
                            icon: const Icon(Icons.chevron_right_rounded),
                            tooltip: 'Next page',
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
            if (_tab == 'Report and budget') ...[
              const ImportBar(['expenses']),
              // --- monthly report actions
              DashSection(
                title: 'Monthly report',
                hint: 'Summary, every purchase, spending by category and by facility.',
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: () => go(context, DocViewer(DocItem(reportName, 'Finance', 'Live report', live: report))),
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('View report'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => runSave(context, 'Word file', () => exportDocx(reportName, report())),
                      icon: const Icon(Icons.description_outlined),
                      label: const Text('Word'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => runSave(context, 'Excel file', () => exportXlsx(reportName, report())),
                      icon: const Icon(Icons.table_chart_outlined),
                      label: const Text('Excel'),
                    ),
                  ],
                ),
              ),
              DashSection(
                title: 'Annual budget',
                hint: annualBudget.isEmpty
                    ? 'Not set yet. Enter the approved budget so the report can compare spending against it.'
                    : 'Total ${peso(annualBudget.values.fold<int>(0, (a, b) => a + b))} per year.',
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonalIcon(
                    onPressed: () => _budget(context),
                    icon: const Icon(Icons.tune_rounded),
                    label: Text(annualBudget.isEmpty ? 'Set annual budget' : 'Edit annual budget'),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _stat(String k, String v) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(v, style: hd(17, color: ink)),
          Text(k, style: const TextStyle(color: inkSoft, fontSize: 12)),
        ],
      );
}
