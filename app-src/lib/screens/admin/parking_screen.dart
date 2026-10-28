// ADMIN page: Parking (slots, requests, rentals).

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../widgets/widgets.dart';
import '../shared/import_sheet.dart';
import '../shared/payment_widgets.dart';

/// Administrator: the motor parking slots and the residents asking for one.
class AdminParking extends StatefulWidget {
  const AdminParking({super.key});

  @override
  State<AdminParking> createState() => _AdminParkingState();
}

class _AdminParkingState extends State<AdminParking> {
  /// 0 Requests, 1 Slots, 2 Current rentals (each is its own section so the page stays clear).
  int _tab = 0;

  static const _monthly = 'Monthly (1 month)';
  static const _daily = 'Daily (by the day)';

  /// Changes a request: the slot, the rental and the amount.
  void _editRequest(BuildContext context, ParkingReq p) {
    final ids = [
      for (final x in app.slots)
        if (!x.used && (app.heldSlots[x.id] == null || app.heldSlots[x.id] == p.unit)) x.id,
    ];
    if (p.slot.isNotEmpty && !ids.contains(p.slot)) ids.insert(0, p.slot);
    const none = 'No slot chosen';
    if (p.slot.isEmpty) ids.insert(0, none);
    showFormSheet(
      context,
      title: 'Edit request · ${p.unit}',
      subtitle: 'Change the slot, the rental or the amount before you assign it. Leave the amount as it is to use the price of the slot size.',
      choices: [
        ChoiceSpec('slot', 'Slot', ids, p.slot.isEmpty ? none : p.slot),
        ChoiceSpec('plan', 'Rental', const [_monthly, _daily], p.plan == 'day' ? _daily : _monthly),
      ],
      fields: [
        FieldSpec('days', 'Number of days', type: TextInputType.number, initial: '${p.days < 1 ? 1 : p.days}', onlyWhenKey: 'plan', onlyWhenValue: _daily),
        FieldSpec('amount', 'Amount (PHP)', type: TextInputType.number, initial: p.amount > 0 ? '${p.amount}' : ''),
      ],
      submit: 'Save changes',
      onSubmit: (v) {
        final slot = v['slot'] == none ? '' : '${v['slot']}';
        final daily = v['plan'] == _daily;
        final days = int.tryParse('${v['days'] ?? ''}'.trim()) ?? 0;
        return app.editParkingRequest(p, slot, daily ? 'day' : 'month', days, '${v['amount'] ?? ''}');
      },
    );
  }

  /// Changes a current rental: who rents, monthly or daily, the dates and the amount.
  void _editRental(BuildContext context, ParkingSlot s) {
    showFormSheet(
      context,
      title: 'Edit rental · ${s.id}',
      subtitle: 'Change who rents this slot, the dates or the amount. Use a unit name such as "Unit 12A".',
      choices: [ChoiceSpec('plan', 'Rental', const [_monthly, _daily], s.daily ? _daily : _monthly)],
      fields: [
        FieldSpec('unit', 'Unit', initial: s.unit),
        FieldSpec('from', 'Start date', hint: shortDate(DateTime.now()), initial: s.from.isEmpty ? shortDate(DateTime.now()) : isoShort(s.from)),
        FieldSpec('until', 'End date', hint: 'Leave empty for one month', initial: s.until.isEmpty ? '' : isoShort(s.until)),
        FieldSpec('amount', 'Amount (PHP)', type: TextInputType.number, initial: s.amount > 0 ? '${s.amount}' : ''),
      ],
      submit: 'Save changes',
      onSubmit: (v) => app.editRental(
        s,
        unitRaw: '${v['unit'] ?? ''}',
        plan: v['plan'] == _daily ? 'day' : 'month',
        fromRaw: '${v['from'] ?? ''}',
        untilRaw: '${v['until'] ?? ''}',
        amountRaw: '${v['amount'] ?? ''}',
      ),
    );
  }

  /// Walk-in: the resident pays at the counter (cash, check, card or e-wallet). Records the payment (receipt), gives the slot, texts the resident.
  void _officePay(BuildContext context, ParkingReq p) {
    showFormSheet(
      context,
      title: 'Walk-in payment · ${p.unit}',
      subtitle: 'Slot ${p.slot}. Enter what the office received. A receipt is issued, the slot is assigned and the resident gets a text with the next due date.',
      choices: [ChoiceSpec('via', 'Paid at the counter by', AppState.walkinOptions, AppState.walkinOptions.first)],
      fields: [
        FieldSpec('amount', 'Amount received (PHP)', type: TextInputType.number, initial: p.amount > 0 ? '${p.amount}' : ''),
        const FieldSpec('ref', 'Receipt or reference no. (optional)'),
      ],
      submit: 'Record payment and assign',
      onSubmit: (v) {
        final err = app.parkingOfficePayment(p, '${v['amount'] ?? ''}', '${v['ref'] ?? ''}', via: '${v['via'] ?? 'Cash'}');
        if (err == null) msg(context, 'Payment recorded. ${p.slot} is now assigned to ${p.unit}. ${app.lastSmsNote}');
        return err;
      },
    );
  }

  /// Walk-in to renew a monthly rental.
  void _renewPay(BuildContext context, ParkingSlot s) {
    final d = parkDueOf(s);
    showFormSheet(
      context,
      title: 'Renew ${s.id} · ${s.unit}',
      subtitle: '${d != null ? 'The rental runs until ${isoShort(d.until)}; one more month is added. ' : ''}Recording it issues a receipt, extends the rental and sends the resident a text with the next due date.',
      choices: [ChoiceSpec('via', 'Paid at the counter by', AppState.walkinOptions, AppState.walkinOptions.first)],
      fields: [
        FieldSpec('amount', 'Amount received (PHP)', type: TextInputType.number, initial: '${app.parkRenewAmount(s)}'),
        const FieldSpec('ref', 'Receipt or reference no. (optional)'),
      ],
      submit: 'Record payment and renew',
      onSubmit: (v) {
        final err = app.parkingRenewOfficePayment(s, '${v['amount'] ?? ''}', '${v['via'] ?? 'Cash'}', '${v['ref'] ?? ''}');
        if (err == null) msg(context, 'Payment recorded. ${s.id} is renewed until ${isoShort(s.until)}. ${app.lastSmsNote}');
        return err;
      },
    );
  }

  void _rejectPayment(BuildContext context, PaymentProof proof) {
    showFormSheet(
      context,
      title: 'Reject payment details',
      subtitle: '${proof.unit} · ${proof.method} · Ref. ${proof.reference}. Tell the resident what is wrong. They can send the correct details.',
      fields: const [FieldSpec('reason', 'Reason', hint: 'e.g. Reference number not found. Please check it.', lines: 3)],
      submit: 'Reject',
      onSubmit: (v) {
        final reason = (v['reason'] as String).trim();
        if (reason.isEmpty) return 'Enter the reason so the resident knows what to correct.';
        app.rejectProof(proof, reason);
        return null;
      },
    );
  }

  Widget _fact(BuildContext context, String label, String value) => SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: TextStyle(color: muted(context), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ],
        ),
      );

  void _rename(BuildContext context, ParkingSlot s) {
    showFormSheet(
      context,
      title: 'Rename ${s.id}',
      subtitle: 'Use the name painted on the parking space, e.g. B1-05. The resident keeps the slot.',
      fields: [FieldSpec('name', 'Slot name', initial: s.id)],
      submit: 'Save',
      onSubmit: (v) => app.renameSlot(s, v['name'] as String),
    );
  }

  /// Changes the size of a slot. The size decides the price for the next resident.
  void _size(BuildContext context, ParkingSlot s) {
    final labels = {
      for (final z in app.parkSizes) '${z.name} · ${z.sqm > 0 ? '${z.sqm} sqm · ' : ''}${peso(z.month)}/month': z.name,
    };
    final current = labels.entries.firstWhere((e) => e.value == s.size, orElse: () => labels.entries.first).key;
    showFormSheet(
      context,
      title: 'Size of ${s.id}',
      subtitle: 'The rental price follows the size. ${s.used ? 'The current resident keeps the amount they already pay.' : 'The next resident pays the rate of this size.'}',
      choices: [ChoiceSpec('size', 'Slot size', labels.keys.toList(), current)],
      submit: 'Save',
      onSubmit: (v) {
        app.setSlotSize(s, labels[v['size']] ?? 'Regular');
        return null;
      },
    );
  }

  void _assign(BuildContext context, ParkingSlot s) {
    final unitsList = [for (final u in app.units) if (app.slotOf(u.unit) == null) u.unit];
    if (unitsList.isEmpty) {
      msg(context, 'Every unit already has a slot.');
      return;
    }
    showFormSheet(
      context,
      title: 'Assign ${s.id}',
      subtitle: 'Choose the unit that gets this slot and how long it rents it.',
      choices: [
        ChoiceSpec('unit', 'Unit', unitsList, unitsList.first),
        const ChoiceSpec('plan', 'Rental', ['Monthly (1 month)', 'Daily (by the day)'], 'Monthly (1 month)'),
      ],
      fields: const [
        FieldSpec('days', 'Number of days', type: TextInputType.number, initial: '1', onlyWhenKey: 'plan', onlyWhenValue: 'Daily (by the day)'),
      ],
      submit: 'Assign slot',
      onSubmit: (v) {
        final daily = v['plan'] == 'Daily (by the day)';
        final days = int.tryParse('${v['days'] ?? ''}'.trim()) ?? 0;
        if (daily && (days < 1 || days > 365)) return 'Enter 1 to 365 days.';
        app.assignSlot(s, v['unit'] as String, plan: daily ? 'day' : 'month', days: days);
        return null;
      },
    );
  }

  /// Takes the resident off a slot after the admin confirms. The rental ends and the slot is free.
  Future<void> _remove(BuildContext context, ParkingSlot s) async {
    final unit = s.unit;
    final ok = await confirmDialog(
      context,
      'Remove $unit from ${s.id}?',
      'The ${s.daily ? 'daily' : 'monthly'} rental ends now and ${s.id} becomes free for other residents. Nothing is refunded automatically.',
      confirm: 'Remove',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    app.releaseSlot(s);
    msg(context, '$unit removed. ${s.id} is free.');
  }

  /// Tap a slot: assign it or remove the resident, rename it, or delete it.
  void _slotSheet(BuildContext context, ParkingSlot s) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (sheet) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text(s.used ? '${s.id} · ${s.unit}' : '${s.id} · Free', style: hd(20)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: Text(
                '${s.size} slot · ${peso(app.parkRatesFor(s.size).month)}/month${app.parkRatesFor(s.size).day > 0 ? ' · ${peso(app.parkRatesFor(s.size).day)}/day' : ''}',
                style: TextStyle(color: muted(context), fontSize: 12.5),
              ),
            ),
            if (s.used)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                child: Text('${s.rentalLine}${s.ended ? ' (ended)' : ''}${s.amount > 0 ? ' · ${peso(s.amount)}' : ''}', style: TextStyle(color: muted(context), fontSize: 12.5)),
              ),
            if (s.used)
              ListTile(
                leading: const Icon(Icons.edit_calendar_outlined),
                title: const Text('Edit rental'),
                subtitle: const Text('Change the unit, dates or amount'),
                onTap: () {
                  Navigator.pop(sheet);
                  _editRental(context, s);
                },
              ),
            if (s.used)
              ListTile(
                leading: const Icon(Icons.person_remove_alt_1_rounded, color: danger),
                title: const Text('Remove resident', style: TextStyle(color: danger)),
                subtitle: Text('End ${s.unit}\'s rental and free the slot'),
                onTap: () {
                  Navigator.pop(sheet);
                  _remove(context, s);
                },
              )
            else
              ListTile(
                leading: const Icon(Icons.person_add_alt_1_rounded),
                title: const Text('Assign to a unit'),
                onTap: () {
                  Navigator.pop(sheet);
                  _assign(context, s);
                },
              ),
            ListTile(
              leading: const Icon(Icons.straighten_rounded),
              title: Text('Size: ${s.size}'),
              subtitle: const Text('Change the slot size and its price'),
              onTap: () {
                Navigator.pop(sheet);
                _size(context, s);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(sheet);
                _rename(context, s);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: danger),
              title: const Text('Delete slot', style: TextStyle(color: danger)),
              onTap: () async {
                Navigator.pop(sheet);
                final ok = await confirmDialog(
                  context,
                  'Delete ${s.id}?',
                  s.used
                      ? '${s.id} is assigned to ${s.unit}. Deleting it takes the slot away from them and removes it from the parking area.'
                      : 'The slot is removed from the parking area. Nobody is using it.',
                  confirm: 'Delete',
                  destructive: true,
                );
                if (ok) app.removeSlot(s);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// One request. A reserved slot is assigned once its payment is verified (or paid at the office).
  Widget _request(BuildContext context, ParkingReq p) {
    final proof = p.slot.isNotEmpty ? app.parkingProofFor(p.unit, p.slot) : null;
    final paid = proof?.status == 'Confirmed';
    final reserved = p.slot.isNotEmpty && p.amount > 0;
    final walk = app.walkinOf(p.unit);
    final t = toneOf(context, (proof == null && walk == null) ? Tone.info : Tone.warn);
    final List<Widget> actions = [];
    if (reserved && proof != null && !paid) {
      actions.addAll([
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 38)),
          onPressed: () {
            app.confirmProof(proof);
            msg(context, 'Payment verified. ${p.slot} is now assigned to ${p.unit}. ${app.lastSmsNote}');
          },
          child: Text('Verify and assign ${p.slot}'),
        ),
        TextButton(style: TextButton.styleFrom(foregroundColor: danger), onPressed: () => _rejectPayment(context, proof), child: const Text('Reject payment')),
      ]);
    } else if (reserved && !paid) {
      actions.add(OutlinedButton(
        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38)),
        onPressed: () => _officePay(context, p),
        child: Text(walk != null ? 'Record walk-in payment' : 'Walk-in payment'),
      ));
    } else {
      actions.add(FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size(0, 38)),
        onPressed: () {
          final err = app.assignRequest(p);
          if (err != null) msg(context, err);
        },
        child: Text(p.slot.isNotEmpty ? 'Assign ${p.slot}' : 'Assign'),
      ));
    }
    actions.addAll([
      TextButton(onPressed: () => _editRequest(context, p), child: const Text('Edit')),
      TextButton(onPressed: () => app.declineParking(p), child: const Text('Decline')),
    ]);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text('${p.unit} · ${p.name}', style: const TextStyle(fontWeight: FontWeight.w800))),
            if (p.amount > 0) Text(peso(p.amount), style: hd(18)),
          ]),
          const SizedBox(height: 2),
          Text(
            p.slot.isNotEmpty
                ? 'Slot ${p.slot} (${app.slotSize(p.slot)}) · ${parkPlanText(p.plan, p.days)} · requested ${p.when}'
                : (app.freeSlot == null ? 'No free slot right now' : 'Next free slot: ${app.freeSlot!.id}'),
            style: TextStyle(color: muted(context), fontSize: 12.5),
          ),
          if (reserved) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(14)),
              child: proof == null
                  ? Text(
                      walk != null
                          ? 'Walk-in. ${app.walkinText(walk, p.name.isEmpty ? p.unit : p.name)} They pay at the counter. Record it when they do (cash, check, card or e-wallet). The slot is assigned and they get a text with the next due date.'
                          : 'No payment yet. The resident pays on the Parking page, or taps Walk-in to pay at the office. The slot is only assigned after payment.',
                      style: TextStyle(color: t.fg, fontSize: 12.5, height: 1.35))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(paid ? 'PAYMENT VERIFIED' : 'PAYMENT TO CHECK', style: TextStyle(color: t.fg, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                        const SizedBox(height: 8),
                        Wrap(spacing: 12, runSpacing: 10, children: [
                          _fact(context, 'Method', proof.method),
                          _fact(context, 'Reference no.', proof.reference.isEmpty ? '—' : proof.reference),
                          _fact(context, 'Amount sent', peso(proof.amount)),
                          _fact(context, 'Date paid', proof.paidOn.isEmpty ? 'Not given' : proof.paidOn),
                          _fact(context, 'Sent', clockText(proof.sentAt)),
                          SizedBox(
                            width: 140,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('SCREENSHOT', style: TextStyle(color: muted(context), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                                const SizedBox(height: 2),
                                if (proofImageBytes(proof.image) != null)
                                  InkWell(
                                    onTap: () => showProofImage(context, proof),
                                    child: Row(children: [
                                      ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(proofImageBytes(proof.image)!, width: 44, height: 44, fit: BoxFit.cover)),
                                      const SizedBox(width: 8),
                                      const Text('View', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, decoration: TextDecoration.underline)),
                                    ]),
                                  )
                                else
                                  Text('None attached', style: TextStyle(color: muted(context), fontWeight: FontWeight.w600, fontSize: 13)),
                              ],
                            ),
                          ),
                        ]),
                        const SizedBox(height: 10),
                        Wrap(spacing: 6, runSpacing: 6, children: [
                          Pill(proof.amount == p.amount ? '✓ Amount matches' : '✕ Expected ${peso(p.amount)}', tone: proof.amount == p.amount ? Tone.good : Tone.bad),
                          if (paid) Pill('Receipt ${proof.receiptNo}', tone: Tone.good),
                        ]),
                      ],
                    ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 4, children: actions),
        ],
      ),
    );
  }

  /// The payment details of a renewal (same facts as for a new request).
  Widget _payFacts(BuildContext context, PaymentProof proof, ({Color bg, Color fg}) t, num expected) {
    final match = proof.amount == expected;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PAYMENT TO CHECK', style: TextStyle(color: t.fg, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
          const SizedBox(height: 8),
          Wrap(spacing: 12, runSpacing: 10, children: [
            _fact(context, 'Method', proof.method),
            _fact(context, 'Reference no.', proof.reference.isEmpty ? '—' : proof.reference),
            _fact(context, 'Amount sent', peso(proof.amount)),
            _fact(context, 'Date paid', proof.paidOn.isEmpty ? 'Not given' : proof.paidOn),
            _fact(context, 'Sent', clockText(proof.sentAt)),
            SizedBox(
              width: 140,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SCREENSHOT', style: TextStyle(color: muted(context), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                  const SizedBox(height: 2),
                  if (proofImageBytes(proof.image) != null)
                    InkWell(
                      onTap: () => showProofImage(context, proof),
                      child: Row(children: [
                        ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(proofImageBytes(proof.image)!, width: 44, height: 44, fit: BoxFit.cover)),
                        const SizedBox(width: 8),
                        const Text('View', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, decoration: TextDecoration.underline)),
                      ]),
                    )
                  else
                    Text('None attached', style: TextStyle(color: muted(context), fontWeight: FontWeight.w600, fontSize: 13)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Pill(match ? '✓ Amount matches' : '✕ Expected ${peso(expected)}', tone: match ? Tone.good : Tone.bad),
        ],
      ),
    );
  }

  /// A rental that needs the office: a renewal payment, a walk-in, or a resident who will not renew.
  Widget _renewalCard(BuildContext context, ({ParkingSlot slot, PaymentProof? proof, Walkin? walkin, String? leave}) x) {
    final s = x.slot;
    final d = parkDueOf(s);
    final amt = app.parkRenewAmount(s);
    final t = toneOf(context, x.leave != null ? Tone.info : Tone.warn);
    final actions = <Widget>[];
    Widget body;
    if (x.leave != null) {
      body = Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(14)),
        child: Text(
          'The resident told the office they will not renew.${x.leave!.isEmpty ? '' : ' “${x.leave}”'} The slot stays theirs until ${isoShort(s.until)}. After that, remove them from Current rentals to free it.',
          style: TextStyle(color: t.fg, fontSize: 12.5, height: 1.35),
        ),
      );
    } else if (x.proof != null) {
      body = _payFacts(context, x.proof!, t, amt);
      actions.addAll([
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 38)),
          onPressed: () {
            app.confirmProof(x.proof!);
            msg(context, 'Payment verified. ${s.id} is renewed until ${isoShort(s.until)}. ${app.lastSmsNote}');
          },
          child: Text('Verify and renew ${s.id}'),
        ),
        TextButton(style: TextButton.styleFrom(foregroundColor: danger), onPressed: () => _rejectPayment(context, x.proof!), child: const Text('Reject payment')),
      ]);
    } else {
      body = Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(14)),
        child: Text('Walk-in. ${app.walkinText(x.walkin!, s.unit)} They pay at the counter. Record it when they do (cash, check, card or e-wallet).', style: TextStyle(color: t.fg, fontSize: 12.5, height: 1.35)),
      );
      actions.add(FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 38)), onPressed: () => _renewPay(context, s), child: const Text('Record walk-in payment')));
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: Theme.of(context).dividerColor), color: Theme.of(context).colorScheme.surface),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text('${s.unit} · renewal of ${s.id}', style: const TextStyle(fontWeight: FontWeight.w800))),
            Text(peso(amt), style: hd(18)),
          ]),
          const SizedBox(height: 2),
          Text(
            'Runs until ${isoShort(s.until)}${d != null ? ' · next payment due ${isoShort(d.nextDue)} (${parkDaysText(d.days)})' : ''}',
            style: TextStyle(color: muted(context), fontSize: 12.5),
          ),
          const SizedBox(height: 10),
          body,
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 4, children: actions),
          ],
        ],
      ),
    );
  }

  /// The texts sent to residents (the prototype only saves them; a real SMS service would deliver them).
  Widget _smsLog(BuildContext context) {
    final l = app.smsLog.take(6).toList();
    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Text messages to residents', style: hd(17)),
          const SizedBox(height: 4),
          Text(
            'When a parking payment is approved, the resident gets a text with the rental period and the next due date. In this prototype the text is saved here and shown on the resident\'s dashboard; connecting an SMS service would send it to their phone.',
            style: TextStyle(color: muted(context), fontSize: 12.5, height: 1.4),
          ),
          if (l.isEmpty)
            Padding(padding: const EdgeInsets.only(top: 8), child: Text('No texts yet.', style: TextStyle(color: muted(context))))
          else
            for (final m in l)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${m.unit} · ${m.to.isEmpty ? 'no mobile number' : m.to} · ${clockText(DateTime.fromMillisecondsSinceEpoch(m.at))} · ${m.status}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                    Text(m.text, style: TextStyle(color: muted(context), fontSize: 12, height: 1.35)),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _requestsTab(BuildContext context, List<ParkingReq> waiting) {
    final renewals = app.parkRenewals;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (renewals.isNotEmpty) ...[
          Text('Renewals', style: hd(16)),
          const SizedBox(height: 8),
          for (final x in renewals) _renewalCard(context, x),
          if (waiting.isNotEmpty) Text('New requests', style: hd(16)),
          if (waiting.isNotEmpty) const SizedBox(height: 8),
        ],
        if (waiting.isEmpty)
          const EmptyBox('No new requests waiting.', icon: Icons.two_wheeler_outlined)
        else
          for (final p in waiting) _request(context, p),
        const SizedBox(height: 4),
        _smsLog(context),
      ],
    );
  }

  List<Widget> _slotsTab(BuildContext context) => [
            Row(
              children: [
                Expanded(child: Text('Slots', style: hd(18))),
                TextButton.icon(
                  onPressed: () => showFormSheet(
                    context,
                    title: 'Add parking slots',
                    subtitle: app.slots.isEmpty ? 'How many motor parking slots does the building have?' : 'You have ${app.slots.length} slots. How many more should be added?',
                    choices: [ChoiceSpec('size', 'Slot size', [for (final z in app.parkSizes) z.name], 'Regular')],
                    fields: const [FieldSpec('n', 'Number of slots', type: TextInputType.number, hint: 'e.g. 24')],
                    submit: 'Add slots',
                    onSubmit: (v) => app.addSlots(v['n'] as String, size: v['size'] as String),
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add slots'),
                ),
              ],
            ),
            if (app.slots.isEmpty)
              const EmptyBox('No slots yet. Tap "Add slots" to set up the parking area.', icon: Icons.local_parking_rounded)
            else
              Text('Tap a slot to assign, edit the rental, release, rename or delete it.', style: TextStyle(color: muted(context), fontSize: 12.5)),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.05,
              children: [
                for (final s in app.slots)
                  Builder(builder: (context) {
                    final held = app.heldSlots[s.id];
                    final t = toneOf(context, s.used ? Tone.bad : (held != null ? Tone.warn : Tone.good));
                    return GestureDetector(
                      onTap: () => _slotSheet(context, s),
                      child: Container(
                        decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(14)),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.all(4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(s.id, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: t.fg)),
                            Text(s.used ? s.unit.replaceFirst('Unit ', '') : (held != null ? 'Held ${held.replaceFirst('Unit ', '')}' : 'Free'),
                                maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: t.fg)),
                            Text(s.size, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9.5, color: t.fg.withValues(alpha: 0.7))),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
            RCard(
              child: Text(
                'The price depends on the size of the slot: ${[for (final z in app.parkSizes) '${z.name} ${peso(z.month)}/month'].join(' · ')}. Change the rates under Finance > Settings. Residents reserve a slot from their Parking page.',
                style: TextStyle(color: muted(context), fontSize: 12.5, height: 1.4),
              ),
            ),
      ];

  List<Widget> _rentalsTab(BuildContext context, List<ParkingSlot> rented) => [
            if (rented.isEmpty)
              const EmptyBox('No slot is rented yet.', icon: Icons.two_wheeler_outlined)
            else
              RCard(
                child: Column(
                  children: [
                    for (final s in rented)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${s.unit} · ${s.id} (${s.size})${s.amount > 0 ? ' · ${peso(s.amount)}' : ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                  Text(
                                    s.until.isEmpty ? '${s.daily ? 'Daily' : 'Monthly'} · no end date' : '${s.daily ? 'Daily' : 'Monthly'} · ${isoShort(s.from)} – ${isoShort(s.until)}',
                                    style: TextStyle(color: muted(context), fontSize: 12.5),
                                  ),
                                  if (parkDueOf(s) != null)
                                    Text('Next payment due ${isoShort(parkDueOf(s)!.nextDue)} (${parkDaysText(parkDueOf(s)!.days)})', style: TextStyle(color: muted(context), fontSize: 12.5)),
                                  const SizedBox(height: 4),
                                  Wrap(spacing: 6, runSpacing: 4, children: [
                                    if (s.ended)
                                      const Pill('Ended', tone: Tone.bad)
                                    else if (parkDueOf(s)?.soon ?? false)
                                      const Pill('Renewal due soon', tone: Tone.warn)
                                    else
                                      const Pill('Active', tone: Tone.good),
                                    if (app.leaveNotes.containsKey(s.unit)) const Pill('Will not renew', tone: Tone.info),
                                  ]),
                                ],
                              ),
                            ),
                            if (!s.daily) TextButton(onPressed: () => _renewPay(context, s), child: const Text('Renew')),
                            TextButton(onPressed: () => _editRental(context, s), child: const Text('Edit')),
                            TextButton(
                              style: TextButton.styleFrom(foregroundColor: danger),
                              onPressed: () => _remove(context, s),
                              child: const Text('Remove'),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
      ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final waiting = app.parking.where((p) => !p.confirmed).toList();
        final free = app.freeSlotCount;
        final rented = app.slots.where((s) => s.used).toList()..sort((a, b) => naturalCompare(a.unit, b.unit));
        return SubPage(
          title: 'Motor parking',
          subtitle: 'Assign slots to residents and release them when they are done.',
          children: [
            const ImportBar(['slots']),
            PastelCard(
              color: Pastel.peach,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: StatsRow([
                ['In use', '${app.slotsUsed}'],
                ['Free', '$free'],
                ['Waiting', '${waiting.length + app.parkRenewals.length}'],
                ['Monthly income', peso(app.slots.where((x) => x.used && !x.daily && !x.ended).fold<num>(0, (t, x) => t + (x.amount > 0 ? x.amount : app.parkRatesFor(x.size).month)))],
              ]),
            ),
            SubTabs(
              items: [
                SubTabItem('Requests', count: waiting.length + app.parkRenewals.length, hot: waiting.isNotEmpty || app.parkRenewals.isNotEmpty),
                SubTabItem('Slots', count: app.slots.length),
                SubTabItem('Current rentals', count: rented.length),
              ],
              index: _tab,
              onChanged: (i) => setState(() => _tab = i),
            ),
            if (_tab == 0) _requestsTab(context, waiting),
            if (_tab == 1) ..._slotsTab(context),
            if (_tab == 2) ..._rentalsTab(context, rented),
          ],
        );
      },
    );
  }
}
