// Payment models: payment methods, payment records (receipts) and payment proofs sent by residents.

import 'app_state.dart' show peso;
import 'doc_model.dart';

/// A way residents can pay their dues (shown under Dues & payment).
/// The details are sample text - the administrator edits them in Finance.
class PayMethod {
  final String name;
  String details;
  bool enabled;
  PayMethod(this.name, this.details, {this.enabled = true});
}

/// A payment the administrator has recorded. This is the proof of payment
/// (receipt) that can be opened and downloaded as Word or Excel.
class PaymentRecord {
  final int id;
  final String receiptNo, unit, payer, forText, method, reference, date;
  final num amount;
  const PaymentRecord(this.id, this.receiptNo, this.unit, this.payer,
      this.forText, this.method, this.reference, this.date, this.amount);

  /// The date paid, read back from [date] (e.g. "Aug 12, 2026").
  DateTime get when {
    final m = RegExp(r'^([A-Za-z]{3}) (\d{1,2}), (\d{4})$').firstMatch(date);
    if (m == null) return DateTime.fromMillisecondsSinceEpoch(0);
    const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return DateTime(int.parse(m[3]!), names.indexOf(m[1]!) + 1, int.parse(m[2]!));
  }
}

/// A resident's "I have paid" message with the reference number, waiting for
/// the administrator to check it.
/// What a motor parking payment is for. Same text as the website.
const parkingPayFor = 'Motor parking rental';

/// The parking sticker fee and the parking rental are one thing. Older records are read under the one name.
String normPayFor(String t) => t == 'Parking sticker fee' ? parkingPayFor : t;

/// A payment proof sent by a resident, waiting for the admin to confirm.
class PaymentProof {
  final int id;
  final String unit, payer, method, reference, date;
  final num amount;
  String status; // Pending | Confirmed | Rejected
  String forText, receiptNo, confirmedOn;

  /// Why the administrator rejected it (shown to the resident, kept in the record).
  String reason, rejectedOn;

  /// True for a payment the office recorded itself (no "I have paid" message from the resident).
  final bool direct;

  /// For a parking payment: the slot the resident reserved.
  String slot;

  /// When the resident sent it (milliseconds, 0 = unknown, then the date is used), and whether the
  /// system posted it by itself after the waiting time.
  final int at;
  bool auto;

  /// A photo of the online payment the resident attached (a "data:image/..." text, so the website shows it too). Empty = none.
  String image;

  /// The day the resident says they paid, like "Oct 27, 2026" (empty on older records).
  final String paidOn;

  /// True for a payment that renews a monthly parking rental (the slot is already theirs).
  final bool renew;

  /// When the details were sent. Older records only have a date, so 9 AM of that day is used.
  DateTime get sentAt {
    if (at > 1000000000000) return DateTime.fromMillisecondsSinceEpoch(at);
    final m = RegExp(r'^([A-Za-z]{3}) (\d{1,2}), (\d{4})$').firstMatch(date);
    if (m == null) return DateTime.now();
    const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return DateTime(int.parse(m[3]!), names.indexOf(m[1]!) + 1, int.parse(m[2]!), 9);
  }

  PaymentProof(this.id, this.unit, this.payer, this.method, this.reference,
      this.date, this.amount,
      {this.status = 'Pending',
      this.forText = '',
      this.receiptNo = '',
      this.confirmedOn = '',
      this.reason = '',
      this.rejectedOn = '',
      this.direct = false,
      this.slot = '',
      this.at = 0,
      this.auto = false,
      this.image = '',
      this.paidOn = '',
      this.renew = false});

  /// Shared with the website through the live database (same field names).
  Map<String, dynamic> toJson() => {
        'id': id,
        'unit': unit,
        'payer': payer,
        'forText': forText,
        'method': method,
        'reference': reference,
        'amount': amount,
        'date': date,
        'status': status,
        'receiptNo': receiptNo,
        if (confirmedOn.isNotEmpty) 'confirmedOn': confirmedOn,
        if (reason.isNotEmpty) 'reason': reason,
        if (rejectedOn.isNotEmpty) 'rejectedOn': rejectedOn,
        if (direct) 'direct': true,
        if (slot.isNotEmpty) 'slot': slot,
        if (at > 0) 'at': at,
        if (image.isNotEmpty) 'image': image,
        if (paidOn.isNotEmpty) 'paidOn': paidOn,
        if (auto) 'auto': true,
        if (renew) 'renew': true,
        if (auto) 'confirmedBy': 'Automatic posting',
      };

  static PaymentProof? fromJson(Map<String, dynamic> j) {
    final id = j['id'];
    final amount = j['amount'];
    if (id is! num) return null;
    String s(String k) => (j[k] ?? '').toString();
    final st = s('status');
    return PaymentProof(
      id.toInt(),
      s('unit'),
      s('payer'),
      s('method'),
      s('reference'),
      s('date'),
      amount is num ? amount : (num.tryParse(amount.toString()) ?? 0),
      status: st == 'Confirmed' || st == 'Rejected' ? st : 'Pending',
      forText: normPayFor(s('forText')),
      receiptNo: s('receiptNo'),
      confirmedOn: s('confirmedOn'),
      reason: s('reason'),
      rejectedOn: s('rejectedOn'),
      direct: j['direct'] == true,
      slot: s('slot'),
      at: j['at'] is num ? (j['at'] as num).toInt() : 0,
      auto: j['auto'] == true,
      image: s('image'),
      paidOn: s('paidOn'),
      renew: j['renew'] == true,
    );
  }
}

/// One receipt as document blocks (shown in the viewer, exported to Word/Excel).
List<DocBlock> receiptBlocks(PaymentRecord p) => [
      const DocBlock.h1('Payment receipt'),
      const DocBlock.p('City Residences Condominium Corporation'),
      DocBlock.table([
        const ['Detail', 'Information'],
        ['Receipt no.', p.receiptNo],
        ['Date paid', p.date],
        ['Unit', p.unit],
        ['Received from', p.payer],
        ['Payment for', p.forText],
        ['Amount', peso(p.amount)],
        ['Payment method', p.method],
        ['Reference no.', p.reference],
        const ['Status', 'Paid'],
      ]),
      const DocBlock.p(
          'This receipt is your proof of payment. Keep a copy for your records.'),
    ];

/// A list of payments as document blocks (payment history export).
List<DocBlock> paymentHistoryBlocks(String title, List<PaymentRecord> list) {
  final total = list.fold<num>(0, (s, p) => s + p.amount);
  return [
    DocBlock.h1(title),
    const DocBlock.p('City Residences Condominium Corporation'),
    DocBlock.table([
      const [
        'Receipt no.', 'Date', 'Unit', 'Paid by', 'Payment for', 'Method', 'Reference no.', 'Amount'
      ],
      for (final p in list)
        [p.receiptNo, p.date, p.unit, p.payer, p.forText, p.method, p.reference, peso(p.amount)],
    ]),
    DocBlock.p('${list.length} payment${list.length == 1 ? '' : 's'} - total ${peso(total)}'),
  ];
}
