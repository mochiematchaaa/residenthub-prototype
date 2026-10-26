// RESIDENT page: Grievances (send and follow progress).

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../services/demo.dart' show kDemo;
import '../shared/maintenance_widgets.dart';
import '../../widgets/widgets.dart';

class ResGrievances extends StatelessWidget {
  const ResGrievances({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([app, maint]),
      builder: (context, _) {
        final list = app.myGrievances;
        return SubPage(
          title: 'Grievances',
          subtitle: 'Submit a concern and track its status. The association will follow up here.',
          fab: FloatingActionButton.extended(
            backgroundColor: lav,
            foregroundColor: ink,
            onPressed: () => showFormSheet(
              context,
              title: 'Submit a grievance',
              fields: const [
                FieldSpec('title', 'Subject', hint: 'e.g. Leaking pipe in the hallway'),
                FieldSpec('body', 'Details', hint: 'Describe the concern', lines: 4),
              ],
              submit: 'Submit grievance',
              onSubmit: (v) {
                final t = (v['title'] as String).trim();
                if (t.isEmpty) return 'Add a subject so the office knows what this is about.';
                app.addGrievance(t, (v['body'] as String).trim());
                return null;
              },
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text('New'),
          ),
          children: [
            if (list.isEmpty) const EmptyBox('No grievances submitted yet.', icon: Icons.sentiment_satisfied_alt_outlined),
            for (final g in list)
              RCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: Text(g.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5))),
                      Pill(g.statusLabel),
                    ]),
                    if (g.body.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(g.body, style: TextStyle(color: muted(context), fontSize: 13, height: 1.4)),
                    ],
                    const SizedBox(height: 12),
                    _Progress(stage: g.stage, labels: const ['Open', 'In progress', 'Resolved']),
                    if (kDemo) RepairInfo(g),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Progress extends StatelessWidget {
  final int stage;
  final List<String> labels;
  const _Progress({required this.stage, required this.labels});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: i <= stage ? (stage == 2 ? const Color(0xFF3F8F5B) : lav) : Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(labels[i], style: TextStyle(fontSize: 11, fontWeight: i == stage ? FontWeight.w800 : FontWeight.w500, color: i == stage ? null : muted(context))),
              ],
            ),
          ),
      ],
    );
  }
}
