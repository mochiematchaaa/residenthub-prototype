// Unit / resident history: everything on record for one unit, in one list (used by the history screen and its Excel export).

import '../core/core.dart';
import '../widgets/widgets.dart' show Tone;

/// One line of a unit's history. [cat] is money, requests, community or office.
class HistEvent {
  final DateTime ts;
  final String cat, kind, title, sub;
  final num? amount;
  final String chip;
  final Tone? tone;
  final PaymentRecord? receipt;
  const HistEvent(this.ts, this.cat, this.kind, this.title, this.sub, {this.amount, this.chip = '', this.tone, this.receipt});
}

const histFilters = ['Everything', 'Dues & payments', 'Requests & repairs', 'Community', 'Office log'];
String histCat(String filter) => const {
      'Dues & payments': 'money',
      'Requests & repairs': 'requests',
      'Community': 'community',
      'Office log': 'office',
    }[filter] ?? '';

Tone _tone(String s) => switch (s) {
      'Approved' || 'Paid' || 'Confirmed' || 'Resolved' || 'Completed' || 'Verified' => Tone.good,
      'Rejected' || 'Denied' || 'Overdue' || 'Open' => Tone.bad,
      'In progress' => Tone.info,
      _ => Tone.warn,
    };

DateTime _on(String text, [DateTime? fallback]) => parseShortDate(text) ?? fallback ?? DateTime.fromMillisecondsSinceEpoch(0);

/// Every record that belongs to [unit], newest first.
List<HistEvent> unitEvents(String unit) {
  final ev = <HistEvent>[];
  for (final d in app.dues.where((d) => d.unit == unit)) {
    final st = d.paid ? 'Paid' : (d.overdue ? 'Overdue' : 'Unpaid');
    final b = d.billed;
    ev.add(HistEvent(
      _on(b, d.id > 1000000000000 ? DateTime.fromMillisecondsSinceEpoch(d.id) : null),
      'money',
      'Charge',
      d.note,
      '${b.isEmpty ? '' : 'Billed $b'}${d.dueDate.isEmpty ? '' : ' · due ${d.dueDate}'}',
      amount: d.amt,
      chip: st,
      tone: _tone(st),
    ));
  }
  for (final p in app.payments.where((p) => p.unit == unit)) {
    ev.add(HistEvent(
      p.when.add(const Duration(milliseconds: 1)),
      'money',
      'Payment',
      'Payment received · ${p.receiptNo}',
      [p.forText, p.method, if (p.reference != '—' && p.reference.isNotEmpty) 'Ref ${p.reference}'].where((x) => x.isNotEmpty).join(' · '),
      amount: p.amount,
      chip: 'Paid',
      tone: Tone.good,
      receipt: p,
    ));
  }
  for (final p in app.proofs.where((p) => p.unit == unit && p.status != 'Confirmed')) {
    ev.add(HistEvent(
      p.sentAt,
      'money',
      'Payment sent',
      'Payment details sent by the resident',
      [p.forText, p.method, 'Ref ${p.reference}', if (p.status == 'Rejected' && p.reason.isNotEmpty) 'Reason: ${p.reason}'].where((x) => x.isNotEmpty).join(' · '),
      amount: p.amount,
      chip: p.status == 'Pending' ? 'Waiting' : p.status,
      tone: _tone(p.status),
    ));
  }
  for (final b in app.bookings.where((b) => b.unit == unit)) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(b.day);
    ev.add(HistEvent(
      m == null ? DateTime.fromMillisecondsSinceEpoch(b.id > 1000000000000 ? b.id : 0) : DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!)),
      'community',
      'Booking',
      'Booked ${b.place}',
      b.when,
      chip: b.status,
      tone: _tone(b.status),
    ));
  }
  for (final g in app.grievances.where((g) => g.by == unit)) {
    ev.add(HistEvent(
      DateTime.fromMillisecondsSinceEpoch(g.id > 1000000000000 ? g.id : 0),
      'requests',
      'Complaint',
      g.title,
      g.body.length > 140 ? '${g.body.substring(0, 140)}…' : g.body,
      chip: g.statusLabel,
      tone: _tone(g.statusLabel),
    ));
  }
  for (final q in app.parking.where((q) => q.unit == unit)) {
    ev.add(HistEvent(
      DateTime.fromMillisecondsSinceEpoch(q.at > 1000000000000 ? q.at : 0),
      'requests',
      'Parking',
      'Motor parking request${q.slot.isEmpty ? '' : ' · slot ${q.slot}'}',
      '${q.plan == 'month' ? 'Monthly' : 'By the day'}${q.amount > 0 ? ' · ${peso(q.amount)}' : ''}',
      chip: q.confirmed ? 'Approved' : 'Pending',
      tone: q.confirmed ? Tone.good : Tone.warn,
    ));
  }
  for (final a in app.activityLog.where((a) => a.title.contains(unit))) {
    ev.add(HistEvent(a.at, 'office', 'Office', a.title, a.area));
  }
  ev.sort((a, b) => b.ts.compareTo(a.ts));
  return ev;
}

/// The numbers at the top of a unit's history.
class UnitSummary {
  final Unit unit;
  final UnitDues dues;
  final List<Due> charges, open;
  final List<PaymentRecord> payments; // newest first
  final int overdue, openRequests;
  final String slot;
  final List<Account> accounts;
  UnitSummary(this.unit, this.dues, this.charges, this.open, this.payments, this.overdue, this.openRequests, this.slot, this.accounts);
  PaymentRecord? get last => payments.isEmpty ? null : payments.first;
}

UnitSummary? unitSummary(String name) {
  final u = app.units.where((u) => u.unit == name).firstOrNull;
  if (u == null) return null;
  final charges = app.dues.where((d) => d.unit == name).toList()..sort((a, b) => b.id.compareTo(a.id));
  final open = charges.where((d) => !d.paid).toList();
  final pays = app.payments.where((p) => p.unit == name).toList()..sort((a, b) => b.when.compareTo(a.when));
  return UnitSummary(
    u,
    app.unitDues(u),
    charges,
    open,
    pays,
    open.where((d) => d.overdue).length,
    app.grievances.where((g) => g.by == name && g.stage < 2).length,
    app.slotOf(name)?.id ?? '',
    [for (final a in app.residentAccounts) if (a.unit == name) a],
  );
}
