// Calendar page used by both admin and resident (events, bookings, due dates).

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../widgets/widgets.dart';

/// Shared by the resident and admin apps (`admin: true` shows every booking).
enum EntryKind { event, booking, due }

/// One thing shown on the calendar.
class CalEntry {
  final EntryKind kind;
  final String title;
  final String subtitle;
  const CalEntry(this.kind, this.title, this.subtitle);
}

const _months3 = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
const _wd3 = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun']; // index + 1 == DateTime.weekday

bool _same(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// The sample data stores dates as text ("Oct 3, 6:00 PM", "Saturday, 2 PM",
/// "Tomorrow, 3 PM"...). This turns the leading date part into a real date.
DateTime? _parseLoose(String raw, DateTime now) {
  final s = raw.trim().toLowerCase();
  final today = DateTime(now.year, now.month, now.day);
  final m = RegExp(r'^([a-z]{3})[a-z]* (\d{1,2})(?:, (\d{4}))?').firstMatch(s);
  if (m != null) {
    final mi = _months3.indexOf(m.group(1)!);
    if (mi >= 0) {
      return DateTime(int.tryParse(m.group(3) ?? '') ?? now.year, mi + 1, int.parse(m.group(2)!));
    }
  }
  if (s.startsWith('tomorrow')) return today.add(const Duration(days: 1));
  if (s.startsWith('today') || s.contains(' today')) return today;
  final w = RegExp(r'^([a-z]{3})').firstMatch(s);
  if (w != null) {
    final wi = _wd3.indexOf(w.group(1)!);
    if (wi >= 0) return today.add(Duration(days: ((wi + 1) - today.weekday) % 7));
  }
  return null;
}

List<CalEntry> entriesFor(DateTime day, {required bool admin}) {
  final now = DateTime.now();
  final out = <CalEntry>[];

  for (final e in app.events) {
    final rec = RegExp(r'^every ([a-z]{3})').firstMatch(e.date.toLowerCase());
    final bool hit;
    if (rec != null) {
      hit = _wd3.indexOf(rec.group(1)!) + 1 == day.weekday;
    } else {
      final d = _parseLoose(e.date, now);
      hit = d != null && _same(d, day);
    }
    if (hit) out.add(CalEntry(EntryKind.event, e.title, '${e.date.split(' · ').last} · ${e.place}'));
  }

  for (final b in (admin ? app.bookings : app.myBookings)) {
    if (b.status == 'Denied') continue;
    final d = _parseLoose(b.when, now);
    if (d != null && _same(d, day)) {
      out.add(CalEntry(EntryKind.booking, b.place, '${admin ? '${b.who} · ' : ''}${b.when} · ${b.status}'));
    }
  }

  if (!admin) {
    for (final r in app.myDueRows) {
      final d = _parseLoose(r.due, now);
      if (d != null && _same(d, day)) {
        out.add(CalEntry(EntryKind.due, 'Dues: ${r.month}', '${peso(r.amt)} · ${r.status}'));
      }
    }
  }
  return out;
}

Color _dotColor(EntryKind k) => switch (k) {
      EntryKind.event => const Color(0xFF3DB89E),
      EntryKind.booking => const Color(0xFFE8914A),
      EntryKind.due => const Color(0xFFD9A81E),
    };

Pastel _pastelOf(EntryKind k) => switch (k) {
      EntryKind.event => Pastel.mint,
      EntryKind.booking => Pastel.peach,
      EntryKind.due => Pastel.butter,
    };

/// Home-screen entry card: shows how many things are scheduled today.
class CalendarCard extends StatelessWidget {
  final bool admin;
  const CalendarCard({super.key, required this.admin});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final n = entriesFor(now, admin: admin).length;
    return PastelCard(
      color: Pastel.sky,
      onTap: () => go(context, CalendarScreen(admin: admin)),
      child: Row(
        children: [
          const GlassIcon(Icons.calendar_month_rounded, size: 48),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Calendar', style: TextStyle(color: inkSoft, fontSize: 12.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(n == 0 ? 'Nothing scheduled today' : '$n scheduled today', style: hd(17)),
                Text(longDate(now), style: const TextStyle(color: inkSoft, fontSize: 12.5)),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_rounded),
        ],
      ),
    );
  }
}

class CalendarScreen extends StatefulWidget {
  final bool admin;
  const CalendarScreen({super.key, required this.admin});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  static const _weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _todayYellow = Color(0xFFFFD84D);

  late DateTime month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime? selected; // null = show the whole month's agenda

  void _shift(int by) => setState(() {
        month = DateTime(month.year, month.month + by, 1);
        selected = null;
      });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
        final agenda = <(DateTime, CalEntry)>[];
        for (var d = 1; d <= daysInMonth; d++) {
          final day = DateTime(month.year, month.month, d);
          if (selected != null && !_same(day, selected!)) continue;
          for (final e in entriesFor(day, admin: widget.admin)) {
            agenda.add((day, e));
          }
        }
        return SubPage(
          title: 'Calendar',
          actions: [
            TextButton(
              onPressed: () => setState(() {
                final n = DateTime.now();
                month = DateTime(n.year, n.month, 1);
                selected = n;
              }),
              child: const Text('Today'),
            ),
          ],
          children: [
            _monthCard(context),
            Text(
              selected == null ? 'All of ${_monthNames[month.month - 1]}' : longDate(selected!),
              style: hd(18),
            ),
            if (agenda.isEmpty)
              const EmptyBox('Nothing scheduled here.', icon: Icons.event_busy_outlined)
            else
              Column(children: [for (final a in agenda) _agendaRow(a.$1, a.$2)]),
            _legendPill(context),
          ],
        );
      },
    );
  }

  // ---- month grid in the style of the reference: Monday first, Sunday in red,
  // circled days have something scheduled, today is filled yellow.
  Widget _monthCard(BuildContext context) {
    final lead = month.weekday - 1;
    final days = DateTime(month.year, month.month + 1, 0).day;
    final rows = ((lead + days) / 7).ceil();
    final cs = Theme.of(context).colorScheme;
    return RCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Previous month',
                onPressed: () => _shift(-1),
                icon: const Icon(Icons.arrow_left_rounded, size: 34),
              ),
              Text('${_monthNames[month.month - 1]}, ${month.year}', style: hd(16.5, w: FontWeight.w700)),
              IconButton(
                tooltip: 'Next month',
                onPressed: () => _shift(1),
                icon: const Icon(Icons.arrow_right_rounded, size: 34),
              ),
            ],
          ),
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Center(
                    child: Text(
                      _weekdayNames[i],
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: i == 6 ? danger : cs.onSurface,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Divider(height: 1, color: cs.onSurface.withAlpha(90)),
          const SizedBox(height: 6),
          for (var r = 0; r < rows; r++)
            Row(
              children: [
                for (var c = 0; c < 7; c++)
                  Expanded(child: _cell(context, DateTime(month.year, month.month, 1 - lead + r * 7 + c), c == 6)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _cell(BuildContext context, DateTime d, bool sunday) {
    final inMonth = d.month == month.month;
    final sel = selected != null && _same(d, selected!);
    final isToday = _same(d, DateTime.now());
    final has = entriesFor(d, admin: widget.admin).isNotEmpty;
    final cs = Theme.of(context).colorScheme;

    Color? fill;
    Color text = sunday ? danger : cs.onSurface;
    if (sel) {
      fill = lavDeep;
      text = Colors.white;
    } else if (isToday) {
      fill = _todayYellow;
      text = ink;
    }
    if (!inMonth) text = text.withAlpha(90);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() {
        if (!inMonth) month = DateTime(d.year, d.month, 1);
        selected = sel ? null : d;
      }),
      child: SizedBox(
        height: 46,
        child: Center(
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: fill,
              shape: BoxShape.circle,
              border: has && fill == null && inMonth ? Border.all(color: cs.onSurface.withAlpha(150), width: 1.3) : null,
            ),
            child: Text(
              '${d.day}',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: sel || isToday || has ? FontWeight.w800 : FontWeight.w500,
                color: text,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---- agenda rows: coloured date tab on the left, wide card on the right.
  Widget _agendaRow(DateTime day, CalEntry e) {
    final base = _pastelOf(e.kind).color;
    final tab = Color.lerp(base, ink, 0.1)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 62,
              decoration: BoxDecoration(
                color: tab,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
              ),
              child: DefaultTextStyle.merge(
                style: const TextStyle(color: ink),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_weekdayNames[day.weekday - 1], style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                    Text('${day.day}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.1)),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: base,
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(24)),
                ),
                child: DefaultTextStyle.merge(
                  style: const TextStyle(color: ink),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(e.title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                      const SizedBox(height: 3),
                      Text(e.subtitle, textAlign: TextAlign.center, style: const TextStyle(color: inkSoft, fontSize: 12, height: 1.3)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- the little "Note" pill at the bottom of the reference.
  Widget _legendPill(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(99)),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 16,
        runSpacing: 6,
        children: [
          _legend('Community event', EntryKind.event),
          _legend('Facility booking', EntryKind.booking),
          if (!widget.admin) _legend('Dues due date', EntryKind.due),
        ],
      ),
    );
  }

  Widget _legend(String text, EntryKind k) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: _pastelOf(k).color, shape: BoxShape.circle, border: Border.all(color: _dotColor(k), width: 1.5))),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(color: muted(context), fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      );
}
