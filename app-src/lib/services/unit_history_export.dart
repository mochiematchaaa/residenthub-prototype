// Excel export of one unit's history: a styled workbook with charts (see xlsx_rich.dart).

import 'dart:typed_data';

import '../core/core.dart';
import 'doc_files.dart' show safeFileName, saveBytes;
import 'unit_history.dart';
import 'xlsx_rich.dart';

const _mon = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String _ym(DateTime d) => '${_mon[d.month - 1]} ${d.year}';

/// The workbook for [unit], or null when the unit is not found.
Uint8List? buildUnitHistoryXlsx(String unit) {
  final s = unitSummary(unit);
  if (s == null) return null;
  final events = unitEvents(unit);
  final now = DateTime.now();
  final resident = s.accounts.isNotEmpty ? s.accounts.map((a) => a.name).join(', ') : s.unit.name;

  // last six months of billing and payments
  final months = [for (var i = 5; i >= 0; i--) DateTime(now.year, now.month - i)];
  final billed = <String, num>{for (final m in months) _ym(m): 0};
  final paid = <String, num>{for (final m in months) _ym(m): 0};
  for (final d in s.charges) {
    final b = parseShortDate(d.billed);
    if (b != null && billed.containsKey(_ym(b))) billed[_ym(b)] = billed[_ym(b)]! + d.amt;
  }
  for (final p in s.payments) {
    final k = _ym(p.when);
    if (paid.containsKey(k)) paid[k] = paid[k]! + p.amount;
  }
  final byStatus = <String, int>{};
  for (final d in s.charges) {
    final st = d.paid ? 'Paid' : (d.overdue ? 'Overdue' : 'Unpaid');
    byStatus[st] = (byStatus[st] ?? 0) + 1;
  }

  String date(DateTime t) => t.millisecondsSinceEpoch < 86400000 ? '' : shortDate(t);
  final title = '${s.unit.unit} · $resident';

  final overview = RSheet(
    'Overview',
    'Unit history · ${s.unit.unit}',
    [
      RTable('Key figures', const ['Item', 'Detail'], [
        ['Unit', s.unit.unit],
        ['Resident', resident],
        ['Occupancy', s.unit.type],
        ['Contact', s.unit.contact],
        ['Floor area', s.unit.area > 0 ? '${s.unit.area} sqm' : 'Not set'],
        ['Due day', s.unit.dueDay > 0 ? 'Day ${s.unit.dueDay} of every month' : 'Not set'],
        ['Monthly dues', s.dues.monthly > 0 ? peso(s.dues.monthly) : 'Not set'],
        ['Total billed', peso(s.dues.billed)],
        ['Total paid', peso(s.dues.paid)],
        ['Balance', peso(s.dues.balance)],
        ['Open charges', '${s.open.length} (${s.overdue} overdue)'],
        ['Open requests', '${s.openRequests}'],
        ['Parking slot', s.slot.isEmpty ? 'None' : s.slot],
        ['Last payment', s.last == null ? 'None yet' : '${s.last!.date} · ${peso(s.last!.amount)}'],
        ['Sign-in accounts', s.accounts.isEmpty ? 'None' : s.accounts.map((a) => '${a.name} <${a.email}>').join('; ')],
      ]),
      RTable(
        'Billed and paid, last 6 months',
        const ['Month', 'Billed', 'Paid'],
        [for (final m in months) [_ym(m), billed[_ym(m)]!, paid[_ym(m)]!]],
        kinds: const ['text', 'money', 'money'],
        chart: const RChart('Billed and paid by month (₱)', valueCols: [1, 2], colors: ['5B4FB3', '14A38B']),
      ),
      RTable(
        'Charges by status',
        const ['Status', 'Charges'],
        [for (final e in byStatus.entries) [e.key, e.value]],
        kinds: const ['text', 'int'],
        chart: const RChart('Charges by status', donut: true, colors: ['14A38B', 'F2A33A', 'E5534B']),
      ),
    ],
    note: 'Prepared ${shortDate(now)} · $title',
  );

  final charges = RSheet(
    'Charges',
    'Charges · ${s.unit.unit}',
    [
      RTable(
        'All charges billed to this unit',
        const ['Billed', 'Charge', 'Amount', 'Due', 'Status', 'Reminders'],
        [
          for (final d in s.charges) [d.billed, d.note, d.amt, d.dueDate, d.paid ? 'Paid' : (d.overdue ? 'Overdue' : 'Unpaid'), d.reminders],
        ],
        kinds: const ['text', 'text', 'money', 'text', 'text', 'int'],
      ),
    ],
  );

  final payments = RSheet(
    'Payments',
    'Payments received · ${s.unit.unit}',
    [
      RTable(
        'Receipts issued',
        const ['Date', 'Receipt no.', 'Paid for', 'Method', 'Reference', 'Amount'],
        [for (final p in s.payments) [p.date, p.receiptNo, p.forText, p.method, p.reference, p.amount]],
        kinds: const ['text', 'text', 'text', 'text', 'text', 'money'],
      ),
    ],
    tab: '14A38B',
  );

  final subs = app.proofs.where((p) => p.unit == unit).toList()..sort((a, b) => b.sentAt.compareTo(a.sentAt));
  final submissions = RSheet(
    'Payment submissions',
    'Payment details sent by the resident · ${s.unit.unit}',
    [
      RTable(
        'Everything the resident sent',
        const ['Sent', 'Paid for', 'Method', 'Reference', 'Amount', 'Status', 'Posted', 'Note'],
        [
          for (final p in subs)
            [
              clockText(p.sentAt),
              p.forText,
              p.method,
              p.reference,
              p.amount,
              p.status == 'Confirmed' ? 'Posted' : p.status,
              p.status == 'Confirmed' ? (p.auto ? 'Automatically' : 'By the office') : '',
              p.status == 'Rejected' ? p.reason : '',
            ],
        ],
        kinds: const ['text', 'text', 'text', 'text', 'money', 'text', 'text', 'text'],
      ),
    ],
    tab: 'F2A33A',
  );

  List<List<Object>> evRows(Iterable<HistEvent> list) => [
        for (final e in list) [date(e.ts), e.kind, e.title, e.sub, e.amount ?? '', e.chip],
      ];
  const evHead = ['Date', 'Type', 'What', 'Details', 'Amount', 'Status'];
  const evKinds = ['text', 'text', 'text', 'text', 'money', 'text'];

  final bookings = RSheet('Bookings', 'Facility bookings · ${s.unit.unit}',
      [RTable('Bookings', evHead, evRows(events.where((e) => e.kind == 'Booking')), kinds: evKinds)]);
  final requests = RSheet('Requests and repairs', 'Complaints and requests · ${s.unit.unit}',
      [RTable('Complaints, repairs and parking requests', evHead, evRows(events.where((e) => e.cat == 'requests')), kinds: evKinds)]);
  final office = RSheet('Office log', 'Office log · ${s.unit.unit}',
      [RTable('Actions the office took that mention this unit', evHead, evRows(events.where((e) => e.cat == 'office')), kinds: evKinds)]);
  final timeline = RSheet('Timeline', 'Full timeline · ${s.unit.unit}',
      [RTable('Everything on record, newest first', evHead, evRows(events), kinds: evKinds)],
      tab: '3B3486');

  return buildXlsxRich([overview, charges, payments, submissions, bookings, requests, office, timeline]);
}

/// Builds and saves the workbook. Returns an error text, or null on success (or when the save was cancelled).
Future<String?> exportUnitHistory(String unit) async {
  final bytes = buildUnitHistoryXlsx(unit);
  if (bytes == null) return 'That unit was not found.';
  await saveBytes('${safeFileName('Unit history $unit')}.xlsx', bytes);
  return null;
}
