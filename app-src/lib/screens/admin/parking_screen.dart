// ADMIN page: Parking (slots, requests, rentals).

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../widgets/widgets.dart';
import '../shared/import_sheet.dart';

/// Administrator: the motor parking slots and the residents asking for one.
class AdminParking extends StatelessWidget {
  const AdminParking({super.key});

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
            if (s.used)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                child: Text('${s.rentalLine}${s.ended ? ' (ended)' : ''}${s.amount > 0 ? ' · ${peso(s.amount)}' : ''}', style: TextStyle(color: muted(context), fontSize: 12.5)),
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

  /// One request. A reserved slot is approved when its payment is confirmed.
  Widget _request(BuildContext context, ParkingReq p) {
    final proof = p.slot.isNotEmpty ? app.parkingProofFor(p.unit, p.slot) : null;
    final paid = proof?.status == 'Confirmed';
    final reserved = p.slot.isNotEmpty && p.amount > 0;
    final Widget chip = !reserved
        ? (p.slot.isNotEmpty ? Pill('Chose ${p.slot}', tone: Tone.info) : const SizedBox.shrink())
        : proof == null
            ? const Pill('Waiting for payment', tone: Tone.info)
            : (paid ? const Pill('Paid', tone: Tone.good) : Pill('Payment sent · Ref ${proof.reference}', tone: Tone.warn));
    final List<Widget> actions;
    if (reserved && proof == null) {
      actions = [
        TextButton(
          onPressed: () async {
            final ok = await confirmDialog(context, 'Assign without payment?', '${p.unit} has not paid yet. The slot is assigned and no payment is recorded.', confirm: 'Assign anyway', destructive: true);
            if (!ok) return;
            final err = app.assignRequest(p);
            if (err != null && context.mounted) msg(context, err);
          },
          child: const Text('Assign without payment'),
        ),
      ];
    } else if (reserved && !paid) {
      actions = [
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 38)),
          onPressed: () {
            app.confirmProof(proof!);
            msg(context, 'Payment confirmed. ${p.slot} is now assigned to ${p.unit}.');
          },
          child: const Text('Confirm payment'),
        ),
      ];
    } else {
      actions = [
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 38)),
          onPressed: () {
            final err = app.assignRequest(p);
            if (err != null) msg(context, err);
          },
          child: Text(p.slot.isNotEmpty ? 'Assign ${p.slot}' : 'Assign'),
        ),
      ];
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${p.unit} · ${p.name}', style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(
            p.slot.isNotEmpty
                ? 'Slot ${p.slot}${p.amount > 0 ? ' · ${peso(p.amount)}' : ''} · ${parkPlanText(p.plan, p.days)}'
                : (app.freeSlot == null ? 'No free slot right now' : 'Next free slot: ${app.freeSlot!.id}'),
            style: TextStyle(color: muted(context), fontSize: 12.5),
          ),
          const SizedBox(height: 6),
          chip,
          const SizedBox(height: 6),
          Wrap(spacing: 6, children: [...actions, TextButton(onPressed: () => app.declineParking(p), child: const Text('Decline'))]),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final waiting = app.parking.where((p) => !p.confirmed).toList();
        final free = app.freeSlotCount;
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
                ['Waiting', '${waiting.length}'],
                ['Monthly', peso(app.motorRate)],
              ]),
            ),
            Text('Requests', style: hd(18)),
            if (waiting.isEmpty)
              const EmptyBox('No requests waiting.', icon: Icons.two_wheeler_outlined)
            else
              RCard(
                child: Column(
                  children: [
                    for (final p in waiting) _request(context, p),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(child: Text('Slots', style: hd(18))),
                TextButton.icon(
                  onPressed: () => showFormSheet(
                    context,
                    title: 'Add parking slots',
                    subtitle: app.slots.isEmpty ? 'How many motor parking slots does the building have?' : 'You have ${app.slots.length} slots. How many more should be added?',
                    fields: const [FieldSpec('n', 'Number of slots', type: TextInputType.number, hint: 'e.g. 24')],
                    submit: 'Add slots',
                    onSubmit: (v) => app.addSlots(v['n'] as String),
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add slots'),
                ),
              ],
            ),
            if (app.slots.isEmpty)
              const EmptyBox('No slots yet. Tap "Add slots" to set up the parking area.', icon: Icons.local_parking_rounded)
            else
              Text('Tap a slot to assign, release, rename or delete it.', style: TextStyle(color: muted(context), fontSize: 12.5)),
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
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
            Text('Current rentals', style: hd(18)),
            if (app.slots.where((s) => s.used).isEmpty)
              const EmptyBox('No slot is rented yet.', icon: Icons.two_wheeler_outlined)
            else
              RCard(
                child: Column(
                  children: [
                    for (final s in (app.slots.where((s) => s.used).toList()..sort((a, b) => naturalCompare(a.unit, b.unit))))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${s.unit} · ${s.id}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                  Text(
                                    s.until.isEmpty ? '${s.daily ? 'Daily' : 'Monthly'} · no end date' : '${s.daily ? 'Daily' : 'Monthly'} · ${isoShort(s.from)} – ${isoShort(s.until)}',
                                    style: TextStyle(color: muted(context), fontSize: 12.5),
                                  ),
                                  const SizedBox(height: 4),
                                  s.ended ? const Pill('Ended', tone: Tone.bad) : const Pill('Active', tone: Tone.good),
                                ],
                              ),
                            ),
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
            RCard(
              child: Text(
                'Change the monthly and daily rates under Finance. Residents reserve a slot from their Parking page.',
                style: TextStyle(color: muted(context), fontSize: 12.5, height: 1.4),
              ),
            ),
          ],
        );
      },
    );
  }
}
