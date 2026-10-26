// RESIDENT page: My reservations.

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../widgets/widgets.dart';

class ResReservations extends StatelessWidget {
  const ResReservations({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final list = app.myBookings;
        return SubPage(
          title: 'My reservations',
          subtitle: "Every facility request you've made, and its current status.",
          fab: FloatingActionButton.extended(
            backgroundColor: lav,
            foregroundColor: ink,
            onPressed: () {
              Navigator.of(context).pop();
              app.setResTab(1);
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('New booking'),
          ),
          children: [
            if (list.isEmpty) const EmptyBox('No reservations yet.', icon: Icons.event_busy_outlined),
            for (final b in list)
              RCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    IconBadge(amenityIcon(b.place), accent: true),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(b.place, style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(b.when, style: TextStyle(color: muted(context), fontSize: 12.5)),
                        ],
                      ),
                    ),
                    Pill(b.status),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
