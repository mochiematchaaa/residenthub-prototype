// ADMIN page: Grievances.

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../services/demo.dart' show kDemo;
import '../../widgets/widgets.dart';
import '../shared/maintenance_widgets.dart';

class AdminGrievances extends StatefulWidget {
  const AdminGrievances({super.key});

  @override
  State<AdminGrievances> createState() => _AdminGrievancesState();
}

class _AdminGrievancesState extends State<AdminGrievances> {
  bool showDone = false;

  static const _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

  /// Done complaints, compiled by the month they were finished.
  List<Widget> _done(BuildContext context, List<Grievance> done) {
    if (done.isEmpty) return const [EmptyBox('Nothing is done yet. Resolved complaints are compiled here by month.', icon: Icons.task_alt_rounded)];
    final groups = <String, List<Grievance>>{};
    final order = <String>[];
    final sorted = [...done]..sort((a, b) {
        final da = maint.repairs[a.id]?.resolvedOn, db = maint.repairs[b.id]?.resolvedOn;
        if (da != null && db != null) return db.compareTo(da);
        if (da != null) return -1;
        if (db != null) return 1;
        return b.id.compareTo(a.id);
      });
    for (final g in sorted) {
      final d = maint.repairs[g.id]?.resolvedOn;
      final k = d == null ? 'Earlier' : '${_months[d.month - 1]} ${d.year}';
      groups.putIfAbsent(k, () {
        order.add(k);
        return [];
      }).add(g);
    }
    final total = done.fold<num>(0, (s, g) => s + (maint.repairs[g.id]?.cost ?? 0));
    return [
      RCard(
        child: Row(children: [
          Expanded(child: Column(children: [Text('${done.length}', style: hd(24)), Text('Resolved', style: TextStyle(color: muted(context), fontSize: 12))])),
          Expanded(child: Column(children: [Text(peso(total), style: hd(24)), Text('Total repair cost', style: TextStyle(color: muted(context), fontSize: 12))])),
        ]),
      ),
      for (final k in order) ...[
        SectionHeader('$k · ${groups[k]!.length} resolved'),
        for (final g in groups[k]!) _doneRow(context, g),
      ],
    ];
  }

  Widget _doneRow(BuildContext context, Grievance g) {
    final a = maint.repairs[g.id];
    final who = maint.staffById(a?.staffId);
    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(g.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
            const Pill('Resolved', tone: Tone.good),
          ]),
          const SizedBox(height: 2),
          Text('${g.by}${who != null ? ' · handled by ${who.name}' : ''}', style: TextStyle(color: muted(context), fontSize: 12.5)),
          if (a != null && a.completion.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(a.completion, style: const TextStyle(fontSize: 13)),
          ],
          if (a != null && (a.resolvedOn != null || a.cost > 0)) ...[
            const SizedBox(height: 4),
            Text('${a.resolvedOn != null ? shortDate(a.resolvedOn!) : ''}${a.resolvedOn != null && a.cost > 0 ? ' · ' : ''}${a.cost > 0 ? peso(a.cost) : ''}',
                style: TextStyle(color: muted(context), fontSize: 12.5)),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([app, maint]),
      builder: (context, _) {
        final active = [for (final g in app.grievances) if (g.stage < 2) g];
        final done = [for (final g in app.grievances) if (g.stage >= 2) g];
        return SubPage(
          title: 'Complaints',
          subtitle: kDemo
              ? 'Track resident concerns, assign the repair, and move them to resolved. Finished ones are compiled under Done.'
              : 'Track resident concerns and move them to resolved. Finished ones are compiled under Done.',
          children: [
            FilterRow(
              options: ['Active (${active.length})', 'Done (${done.length})'],
              selected: showDone ? 'Done (${done.length})' : 'Active (${active.length})',
              onSelect: (v) => setState(() => showDone = v.startsWith('Done')),
            ),
            if (showDone)
              ..._done(context, done)
            else ...[
              if (active.isEmpty) EmptyBox(app.grievances.isEmpty ? 'No complaints from residents yet.' : 'No active complaints. Finished ones are under Done.', icon: Icons.task_alt_rounded),
              for (final g in active) _GrievanceCard(g),
            ],
          ],
        );
      },
    );
  }
}

class _GrievanceCard extends StatelessWidget {
  final Grievance g;
  const _GrievanceCard(this.g);

  @override
  Widget build(BuildContext context) {
    final advance = FilledButton(
      onPressed: () {
        if (kDemo && g.stage == 1) {
          showResolveSheet(context, g);
        } else {
          app.advanceGrievance(g.id);
        }
      },
      child: Text(g.stage == 0 ? 'Start working on it' : 'Mark resolved'),
    );
    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(g.title, style: hd(16))),
            Pill(g.statusLabel),
          ]),
          const SizedBox(height: 3),
          Text('Reported by ${g.by}', style: TextStyle(color: muted(context), fontSize: 12.5)),
          if (g.body.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(g.body, style: TextStyle(color: muted(context), fontSize: 13)),
          ],
          if (kDemo) RepairInfo(g, admin: true),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < 3; i++)
                Expanded(
                  child: Container(
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: i <= g.stage ? (g.stage == 2 ? const Color(0xFF3F8F5B) : lav) : Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                ),
            ],
          ),
          if (g.stage < 2) ...[
            const SizedBox(height: 12),
            if (kDemo)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => showAssignSheet(context, g),
                      child: Text(maint.staffById(maint.repairs[g.id]?.staffId) != null ? 'Reassign' : 'Assign repair'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: advance),
                ],
              )
            else
              SizedBox(width: double.infinity, child: advance),
          ],
        ],
      ),
    );
  }
}
