// RESIDENT page: Events and RSVP.

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../widgets/widgets.dart';

/// Resident: community events, with "I'm going".
class ResEvents extends StatefulWidget {
  const ResEvents({super.key});

  @override
  State<ResEvents> createState() => _ResEventsState();
}

class _ResEventsState extends State<ResEvents> {
  String _filter = 'all';

  /// "Oct 18, 2026 · 6:00 PM" -> (OCT, 18). "Every Sat · 6:00 AM" -> (SAT, •).
  (String, String) _badge(String date) {
    final m = RegExp(r'^([A-Za-z]{3})[a-z]* (\d{1,2})').firstMatch(date);
    if (m != null) return (m[1]!.toUpperCase(), m[2]!);
    final e = RegExp(r'^Every ([A-Za-z]{3})').firstMatch(date);
    if (e != null) return (e[1]!.toUpperCase(), '•');
    return ('', '•');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final going = app.events.where((e) => app.rsvp.contains(e.id)).length;
        final labels = <String, String>{
          'all': 'All events (${app.events.length})',
          'mine': "I'm going ($going)",
        };
        final shown = app.events.where((e) => _filter == 'all' || app.rsvp.contains(e.id)).toList();
        const colors = [Pastel.butter, Pastel.mint, Pastel.peach, Pastel.sky, Pastel.lavender];
        return SubPage(
          title: 'Community events',
          subtitle: 'See what is coming up and tell us you are going.',
          children: [
            FilterRow(
              options: labels.values.toList(),
              selected: labels[_filter]!,
              onSelect: (v) => setState(() => _filter = labels.entries.firstWhere((e) => e.value == v).key),
            ),
            if (shown.isEmpty) const EmptyBox('You have not said you are going to any event yet.', icon: Icons.celebration_outlined),
            for (var i = 0; i < shown.length; i++) _card(shown[i], colors[i % colors.length]),
          ],
        );
      },
    );
  }

  Widget _card(EventItem e, Pastel color) {
    final b = _badge(e.date);
    final yes = app.rsvp.contains(e.id);
    return PastelCard(
      color: color,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(color: Colors.white.withAlpha(190), borderRadius: BorderRadius.circular(18)),
            child: Column(
              children: [
                Text(b.$1, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1, color: inkSoft)),
                Text(b.$2, style: hd(22, color: ink)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.title, style: hd(17)),
                const SizedBox(height: 3),
                Text('${e.date} · ${e.place}', style: const TextStyle(color: inkSoft, fontSize: 12.5, height: 1.3)),
                if (e.about.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(e.about, style: const TextStyle(fontSize: 13.5, height: 1.4)),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text('${app.goingCount(e)} going', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                    const Spacer(),
                    FilledButton(
                      onPressed: () {
                        app.toggleRsvp(e);
                        msg(context, app.rsvp.contains(e.id) ? 'See you at ${e.title}!' : 'Removed from ${e.title}.');
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: yes ? Colors.white.withAlpha(200) : ink,
                        foregroundColor: yes ? ink : Colors.white,
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                      ),
                      child: Text(yes ? "You're going ✓" : "I'm going"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
