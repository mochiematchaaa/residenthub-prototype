// DEMO ONLY - RESIDENT page: Maintenance (what the office is servicing, and my repair requests).

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../widgets/widgets.dart';
import '../shared/maintenance_widgets.dart';
import 'grievances_screen.dart';

class ResMaintenance extends StatelessWidget {
  const ResMaintenance({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([app, maint]),
      builder: (context, _) {
        final upcoming = maint.sortedTasks.where((t) => daysFromToday(t.due) <= 30).toList();
        final done = maint.tasks.where((t) => t.lastDone != null).toList()
          ..sort((a, b) => b.lastDone!.compareTo(a.lastDone!));
        final mine = app.myGrievances.where((g) => g.stage < 2 && maint.staffById(maint.repairs[g.id]?.staffId) != null).toList();
        return SubPage(
          title: 'Maintenance',
          subtitle: 'What the office is servicing, and the status of your repair requests. Some work may cause short interruptions.',
          children: [
            for (final e in maint.closures)
              RCard(
                color: toneOf(context, Tone.warn).bg,
                child: Text(
                  '${e.facility} is closed for maintenance. ${e.name} is ${e.status.toLowerCase()}. It cannot be booked until it is working again.',
                  style: TextStyle(color: toneOf(context, Tone.warn).fg, fontWeight: FontWeight.w600, height: 1.4),
                ),
              ),
            const SectionHeader('Coming up in the next 30 days'),
            if (upcoming.isEmpty) const EmptyBox('Nothing is scheduled in the next 30 days.', icon: Icons.handyman_outlined),
            for (final t in upcoming)
              RCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                          const SizedBox(height: 2),
                          Text('${maint.equipOf(t).isEmpty ? 'Building' : maint.equipOf(t)} · ${t.every} · ${shortDate(t.due)}',
                              style: TextStyle(color: muted(context), fontSize: 12.5)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Pill(taskState(t).$1, tone: toneFromLevel(taskState(t).$2)),
                  ],
                ),
              ),
            const SectionHeader('Your repair requests'),
            if (mine.isEmpty)
              RCard(child: Text('No repair is assigned yet for your unit.', style: TextStyle(color: muted(context)))),
            for (final g in mine)
              RCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: Text(g.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
                      Pill(g.statusLabel),
                    ]),
                    RepairInfo(g),
                  ],
                ),
              ),
            OutlinedButton.icon(
              onPressed: () => go(context, const ResGrievances()),
              icon: const Icon(Icons.edit_note_rounded),
              label: const Text('Report a problem'),
            ),
            const SectionHeader('Recently completed'),
            for (final t in done.take(5))
              RCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text('${shortDate(t.lastDone!)}${maint.assigneeOf(t).isEmpty ? '' : ' · ${maint.assigneeOf(t)}'}',
                        style: TextStyle(color: muted(context), fontSize: 12.5)),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
