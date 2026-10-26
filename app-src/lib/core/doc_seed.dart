// Builds the live documents (collection report, statement of account) from the current data.

import 'app_state.dart';
import 'doc_model.dart';
import 'expenses.dart';
import 'payments.dart';

/// The reports that are built from the app's data each time they are opened.
/// Nothing else ships with the app: the administrator uploads the real documents.
List<DocItem> liveDocs() => [
      DocItem(
        'Collection Report',
        'Finance',
        'Live report',
        audience: 'admin',
        live: collectionReport,
      ),
      DocItem(
        'My Statement of Account',
        'Finance',
        'Live statement',
        audience: 'resident',
        live: statementOfAccount,
      ),
      DocItem(
        'Payment History (all units)',
        'Finance',
        'Live record',
        audience: 'admin',
        live: () => paymentHistoryBlocks('Payment history', app.payments),
      ),
      DocItem(
        'My Payment History',
        'Finance',
        'Live record',
        audience: 'resident',
        live: () => paymentHistoryBlocks('Payment history ${app.myUnit}', app.myPayments),
      ),
      DocItem(
        'Monthly Expense Report',
        'Finance',
        'Live report',
        audience: 'admin',
        live: () {
          final n = DateTime.now();
          return monthlyExpenseBlocks(app.expenses, DateTime(n.year, n.month, 1), app.collectedThisMonth);
        },
      ),
      DocItem(
        'Expense Report',
        'Finance',
        'Live report',
        audience: 'admin',
        live: () => expenseReportBlocks(app.expenses, app.totalCollected),
      ),
    ];

/// Live: every charge billed to the units, rebuilt each time it is opened.
List<DocBlock> collectionReport() {
  final dues = app.dues;
  final paid = dues.where((d) => d.paid).fold<num>(0, (s, d) => s + d.amt);
  final unpaid = dues.where((d) => !d.paid).fold<num>(0, (s, d) => s + d.amt);
  return [
    const DocBlock.h1('Dues collection report'),
    DocBlock.p('As of ${longDate(DateTime.now())}.'),
    DocBlock.table([
      const ['Unit', 'Household', 'Charge', 'Amount', 'Status'],
      for (final d in dues) [d.unit, d.name, d.note, peso(d.amt), d.paid ? 'Paid' : 'Unpaid'],
    ]),
    const DocBlock.h2('Summary'),
    DocBlock.table([
      const ['Item', 'Amount'],
      ['Recorded as paid', peso(paid)],
      ['Still outstanding', peso(unpaid)],
      ['Total on this report', peso(paid + unpaid)],
    ]),
    DocBlock.p('${dues.where((d) => !d.paid).length} of ${dues.length} charges are still open.'),
  ];
}

/// Live: the signed-in resident's own dues.
List<DocBlock> statementOfAccount() {
  final rows = app.myDueRows;
  return [
    const DocBlock.h1('Statement of account'),
    DocBlock.p('${app.myUnit} - ${app.myHousehold}'),
    DocBlock.p('As of ${longDate(DateTime.now())}.'),
    DocBlock.table([
      const ['Month', 'Due date', 'Amount', 'Status'],
      for (final r in rows) [r.month, r.due, peso(r.amt), r.status],
    ]),
    DocBlock.p('Balance due: ${peso(app.myBalance)}'),
  ];
}
