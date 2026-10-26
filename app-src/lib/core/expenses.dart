// Expense model (what the corporation spent) and its categories.

import 'app_state.dart' show peso, shortDate, longDate;
import 'doc_model.dart';

/// What a purchase was for. The first ones follow the lines of the approved annual budget.
const expenseCategories = [
  'Security services',
  'Common-area utilities',
  'Janitorial and maintenance',
  'Repairs and improvements',
  'Supplies and equipment',
  'Insurance',
  'Administration and reserve fund',
  'Other',
];

/// Approved annual budget per category. Empty until the administrator enters it
/// (Expenses > Annual budget); it is shared with the website through the database.
final annualBudget = <String, int>{};

/// Which facility or part of the building a purchase is for.
const expenseAreas = [
  'Whole building',
  'Lobby and common areas',
  'Swimming pool',
  'Function hall',
  'Elevators',
  'Parking',
  'Grounds and garden',
  'Offices and security',
];

const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

String monthYear(DateTime d) => '${_monthNames[d.month - 1]} ${d.year}';

/// Reads dates written like "Oct 10, 2026". Returns null when the text does not match.
DateTime? parseShortDate(String raw) {
  final m = RegExp(r'^\s*([A-Za-z]{3})[a-z]*\.? (\d{1,2}), (\d{4})\s*$').firstMatch(raw);
  if (m == null) return null;
  const names = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
  final i = names.indexOf(m[1]!.toLowerCase());
  if (i < 0) return null;
  final day = int.parse(m[2]!);
  if (day < 1 || day > 31) return null;
  return DateTime(int.parse(m[3]!), i + 1, day);
}

/// One purchase of the corporation: what was bought, how many, the price, from whom.
class Expense {
  final int id;
  final String item, category, area, payee, receiptNo, note;
  final num qty, unitPrice;
  final DateTime date;
  const Expense({
    required this.id,
    required this.item,
    required this.category,
    required this.area,
    required this.payee,
    required this.receiptNo,
    required this.note,
    required this.qty,
    required this.unitPrice,
    required this.date,
  });

  /// Total paid for this purchase.
  num get amount => qty * unitPrice;

  String get qtyText => qty == qty.roundToDouble() ? qty.toInt().toString() : qty.toString();

  /// Supplier, with the official receipt number when there is one.
  String get supplierText => receiptNo.isEmpty ? payee : '$payee / OR $receiptNo';
}

num _sum(Iterable<Expense> list) => list.fold<num>(0, (s, e) => s + e.amount);

bool _inMonth(Expense e, int y, int m) => e.date.year == y && e.date.month == m;

/// Monthly expense report for the client: summary, every purchase of the month,
/// spending by category against the monthly budget, and spending by facility.
List<DocBlock> monthlyExpenseBlocks(List<Expense> all, DateTime month, num collected) {
  final y = month.year, m = month.month;
  final list = all.where((e) => _inMonth(e, y, m)).toList()..sort((a, b) => a.date.compareTo(b.date));
  final prev = DateTime(y, m - 1, 1);
  final prevTotal = _sum(all.where((e) => _inMonth(e, prev.year, prev.month)));
  final spent = _sum(list);
  final budgetTotal = annualBudget.values.fold<int>(0, (s, v) => s + v);
  final monthlyBudget = budgetTotal / 12;
  final diff = spent - prevTotal;

  final catRows = <List<String>>[];
  for (final c in expenseCategories) {
    final s = _sum(list.where((e) => e.category == c));
    if (s == 0 && !annualBudget.containsKey(c)) continue;
    final b = annualBudget[c];
    catRows.add([
      c,
      peso(s),
      b == null ? '-' : peso(b / 12),
      b == null ? '-' : '${(s / (b / 12) * 100).round()}%',
    ]);
  }
  final areaRows = <List<String>>[];
  for (final a in expenseAreas) {
    final items = list.where((e) => e.area == a).toList();
    if (items.isEmpty) continue;
    areaRows.add([a, '${items.length}', peso(_sum(items))]);
  }

  return [
    const DocBlock.h1('Monthly expense report'),
    DocBlock.p('City Residences Condominium Corporation. Month: ${monthYear(month)}. Prepared ${longDate(DateTime.now())}.'),
    const DocBlock.h2('Summary'),
    DocBlock.table([
      const ['Item', 'Amount'],
      ['Total spent this month', peso(spent)],
      ['Number of purchases', '${list.length}'],
      ['Spent in ${monthYear(prev)}', peso(prevTotal)],
      ['Change from last month', prevTotal == 0 ? '-' : '${diff >= 0 ? '+' : '-'}${peso(diff.abs())}'],
      ['Monthly budget (annual budget divided by 12)', peso(monthlyBudget)],
      ['Budget used', '${(spent / monthlyBudget * 100).round()}%'],
      ['Dues collected this month', peso(collected)],
      ['Collected less spending', collected - spent < 0 ? '-${peso(spent - collected)}' : peso(collected - spent)],
    ]),
    const DocBlock.h2('Purchases'),
    if (list.isEmpty)
      const DocBlock.p('No purchases were recorded this month.')
    else
      DocBlock.table([
        const ['Date', 'Item', 'Qty', 'Unit price', 'Supplier / OR no.', 'Area', 'Category', 'Amount'],
        for (final e in list)
          [shortDate(e.date), e.item, e.qtyText, peso(e.unitPrice), e.supplierText, e.area, e.category, peso(e.amount)],
        ['', 'Total', '', '', '', '', '', peso(spent)],
      ]),
    const DocBlock.h2('Spending by category'),
    DocBlock.table([
      const ['Category', 'Spent', 'Monthly budget', 'Used'],
      ...catRows,
      ['Total', peso(spent), peso(monthlyBudget), '${(spent / monthlyBudget * 100).round()}%'],
    ]),
    if (areaRows.isNotEmpty) ...[
      const DocBlock.h2('Spending by facility'),
      DocBlock.table([
        const ['Facility or area', 'Purchases', 'Spent'],
        ...areaRows,
      ]),
    ],
  ];
}

/// Year-to-date expense report: every purchase and the spending against the annual budget.
List<DocBlock> expenseReportBlocks(List<Expense> list, num collected) {
  final now = DateTime.now();
  final year = now.year;
  final spent = _sum(list);
  final byCat = <String, num>{
    for (final c in expenseCategories) c: _sum(list.where((e) => e.category == c && e.date.year == year)),
  };
  final budgetTotal = annualBudget.values.fold<int>(0, (s, v) => s + v);
  final spentYear = byCat.values.fold<num>(0, (s, v) => s + v);
  return [
    const DocBlock.h1('Expense report'),
    DocBlock.p('City Residences Condominium Corporation. As of ${longDate(now)}.'),
    const DocBlock.h2('All purchases'),
    if (list.isEmpty)
      const DocBlock.p('No purchases have been recorded yet.')
    else
      DocBlock.table([
        const ['Date', 'Item', 'Qty', 'Supplier / OR no.', 'Area', 'Category', 'Amount'],
        for (final e in list) [shortDate(e.date), e.item, e.qtyText, e.supplierText, e.area, e.category, peso(e.amount)],
      ]),
    DocBlock.h2('Spending in $year against the annual budget'),
    DocBlock.table([
      const ['Category', 'Spent', 'Annual budget', 'Used'],
      for (final c in expenseCategories)
        [
          c,
          peso(byCat[c]!),
          annualBudget.containsKey(c) ? peso(annualBudget[c]!) : '-',
          annualBudget.containsKey(c) ? '${(byCat[c]! / annualBudget[c]! * 100).round()}%' : '-',
        ],
      ['Total expenses', peso(spentYear), peso(budgetTotal), '${(spentYear / budgetTotal * 100).round()}%'],
    ]),
    const DocBlock.h2('Summary'),
    DocBlock.table([
      const ['Item', 'Amount'],
      ['Dues collected (all recorded payments)', peso(collected)],
      ['Purchases recorded', peso(spent)],
      ['Collected less spending', collected - spent < 0 ? '-${peso(spent - collected)}' : peso(collected - spent)],
    ]),
  ];
}
