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
  int tab = 0; // 0 requests, 1 today's slots, 2 blocked times, 3 amenities
  bool showAll = false;
  String filter = ''; // '' (everything) | Pending | Approved | Denied | all

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

  /// Change a request: its status and its time.
  void _editBooking(BuildContext context, Booking r) {
    final fi = app.amenities.indexWhere((a) => a.name == r.place);
    final slots = fi >= 0 ? app.amenities[fi].slots : <String>[];
    final canSlot = fi >= 0 && r.day.isNotEmpty && r.slot >= 0 && r.slot < slots.length;
    const labels = {'Pending': 'Waiting for a decision', 'Approved': 'Approved', 'Denied': 'Denied (frees the time)'};
    showFormSheet(
      context,
      title: 'Edit ${r.place} request',
      subtitle: '${r.unit} · ${r.who} · ${r.when}. The resident is told about the change.',
      choices: [
        ChoiceSpec('status', 'Status', labels.values.toList(), labels[r.status] ?? labels['Pending']!),
        if (canSlot) ChoiceSpec('slot', 'Time', slots, slots[r.slot]),
      ],
      submit: 'Save',
      onSubmit: (v) {
        final st = labels.entries.firstWhere((e) => e.value == v['status'], orElse: () => labels.entries.first).key;
        final slot = canSlot ? slots.indexOf(v['slot'] as String) : r.slot;
        final err = app.editBooking(r, st, slot);
        if (err == null) WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) msg(context, 'Request updated.');
        });
        return err;
      },
    );
  }

  Future<void> _removeBooking(BuildContext context, Booking r) async {
    final ok = await confirmDialog(context, 'Remove this request?', '${r.place}, ${r.unit}, ${r.when}. It is deleted for good and the time becomes free.',
        confirm: 'Remove', destructive: true);
    if (!ok || !context.mounted) return;
    app.removeBooking(r);
  }

  /// Add or change a blocked time (cleaning, repairs, out of service ...).
  void _blockForm(BuildContext context, {FBlock? edit, String? facility}) {
    final names = ['All facilities', for (final a in app.amenities) a.name];
    String nameOf(String f) => f == '*' ? 'All facilities' : f;
    final today = dayKey(DateTime.now());
    final b = edit ?? FBlock('', facility ?? '*', 'Cleaning', '', today, today, false, '13:00', '15:00');
    const allDay = 'All day', some = 'Only certain hours';
    const keep = 'Keep them (I will sort them out)', deny = 'Deny them and tell the residents';
    showFormSheet(
      context,
      title: edit == null ? 'Block a time' : 'Edit blocked time',
      subtitle: 'Residents will see these times as unavailable. Use a start and end time for part of a day, or clear the last date when something is out of service until further notice.',
      choices: [
        ChoiceSpec('facility', 'Amenity', names, nameOf(b.facility)),
        ChoiceSpec('reason', 'Why', blockReasons, b.reason),
        ChoiceSpec('hours', 'Hours', const [allDay, some], b.someHours ? some : allDay),
        const ChoiceSpec('deal', 'Bookings already made in that time', [keep, deny], keep),
      ],
      fields: [FieldSpec('note', 'Note shown to residents (optional)', lines: 2, hint: 'e.g. The pool is being drained and scrubbed.', initial: b.note)],
      dates: [
        DateSpec('from', 'From date', b.from),
        DateSpec('to', 'Until date', b.to, clearable: true, emptyText: 'Until further notice'),
      ],
      times: [
        TimeSpec('start', 'From time', b.start.isEmpty ? '13:00' : b.start, onlyWhenKey: 'hours', onlyWhenValue: some, belowChoice: true),
        TimeSpec('end', 'Until time', b.end.isEmpty ? '15:00' : b.end, onlyWhenKey: 'hours', onlyWhenValue: some, belowChoice: true),
      ],
      submit: 'Save',
      onSubmit: (v) {
        final fac = v['facility'] == 'All facilities' ? '*' : v['facility'] as String;
        final err = app.saveBlock(edit,
            facility: fac,
            reason: v['reason'] as String,
            note: v['note'] as String,
            from: v['from'] as String,
            to: v['to'] as String,
            someHours: v['hours'] == some,
            start: v['start'] as String,
            end: v['end'] as String,
            denyBookings: v['deal'] == deny);
        if (err == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) msg(context, app.lastBlockNote);
          });
        }
        return err;
      },
    );
  }

  Future<void> _endBlock(BuildContext context, FBlock b) async {
    final notStarted = b.from.compareTo(dayKey(DateTime.now())) > 0;
    final ok = await confirmDialog(
      context,
      notStarted ? 'Cancel this blocked time?' : 'Reopen now?',
      '${b.facility == '*' ? 'All facilities' : b.facility} · ${b.reason} · ${b.whenText}. Residents can book it again.',
      confirm: notStarted ? 'Cancel it' : 'Reopen',
    );
    if (ok) app.endBlock(b);
  }

  /// A time of today was tapped: change its booking, reserve it for a unit, close it, or open it again.
  void _slotTap(BuildContext context, int f, int i) {
    final cur = app.amenities[f];
    final blk = app.slotBlock(f, i, dayKey(DateTime.now()));
    if (blk != null) {
      _blockForm(context, edit: blk);
      return;
    }
    if (app.slotClosed(f, i)) {
      app.toggleSlot(f, i);
      return;
    }
    final bk = app.bookingAtSlot(f, i);
    if (bk != null) {
      _editBooking(context, bk);
      return;
    }
    const closeIt = 'Close it for today', reserve = 'Reserve it for a unit';
    showFormSheet(
      context,
      title: '${cur.name} · ${cur.slots[i]}',
      subtitle: 'This time is open today. Close it so nobody can book it, or reserve it for a unit (for example a walk-in request at the office). For cleaning, repairs or other dates and hours, use Blocked times.',
      choices: const [ChoiceSpec('what', 'What do you want to do?', [closeIt, reserve], closeIt)],
      fields: const [FieldSpec('unit', 'Unit', hint: 'e.g. Unit 12A', onlyWhenKey: 'what', onlyWhenValue: reserve, belowChoice: true)],
      submit: 'Save',
      onSubmit: (v) {
        if (v['what'] != reserve) {
          app.toggleSlot(f, i);
          return null;
        }
        return app.reserveAmenityTime(f, i, v['unit'] as String);
      },
    );
  }

  Widget _countTile(BuildContext context, String label, int n, Tone? tone, String key) {
    final on = filter == key;
    final t = tone == null ? null : toneOf(context, tone);
    final bg = t?.bg ?? Theme.of(context).colorScheme.surfaceContainerHighest;
    final fg = t?.fg ?? Theme.of(context).colorScheme.onSurface;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() {
            filter = on ? '' : key;
            showAll = false;
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16), border: Border.all(color: on ? fg : Colors.transparent, width: 2)),
            child: Column(children: [
              Text('$n', style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 22)),
              Text(label, textAlign: TextAlign.center, style: TextStyle(color: fg, fontSize: 11.5, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      ),
    );
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
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton.icon(onPressed: () => _editBooking(context, r), icon: const Icon(Icons.edit_outlined, size: 18), label: const Text('Edit')),
            TextButton.icon(
              onPressed: () => _removeBooking(context, r),
              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: danger),
              label: const Text('Remove', style: TextStyle(color: danger)),
            ),
          ]),
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
    final tiles = <Widget>[
      Row(children: [
        _countTile(context, 'Waiting', pend.length, pend.isEmpty ? null : Tone.warn, 'Pending'),
        _countTile(context, 'Approved', ok, Tone.good, 'Approved'),
        _countTile(context, 'Denied', no, null, 'Denied'),
        _countTile(context, 'All', all.length, null, 'all'),
      ]),
      Text('${filter.isEmpty ? 'Tap a number to see only those requests.' : 'Showing one group. Tap the same number again to see everything.'} Every request has Edit and Remove.',
          style: TextStyle(color: muted(context), fontSize: 12)),
    ];
    if (filter == 'Pending') {
      return [...tiles, const SectionHeader('Needs your decision'), if (pend.isEmpty) const EmptyBox('Nothing is waiting.', icon: Icons.event_available_outlined), for (final r in pend) _requestCard(context, r)];
    }
    if (filter == 'Approved' || filter == 'Denied') {
      final rows = rest.where((b) => b.status == filter).toList();
      return [...tiles, SectionHeader('$filter requests'), if (rows.isEmpty) const EmptyBox('Nothing here.', icon: Icons.history_rounded), for (final r in rows) _requestCard(context, r)];
    }
    if (filter == 'all') {
      return [...tiles, const SectionHeader('All requests'), for (final r in [...pend, ...rest]) _requestCard(context, r)];
    }
    return [
      ...tiles,
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
            Text('Hours ${cur.hours} · tap a time to close it, reserve it, or change its booking', style: TextStyle(color: muted(context), fontSize: 12.5)),
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
                      final closed = app.slotClosed(fac, i);
                      final blk = app.slotBlock(fac, i, dayKey(DateTime.now()));
                      final bk = closed ? null : app.bookingAtSlot(fac, i);
                      final booked = closed || bk != null;
                      final label = blk != null ? blk.reason : closed ? 'Closed' : bk == null ? 'Open' : '${bk.status == 'Pending' ? 'Waiting' : 'Booked'} · ${bk.unit.replaceFirst(RegExp(r'^Unit\s+', caseSensitive: false), '')}';
                      final t = toneOf(context, booked ? Tone.bad : Tone.good);
                      return GestureDetector(
                        onTap: () => _slotTap(context, fac, i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(14)),
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(slots[i], textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: t.fg)),
                              Text(label, style: TextStyle(fontSize: 11, color: t.fg)),
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

  Widget _blockCard(BuildContext context, FBlock b, String kind) {
    final tone = kind == 'now' ? Tone.bad : kind == 'soon' ? Tone.warn : Tone.info;
    final n = kind == 'past' ? 0 : app.bookingsInBlock(b).length;
    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(b.facility == '*' ? 'All facilities' : b.facility, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
            Pill(b.reason, tone: tone),
          ]),
          const SizedBox(height: 2),
          Text(b.whenText, style: TextStyle(color: muted(context), fontSize: 12.5)),
          if (b.note.isNotEmpty) Text('“${b.note}”', style: TextStyle(color: muted(context), fontSize: 12.5, fontStyle: FontStyle.italic)),
          if (n > 0)
            Text('$n booking${n == 1 ? ' is' : 's are'} still inside this time. Edit it to deny them.', style: const TextStyle(color: danger, fontSize: 12.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            if (kind != 'past') ...[
              TextButton.icon(onPressed: () => _blockForm(context, edit: b), icon: const Icon(Icons.edit_outlined, size: 18), label: const Text('Edit')),
              TextButton(onPressed: () => _endBlock(context, b), child: Text(kind == 'now' ? 'Reopen now' : 'Cancel')),
            ] else
              TextButton.icon(
                onPressed: () => app.removeBlock(b),
                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: danger),
                label: const Text('Remove', style: TextStyle(color: danger)),
              ),
          ]),
        ],
      ),
    );
  }

  List<Widget> _blocks(BuildContext context) {
    final today = dayKey(DateTime.now());
    final all = [...app.fblocks]..sort((a, b) => b.from.compareTo(a.from));
    final now = all.where((b) => b.onDay(today)).toList();
    final soon = all.where((b) => b.from.compareTo(today) > 0).toList();
    final past = all.where((b) => b.to.isNotEmpty && b.to.compareTo(today) < 0).toList();
    return [
      Row(children: [
        Expanded(child: Text('Close an amenity for cleaning, repairs, a private event or anything else. Choose the dates and the exact hours.', style: TextStyle(color: muted(context), fontSize: 12.5))),
        const SizedBox(width: 8),
        FilledButton.icon(onPressed: () => _blockForm(context), icon: const Icon(Icons.add_rounded, size: 18), label: const Text('Block a time')),
      ]),
      if (all.isEmpty) const EmptyBox('Nothing is blocked. Use “Block a time” when an amenity is out of service or being cleaned.', icon: Icons.block_rounded),
      if (now.isNotEmpty) const SectionHeader('Closed now'),
      for (final b in now) _blockCard(context, b, 'now'),
      if (soon.isNotEmpty) const SectionHeader('Coming up'),
      for (final b in soon) _blockCard(context, b, 'soon'),
      if (past.isNotEmpty) const SectionHeader('Ended'),
      for (final b in past.take(5)) _blockCard(context, b, 'past'),
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
                    Builder(builder: (context) {
                      final l = app.blocksFor(a.name);
                      if (l.isEmpty) return const SizedBox.shrink();
                      final b = l.first;
                      final now = b.onDay(dayKey(DateTime.now()));
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Pill('${now ? 'Closed now' : 'Next'} · ${b.reason} · ${b.whenText}', tone: now ? Tone.bad : Tone.warn),
                      );
                    }),
                  ],
                ),
              ),
              IconButton(tooltip: 'Block a time', onPressed: () => _blockForm(context, facility: a.name), icon: const Icon(Icons.block_rounded, size: 20)),
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

  int get _liveBlocks => app.fblocks.where((b) => b.to.isEmpty || b.to.compareTo(dayKey(DateTime.now())) >= 0).length;

  Widget _page(BuildContext context) {
    final pending = app.pendingBookings;
    return TabPage(
      title: 'Facility booking',
      subtitle: 'Approve requests, open or block today\'s slots, and manage the amenities.',
      children: [
        SubTabs(
          items: [
            SubTabItem('Requests', count: pending, hot: true),
            const SubTabItem("Today's slots"),
            SubTabItem('Blocked times', count: _liveBlocks == 0 ? null : _liveBlocks),
            SubTabItem('Amenities', count: app.amenities.length),
          ],
          index: tab,
          onChanged: (i) => setState(() => tab = i),
        ),
        ...switch (tab) {
          1 => _slots(context),
          2 => _blocks(context),
          3 => _amenities(context),
          _ => _requests(context),
        },
      ],
    );
  }
}
