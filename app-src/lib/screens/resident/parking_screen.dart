// RESIDENT page: Parking (pick and rent a slot).

import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../widgets/widgets.dart';
import '../shared/payment_widgets.dart';

/// Opens the "I have paid" form for the parking slot the resident reserved.
void sendParkingPayment(BuildContext context) {
  final r = app.myParkingReq;
  if (r == null || r.slot.isEmpty) return;
  final methods = [for (final m in app.enabledPayMethods) if (m.name != AppState.officePay) m.name];
  if (methods.isEmpty) {
    msg(context, 'Online payment options are not set up yet. Please pay at the office.');
    return;
  }
  showFormSheet(
    context,
    title: 'Pay for ${r.slot}',
    subtitle: 'Pay ${peso(r.amount)} with GCash, Maya or bank transfer, then enter the reference number and add a screenshot of your payment. '
        'The office checks it and confirms your rental. Paying at the office? Nothing to send; the office records it.',
    photo: const PhotoSpec('photo', 'Screenshot of your payment', hint: 'It helps the office confirm your rental faster.'),
    choices: [ChoiceSpec('method', 'Paid through', methods, methods.first)],
    fields: [
      const FieldSpec('ref', 'Reference no.', hint: 'From your GCash / Maya / bank receipt'),
      FieldSpec('paid', 'Date you paid', hint: 'Like ${shortDate(DateTime.now())}', initial: shortDate(DateTime.now())),
    ],
    submit: 'Send payment details',
    onSubmit: (v) {
      final pic = v['photo'];
      final err = app.submitParkingProof(v['method'] as String, v['ref'] as String,
          image: pic is Uint8List ? proofImageText(pic) : '', paidOn: v['paid'] as String);
      if (err == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) msg(context, 'Sent. The office will verify your payment and confirm your rental.');
        });
      }
      return err;
    },
  );
}

/// Resident: the parking slot of the unit, the charge, and which slots are free.
class ResParking extends StatelessWidget {
  /// True when shown as a tab of the bottom bar (no back arrow).
  final bool tab;
  const ResParking({super.key, this.tab = false});

  void _reserve(BuildContext context, ParkingSlot s) {
    final rates = app.parkRatesFor(s.size);
    final monthLabel = 'Monthly (1 month)${rates.month > 0 ? ' · ${peso(rates.month)}' : ''}';
    final dayLabel = 'Daily · ${peso(rates.day)} per day';
    final hasDaily = rates.day > 0;
    final options = [if (rates.month > 0 || !hasDaily) monthLabel, if (hasDaily) dayLabel];
    showFormSheet(
      context,
      title: 'Reserve ${s.id} · ${s.size} slot',
      subtitle: 'This is a ${s.size.toLowerCase()} slot${rates.sqm > 0 ? ' (${rates.sqm} sqm)' : ''}, so the price is set for that size. Choose how long you will rent it. The slot is held for you. Pay the rental and send the payment details, then the office approves it.',
      choices: [ChoiceSpec('plan', 'Rental', options, options.first)],
      fields: [
        if (hasDaily) FieldSpec('days', 'Number of days', type: TextInputType.number, initial: '1', onlyWhenKey: 'plan', onlyWhenValue: dayLabel),
      ],
      submit: 'Reserve ${s.id}',
      onSubmit: (v) {
        final daily = v['plan'] == dayLabel;
        final days = int.tryParse('${v['days'] ?? ''}'.trim()) ?? 0;
        final err = app.reserveSlot(s.id, plan: daily ? 'day' : 'month', days: days);
        if (err == null) {
          final amount = app.myParkingReq?.amount ?? 0;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) msg(context, amount > 0 ? 'Reserved. Pay ${peso(amount)} to finish.' : 'Request sent to the administrator.');
          });
        }
        return err;
      },
    );
  }

  Widget _step(String label, {required bool done, required bool current, required String n}) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: done ? ink : (current ? Colors.white : Colors.white.withAlpha(140)), shape: BoxShape.circle, border: current ? Border.all(color: ink, width: 2) : null),
            child: done
                ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                : Text(n, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: ink)),
          ),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final mine = app.slotOf(app.myUnit);
        final req = mine == null ? app.myParkingReq : null;
        final picked = req != null && req.slot.isNotEmpty;
        final proof = picked ? app.parkingProofFor(app.myUnit, req.slot) : null;
        final st = proof == null ? 1 : (proof.status == 'Confirmed' ? 3 : 2);
        final free = app.freeSlotCount;
        final held = app.heldSlots;
        final canPick = mine == null && req == null && app.slots.isNotEmpty;
        final cs = Theme.of(context).colorScheme;
        final kids = <Widget>[
          PastelCard(
            color: mine != null ? Pastel.mint : (req != null ? Pastel.butter : Pastel.sky),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const GlassIcon(Icons.two_wheeler_rounded, size: 52),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            mine != null ? 'Your parking slot' : (picked ? 'Reserved for you' : (req != null ? 'Request sent' : 'No parking slot yet')),
                            style: const TextStyle(color: inkSoft, fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(mine != null ? mine.id : (picked ? req.slot : (req != null ? 'Waiting for the office' : app.myUnit)), style: hd(23)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (mine != null)
                  Text(
                    'Assigned to ${app.myUnit}. ${mine.rentalLine}${mine.amount > 0 ? ' · ${peso(mine.amount)}' : ''}.'
                    '${mine.ended ? ' This rental has ended. Please contact the office to renew or free the slot.' : ''}',
                    style: const TextStyle(color: inkSoft, height: 1.4),
                  )
                else if (picked) ...[
                  Text(req.amount > 0 ? 'Charge: ${peso(req.amount)} · ${parkPlanText(req.plan, req.days)}' : 'No rate set yet', style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white.withAlpha(150), borderRadius: BorderRadius.circular(18)),
                    child: Row(children: [
                      _step('Slot chosen', done: true, current: false, n: '1'),
                      _step('Pay ${req.amount > 0 ? peso(req.amount) : 'rental'}', done: st > 1, current: st == 1, n: '2'),
                      _step('Office approves', done: st == 3, current: st == 2, n: '3'),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    st == 1
                        ? 'Pay the rental, then send the payment details. The slot is held for you until the office decides.'
                        : st == 2
                            ? 'Payment details sent (ref. ${proof!.reference}). The office will verify and assign the slot.'
                            : 'Payment verified. The office will assign the slot.',
                    style: const TextStyle(color: inkSoft, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  if (st == 1 && req.amount > 0)
                    SizedBox(width: double.infinity, child: FilledButton(onPressed: () => sendParkingPayment(context), child: Text('Pay ${peso(req.amount)} now'))),
                  if (st == 1)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () async {
                          final ok = await confirmDialog(context, 'Cancel your parking reservation?', 'The slot is released for others. You can reserve again any time.', confirm: 'Cancel reservation', destructive: true);
                          if (!ok || !context.mounted) return;
                          final err = app.cancelMyParkingRequest();
                          if (err != null) msg(context, err);
                        },
                        child: const Text('Cancel reservation'),
                      ),
                    ),
                ] else if (req != null) ...[
                  const Text('The office will assign you a slot when one is free. You will get a notice.', style: TextStyle(color: inkSoft, height: 1.4)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () async {
                        final ok = await confirmDialog(context, 'Cancel your parking request?', 'You can send a new request any time.', confirm: 'Cancel request', destructive: true);
                        if (!ok || !context.mounted) return;
                        final err = app.cancelMyParkingRequest();
                        if (err != null) msg(context, err);
                      },
                      child: const Text('Cancel my request'),
                    ),
                  ),
                ] else ...[
                  Text(
                    app.slots.isEmpty
                        ? 'The office has not set up the parking slots yet. You can still send a request.'
                        : 'Tap a free slot on the map to reserve it. The rental depends on the size of the slot (see the price list below). You pay before the office approves it.',
                    style: const TextStyle(color: inkSoft, height: 1.4),
                  ),
                  if (app.slots.isEmpty) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          app.requestParking();
                          msg(context, 'Parking slot request sent to the administrator.');
                        },
                        child: const Text('Request a parking slot'),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
          if (app.slots.isNotEmpty)
            RCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('Parking map', style: hd(18))),
                      Text('$free of ${app.slots.length} free', style: TextStyle(color: muted(context), fontSize: 12.5)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.45,
                    children: [
                      for (final s in app.slots)
                        Builder(builder: (context) {
                          final isMine = s.unit == app.myUnit;
                          final holder = held[s.id];
                          final myHold = holder != null && holder == app.myUnit;
                          final tone = s.used ? Tone.bad : (holder != null ? Tone.warn : Tone.good);
                          final t = toneOf(context, tone);
                          final label = isMine ? 'Yours' : (s.used ? 'Taken' : (myHold ? 'Yours' : (holder != null ? 'Held' : 'Free')));
                          final tappable = canPick && !s.used && holder == null;
                          return GestureDetector(
                            onTap: tappable ? () => _reserve(context, s) : null,
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isMine ? ink : t.bg,
                                borderRadius: BorderRadius.circular(12),
                                border: myHold ? Border.all(color: ink, width: 2) : null,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(s.id, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: isMine ? Colors.white : t.fg)),
                                  Text(label, style: TextStyle(fontSize: 10.5, color: isMine ? lav : t.fg)),
                                  Text(
                                    !s.used && holder == null && app.parkRatesFor(s.size).month > 0 ? '${s.size} · ${peso(app.parkRatesFor(s.size).month)}' : s.size,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 9, color: (isMine ? lav : t.fg).withValues(alpha: 0.75)),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ],
              ),
            ),
          RCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rental price by slot size', style: hd(18)),
                const SizedBox(height: 4),
                Text('A bigger slot costs more. Each slot on the map shows its size.', style: TextStyle(color: muted(context), fontSize: 12.5)),
                for (final z in app.parkSizes) ...[
                  const Divider(height: 18),
                  Row(
                    children: [
                      Expanded(child: Text('${z.name}${z.sqm > 0 ? ' · ${z.sqm} sqm' : ''}', style: const TextStyle(fontWeight: FontWeight.w700))),
                      Text('${z.month > 0 ? '${peso(z.month)} / month' : '—'}${z.day > 0 ? ' · ${peso(z.day)} / day' : ''}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
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
                Text('How it works', style: hd(18)),
                const SizedBox(height: 8),
                for (final line in [
                  'Tap a free slot on the map. The slot is held for you.',
                  'You choose a monthly or daily rental, and it shows up as a charge. Pay it, then send the payment details.',
                  'When the office verifies your payment, the slot is yours. Your receipt appears under Dues.',
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.check_circle_outline_rounded, size: 18, color: cs.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Expanded(child: Text(line, style: TextStyle(color: muted(context), fontSize: 13, height: 1.4))),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ];
        return tab
            ? TabPage(title: 'Motor parking', subtitle: 'Your parking slot, your charge, and which slots are free.', children: kids)
            : SubPage(title: 'Motor parking', subtitle: 'Your parking slot, your charge, and which slots are free.', children: kids);
      },
    );
  }
}
