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

/// A payment proof sent by a resident, waiting for the admin to confirm.
class PaymentProof {
  final int id;
  final String unit, payer, method, reference, date;
  final num amount;
  String status; // Pending | Confirmed | Rejected
  String forText, receiptNo, confirmedOn;

  /// True for a payment the office recorded itself (no "I have paid" message from the resident).
  final bool direct;

  /// For a parking payment: the slot the resident reserved.
  final String slot;
  PaymentProof(this.id, this.unit, this.payer, this.method, this.reference,
      this.date, this.amount,
      {this.status = 'Pending',
      this.forText = '',
      this.receiptNo = '',
      this.confirmedOn = '',
      this.direct = false,
      this.slot = ''});

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
        if (direct) 'direct': true,
        if (slot.isNotEmpty) 'slot': slot,
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
      forText: s('forText'),
      receiptNo: s('receiptNo'),
      confirmedOn: s('confirmedOn'),
      direct: j['direct'] == true,
      slot: s('slot'),
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
