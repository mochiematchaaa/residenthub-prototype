// RESIDENT page: Book a facility (day, time slot).

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../widgets/widgets.dart';
import 'resident_screens.dart';

class ResBook extends StatefulWidget {
  const ResBook({super.key});

  @override
  State<ResBook> createState() => _ResBookState();
}

class _ResBookState extends State<ResBook> {
  /// How far ahead a resident can book.
  static const _aheadDays = 90;
  static const _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  static const _weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  int fac = 0;
  int? pick;
  String? _day; // yyyy-mm-dd
  DateTime? _month; // first day of the month shown

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  DateTime get _last => _today.add(const Duration(days: _aheadDays));

  String get day {
    final t = dayKey(_today);
    final d = _day;
    return (d == null || d.compareTo(t) < 0) ? t : d;
  }

  DateTime get month {
    final m = _month;
    if (m != null) return m;
    final d = DateTime.parse(day);
    return DateTime(d.year, d.month);
  }

  String label(String key) {
    final d = DateTime.tryParse(key);
    if (d == null) return key;
    return '${_weekdays[d.weekday % 7]}, ${shortDate(d)}';
  }

  void _pickDay(String key) => setState(() {
        _day = key;
        _month = null;
        pick = null;
      });

  Future<void> _chooseDate() async {
    final d = await showDatePicker(context: context, initialDate: DateTime.parse(day), firstDate: _today, lastDate: _last);
    if (d != null) _pickDay(dayKey(d));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final list = app.amenities;
    if (fac >= list.length) fac = list.isEmpty ? 0 : list.length - 1;
    final cur = list.isEmpty ? null : list[fac];
    if (cur == null) {
      return TabPage(
        title: 'Book a facility',
        subtitle: 'Check availability and send a reservation request.',
        children: const [EmptyBox('No facilities can be booked yet. Please check again later.', icon: Icons.event_busy_outlined)],
      );
    }
    final slots = cur.slots;
    if (pick != null && pick! >= slots.length) pick = null;
    final d = day;
    if (pick != null && app.slotState(fac, pick!, d) != 'open') pick = null;
    return TabPage(
      title: 'Book a facility',
      subtitle: 'Check availability and send a reservation request.',
      children: [
        if (app.blocksFor(cur.name).isNotEmpty)
          RCard(
            color: toneOf(context, Tone.warn).bg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${cur.name} is not available at these times', style: TextStyle(color: toneOf(context, Tone.warn).fg, fontWeight: FontWeight.w800)),
                for (final b in app.blocksFor(cur.name).take(3))
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('${b.reason} · ${b.whenText}${b.note.isEmpty ? '' : ' · ${b.note}'}', style: TextStyle(color: toneOf(context, Tone.warn).fg, height: 1.35, fontSize: 13)),
                  ),
              ],
            ),
          ),
        if (maint.closureOf(cur.name) != null)
          RCard(
            color: toneOf(context, Tone.warn).bg,
            child: Text(
              '${cur.name} is closed for maintenance. ${maint.closureOf(cur.name)!.name} is ${maint.closureOf(cur.name)!.status.toLowerCase()}. Booking is paused until it is working again.',
              style: TextStyle(color: toneOf(context, Tone.warn).fg, fontWeight: FontWeight.w600, height: 1.4),
            ),
          ),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final k = app.dayCounts(i, d);
              final on = fac == i;
              return SizedBox(
                width: list.length <= 2 ? (MediaQuery.of(context).size.width - 40 - 12) / 2 : 170,
                child: GestureDetector(
                  onTap: () => setState(() {
                    fac = i;
                    pick = null;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: on ? ink : cs.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: on ? ink : cs.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(amenityIcon(list[i].name), color: on ? lav : cs.onSurfaceVariant),
                        const SizedBox(height: 8),
                        Text(list[i].name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, color: on ? Colors.white : cs.onSurface)),
                        const SizedBox(height: 2),
                        Text(list[i].hours, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: on ? const Color(0xFFB9C3DC) : cs.onSurfaceVariant)),
                        const Spacer(),
                        Text(
                          '${k['open']} vacant · ${(k['booked'] ?? 0) + (k['closed'] ?? 0)} occupied · ${k['pending']} pending',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: on ? lav : cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Text('Slot counts for ${label(d)}. Select a facility, date, and available time.', style: TextStyle(color: muted(context), fontSize: 12.5)),
        _calendar(context),
        RCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(cur.name, style: hd(18))),
                  TextButton.icon(onPressed: _chooseDate, icon: const Icon(Icons.calendar_month_rounded, size: 18), label: const Text('Choose a date')),
                ],
              ),
              Text(label(d), style: TextStyle(color: muted(context), fontSize: 12.5)),
              if (cur.note.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: toneOf(context, Tone.good).bg, borderRadius: BorderRadius.circular(14)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, size: 18, color: toneOf(context, Tone.good).fg),
                      const SizedBox(width: 8),
                      Expanded(child: Text(cur.note, style: TextStyle(color: toneOf(context, Tone.good).fg, fontSize: 12.5, height: 1.4))),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              if (slots.isEmpty)
                Text('No times are set up for this amenity.', style: TextStyle(color: muted(context)))
              else
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.6,
                  children: [for (var i = 0; i < slots.length; i++) _slot(context, i, slots[i], d)],
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 14,
                runSpacing: 6,
                children: [
                  _legend(context, Tone.good, 'Vacant'),
                  _legend(context, Tone.warn, 'Pending'),
                  _legend(context, Tone.bad, 'Booked'),
                  _legend(context, Tone.info, 'Unavailable'),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(3))),
                    const SizedBox(width: 6),
                    Text('Selected', style: TextStyle(fontSize: 12, color: muted(context))),
                  ]),
                ],
              ),
            ],
          ),
        ),
        if (pick != null)
          PastelCard(
            color: Pastel.lavender,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Your reservation request', style: TextStyle(color: inkSoft, fontSize: 12)),
                      const SizedBox(height: 2),
                      Text(cur.name, style: hd(17, color: ink)),
                      Text('${label(d)} · ${slots[pick!]}', style: const TextStyle(color: inkSoft, fontSize: 12.5)),
                    ],
                  ),
                ),
                IconButton(tooltip: 'Clear selection', onPressed: () => setState(() => pick = null), icon: const Icon(Icons.close_rounded)),
                FilledButton(
                  onPressed: () {
                    if (app.slotState(fac, pick!, d) != 'open') {
                      msg(context, 'That time is no longer available.');
                      setState(() => pick = null);
                      return;
                    }
                    app.submitBooking(fac, pick!, day: d);
                    setState(() => pick = null);
                    msg(context, 'Request sent. Track it under My reservations.');
                  },
                  child: const Text('Request'),
                ),
              ],
            ),
          ),
        NavTile(
          icon: Icons.list_alt_rounded,
          title: 'My reservations',
          subtitle: '${app.myBookings.length} on record',
          onTap: () => go(context, const ResReservations()),
        ),
      ],
    );
  }

  /// The month grid. Each day is coloured by how much of the amenity is free.
  Widget _calendar(BuildContext context) {
    final m = month;
    final t = dayKey(_today);
    final last = dayKey(_last);
    final sel = day;
    final lead = DateTime(m.year, m.month, 1).weekday % 7;
    final count = DateTime(m.year, m.month + 1, 0).day;
    final prevOk = DateTime(m.year, m.month).isAfter(DateTime(_today.year, _today.month));
    final nextOk = DateTime(m.year, m.month).isBefore(DateTime(_last.year, _last.month));
    final cells = <Widget>[for (var i = 0; i < lead; i++) const SizedBox.shrink()];
    for (var n = 1; n <= count; n++) {
      final key = dayKey(DateTime(m.year, m.month, n));
      final c = app.dayCounts(fac, key);
      final past = key.compareTo(t) < 0 || key.compareTo(last) > 0;
      Tone tone;
      final open = c['open'] ?? 0, total = c['total'] ?? 0, booked = (c['booked'] ?? 0) + (c['closed'] ?? 0), pend = c['pending'] ?? 0;
      if (open == total) {
        tone = Tone.good;
      } else if (open == 0) {
        tone = booked > 0 ? Tone.bad : Tone.warn;
      } else {
        tone = (pend > 0 && booked == 0) ? Tone.warn : Tone.info;
      }
      final colors = toneOf(context, past ? Tone.info : tone);
      cells.add(
        GestureDetector(
          onTap: past ? null : () => _pickDay(key),
          child: Opacity(
            opacity: past ? 0.4 : 1,
            child: Container(
              decoration: BoxDecoration(
                color: colors.bg,
                borderRadius: BorderRadius.circular(12),
                border: key == sel ? Border.all(color: ink, width: 2) : null,
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('$n', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: colors.fg)),
                  Text(key == t ? 'Today' : (past ? '' : '$open free'), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: colors.fg)),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(onPressed: prevOk ? () => setState(() => _month = DateTime(m.year, m.month - 1)) : null, icon: const Icon(Icons.chevron_left_rounded)),
              Expanded(child: Text('${_months[m.month - 1]} ${m.year}', textAlign: TextAlign.center, style: hd(18))),
              IconButton(onPressed: nextOk ? () => setState(() => _month = DateTime(m.year, m.month + 1)) : null, icon: const Icon(Icons.chevron_right_rounded)),
            ],
          ),
          Row(
            children: [
              for (final w in _weekdays) Expanded(child: Center(child: Text(w, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: muted(context))))),
            ],
          ),
          const SizedBox(height: 6),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 0.85,
            children: cells,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _legend(context, Tone.good, 'Vacant'),
              _legend(context, Tone.info, 'Partly booked'),
              _legend(context, Tone.bad, 'Occupied'),
              _legend(context, Tone.warn, 'Pending request'),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: Text('Pending requests hold their slot until the office reviews them.', style: TextStyle(color: muted(context), fontSize: 11.5))),
              TextButton(onPressed: () => _pickDay(t), child: const Text('Today')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(BuildContext context, Tone t, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: toneOf(context, t).fg, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(fontSize: 12, color: muted(context))),
    ]);
  }

  Widget _slot(BuildContext context, int i, String label, String d) {
    final st = app.slotState(fac, i, d);
    final open = st == 'open';
    final picked = open && pick == i;
    final tone = st == 'pending' ? Tone.warn : (st == 'booked' ? Tone.bad : (open ? Tone.good : Tone.info));
    final t = toneOf(context, tone);
    final word = picked ? 'Selected' : (open ? 'Vacant' : (st == 'pending' ? 'Pending' : (st == 'booked' ? 'Booked' : (st == 'closed' ? (app.slotBlock(fac, i, d)?.reason ?? 'Unavailable') : 'Unavailable'))));
    return GestureDetector(
      onTap: open ? () => setState(() => pick = picked ? null : i) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(color: picked ? ink : t.bg, borderRadius: BorderRadius.circular(14)),
        alignment: Alignment.center,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: picked ? Colors.white : t.fg)),
                Text(word, style: TextStyle(fontSize: 11, color: picked ? lav : t.fg)),
              ],
            ),
            if (picked) const Positioned(top: 5, right: 7, child: Icon(Icons.close_rounded, size: 16, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
