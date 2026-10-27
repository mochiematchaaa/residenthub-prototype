// ADMIN page: Facility (booking requests and time slots).

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../widgets/widgets.dart';
import '../shared/import_sheet.dart';

class AdminFacility extends StatefulWidget {
  const AdminFacility({super.key});

  @override
  State<AdminFacility> createState() => _AdminFacilityState();
}

class _AdminFacilityState extends State<AdminFacility> {
  int fac = 0;
  int tab = 0; // 0 requests, 1 today's slots, 2 amenities
  bool showAll = false;

  void _form(BuildContext context, {Amenity? edit}) {
    final a = edit ?? Amenity('', '', '08:00', '20:00', 120);
    showFormSheet(
      context,
      title: edit == null ? 'Add an amenity' : 'Edit ${edit.name}',
      subtitle: 'Residents book one time slot at a time. The slots are made from the opening and closing time and the length of one booking.'
          '${edit == null ? '' : ' Changing them does not move requests already made today.'}',
      fields: [
        FieldSpec('name', 'Name', hint: 'e.g. Gym, Basketball court', initial: a.name),
        FieldSpec('mins', 'Length of one booking (minutes)', type: TextInputType.number, hint: 'e.g. 60 or 120', initial: '${a.mins}'),
        FieldSpec('note', 'Note shown to residents (optional)', lines: 2, hint: 'e.g. Guests pay a fee.', initial: a.note),
      ],
      times: [TimeSpec('open', 'Opens at', a.open), TimeSpec('close', 'Closes at', a.close)],
      submit: edit == null ? 'Add amenity' : 'Save',
      onSubmit: (v) {
        final err = app.saveAmenity(edit, v['name'] as String, v['open'] as String, v['close'] as String,
            int.tryParse((v['mins'] as String).trim()) ?? 0, v['note'] as String);
        if (err == null && edit == null) setState(() => fac = app.amenities.length - 1);
        return err;
      },
    );
  }

  Future<void> _remove(BuildContext context, Amenity a) async {
    final live = app.activeBookingsToday(a);
    final ok = await confirmDialog(
      context,
      'Remove ${a.name}?',
      '${live > 0 ? '$live upcoming booking${live == 1 ? ' is' : 's are'} still active. ' : ''}'
      'Past reservations stay in the list. Residents can no longer book it.',
      confirm: 'Remove',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final err = app.removeAmenity(a);
    if (err != null) msg(context, err);
  }

  Widget _requestCard(BuildContext context, Booking r) {
    final tone = r.status == 'Approved' ? Tone.good : r.status == 'Denied' ? Tone.bad : Tone.warn;
    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(amenityIcon(r.place), tone: tone),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.place, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    Text('${r.unit} · ${r.who}', style: TextStyle(color: muted(context), fontSize: 12.5)),
                    Text(r.when, style: TextStyle(color: muted(context), fontSize: 12.5)),
                  ],
                ),
              ),
              Pill(r.status, tone: tone),
            ],
          ),
          if (r.status == 'Pending') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: FilledButton(onPressed: () => app.bookAct(r.id, 'Approved'), child: const Text('Approve'))),
                const SizedBox(width: 10),
                Expanded(child: OutlinedButton(onPressed: () => app.bookAct(r.id, 'Denied'), child: const Text('Deny'))),
              ],
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _requests(BuildContext context) {
    final all = app.bookings.where((b) => b.status != 'Completed').toList().reversed.toList();
    final pend = all.where((b) => b.status == 'Pending').toList();
    final rest = all.where((b) => b.status != 'Pending').toList();
    final ok = all.where((b) => b.status == 'Approved').length;
    final no = all.where((b) => b.status == 'Denied').length;
    final shown = showAll ? rest : rest.take(8).toList();
    return [
      PastelCard(
        color: Pastel.sky,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: StatsRow([
          ['Waiting', '${pend.length}'],
          ['Approved', '$ok'],
          ['Denied', '$no'],
        ]),
      ),
      const SectionHeader('Needs your decision'),
      if (pend.isEmpty) const EmptyBox('Nothing is waiting. New requests show up here.', icon: Icons.event_available_outlined),
      for (final r in pend) _requestCard(context, r),
      SectionHeader('Earlier requests', action: rest.length > 8 ? (showAll ? 'Show fewer' : 'Show all ${rest.length}') : null, onAction: () => setState(() => showAll = !showAll)),
      if (rest.isEmpty) const EmptyBox('No earlier requests yet.', icon: Icons.history_rounded),
      for (final r in shown) _requestCard(context, r),
    ];
  }

  List<Widget> _slots(BuildContext context) {
    final list = app.amenities;
    if (list.isEmpty) return const [EmptyBox('No amenities yet. Add one under Amenities.', icon: Icons.meeting_room_outlined)];
    if (fac >= list.length) fac = list.length - 1;
    final cur = list[fac];
    final slots = cur.slots;
    return [
      if (list.length > 1)
        FilterRow(
          options: [for (final f in list) f.name],
          selected: cur.name,
          onSelect: (v) => setState(() => fac = list.indexWhere((f) => f.name == v)),
        ),
      if (cur.note.isNotEmpty)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: toneOf(context, Tone.good).bg, borderRadius: BorderRadius.circular(14)),
          child: Text(cur.note, style: TextStyle(color: toneOf(context, Tone.good).fg, fontSize: 12.5)),
        ),
      RCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${cur.name} · today', style: hd(18)),
            Text('Hours ${cur.hours} · tap a slot to open or block it', style: TextStyle(color: muted(context), fontSize: 12.5)),
            const SizedBox(height: 14),
            if (slots.isEmpty)
              Text('No bookable times. Check the opening hours and the length of one booking.', style: TextStyle(color: muted(context)))
            else
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.7,
                children: [
                  for (var i = 0; i < slots.length; i++)
                    Builder(builder: (context) {
                      final booked = app.slotBooked(fac, i);
                      final t = toneOf(context, booked ? Tone.bad : Tone.good);
                      return GestureDetector(
                        onTap: () => app.toggleSlot(fac, i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(14)),
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(slots[i], textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: t.fg)),
                              Text(booked ? 'Booked' : 'Open', style: TextStyle(fontSize: 11, color: t.fg)),
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
    ];
  }

  List<Widget> _amenities(BuildContext context) {
    final list = app.amenities;
    return [
      Row(children: [
        Expanded(child: Text('Residents see any change straight away.', style: TextStyle(color: muted(context), fontSize: 12.5))),
        FilledButton.icon(onPressed: () => _form(context), icon: const Icon(Icons.add_rounded, size: 18), label: const Text('Add amenity')),
      ]),
      if (list.isEmpty) const EmptyBox('No amenities yet. Add the first one.', icon: Icons.meeting_room_outlined),
      for (final a in list)
        RCard(
          child: Row(
            children: [
              IconBadge(amenityIcon(a.name), accent: true),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text('${a.hours} · ${a.slots.length} slots of ${a.mins} min', style: TextStyle(color: muted(context), fontSize: 12.5)),
                  ],
                ),
              ),
              IconButton(tooltip: 'Edit', onPressed: () => _form(context, edit: a), icon: const Icon(Icons.edit_outlined, size: 20)),
              IconButton(tooltip: 'Remove', onPressed: () => _remove(context, a), icon: const Icon(Icons.delete_outline_rounded, size: 20, color: danger)),
            ],
          ),
        ),
      const ImportBar(['facilities']),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: app, builder: (context, _) => _page(context));
  }

  Widget _page(BuildContext context) {
    final pending = app.pendingBookings;
    return TabPage(
      title: 'Facility booking',
      subtitle: 'Approve requests, open or block today\'s slots, and manage the amenities.',
      children: [
        SubTabs(
          items: [SubTabItem('Requests', count: pending, hot: true), const SubTabItem("Today's slots"), SubTabItem('Amenities', count: app.amenities.length)],
          index: tab,
          onChanged: (i) => setState(() => tab = i),
        ),
        ...switch (tab) {
          1 => _slots(context),
          2 => _amenities(context),
          _ => _requests(context),
        },
      ],
    );
  }
}
