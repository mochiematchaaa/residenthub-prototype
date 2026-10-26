// DEMO ONLY - ADMIN page: Maintenance (preventive schedule, equipment list, maintenance staff).

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../widgets/widgets.dart';
import '../shared/import_sheet.dart';
import '../shared/maintenance_widgets.dart';
import '../shared/notify_sheet.dart';

class AdminMaintenance extends StatefulWidget {
  const AdminMaintenance({super.key});

  @override
  State<AdminMaintenance> createState() => _AdminMaintenanceState();
}

class _AdminMaintenanceState extends State<AdminMaintenance> {
  static const _tabs = ['Schedule', 'Equipment', 'Staff'];
  static const _builtinKinds = ['All', 'Routine', 'Permits and tests'];
  String tab = 'Schedule';
  String kind = 'All';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([app, maint]),
      builder: (context, _) {
        return SubPage(
          title: 'Maintenance',
          subtitle: 'Preventive maintenance schedule, equipment, and the staff who do the work.',
          fab: FloatingActionButton.extended(
            backgroundColor: lav,
            foregroundColor: ink,
            onPressed: () {
              if (tab == 'Schedule') {
                showTaskSheet(context);
              } else if (tab == 'Equipment') {
                showEquipmentSheet(context);
              } else {
                showStaffSheet(context);
              }
            },
            icon: const Icon(Icons.add_rounded),
            label: Text(tab == 'Schedule' ? 'Task' : tab == 'Equipment' ? 'Equipment' : 'Staff'),
          ),
          children: [
            Row(
              children: [
                Expanded(child: MaintStat('Overdue', maint.overdueCount, tone: maint.overdueCount > 0 ? Tone.bad : null)),
                const SizedBox(width: 10),
                Expanded(child: MaintStat('Due in 7 days', maint.dueThisWeekCount, tone: maint.dueThisWeekCount > 0 ? Tone.warn : null)),
                const SizedBox(width: 10),
                Expanded(child: MaintStat('To fix', maint.equipmentToFix, tone: maint.equipmentToFix > 0 ? Tone.bad : null)),
              ],
            ),
            Text(_summary(), style: TextStyle(color: muted(context), fontSize: 12.5, height: 1.4)),
            ImportBar(tab == 'Schedule' ? const ['mtasks'] : tab == 'Equipment' ? const ['equipment'] : const ['staff']),
            FilterRow(options: _tabs, selected: tab, onSelect: (t) => setState(() => tab = t)),
            if (tab == 'Schedule') FilterRow(options: [..._builtinKinds, ...maint.customKinds], selected: kind, onSelect: (k) => setState(() => kind = k)),
            if (tab == 'Schedule' && maint.customKinds.contains(kind))
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(spacing: 8, children: [
                OutlinedButton.icon(
                  onPressed: () => showRenameKindSheet(context, kind, onRenamed: (n) => setState(() => kind = n)),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Rename this type'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final ok = await confirmDialog(context, 'Delete type', 'Delete the type “$kind”? Its tasks stay and become routine maintenance.', confirm: 'Delete', destructive: true);
                    if (ok) {
                      final k = kind;
                      setState(() => kind = 'All');
                      maint.deleteKind(k, app);
                    }
                  },
                  icon: const Icon(Icons.delete_outline_rounded, color: danger),
                  label: const Text('Delete this type'),
                ),
                ]),
              ),
            if (tab == 'Schedule') ..._schedule(context),
            if (tab == 'Equipment') ..._equipment(context),
            if (tab == 'Staff') ..._staff(context),
          ],
        );
      },
    );
  }

  String _summary() {
    final now = DateTime.now();
    final rt = maint.repairTime;
    final avg = rt.$1;
    final closed = maint.closures.map((e) => e.facility).toSet().join(', ');
    return 'Spent on maintenance: ${peso(maint.spentIn(now.year, now.month))} this month, ${peso(maint.spentIn(now.year))} this year. '
        '${avg == null ? 'No finished repairs yet.' : 'Average repair time ${avg < 1 ? 'under a day' : '${avg.toStringAsFixed(1)} days'} across ${rt.$2} finished repairs.'}'
        '${closed.isEmpty ? '' : ' Closed to bookings now: $closed.'}';
  }

  List<Widget> _schedule(BuildContext context) {
    final list = maint.sortedTasks
        .where((t) => kind == 'All' || (kind == 'Routine' ? t.kind == kindRoutine : (kind == 'Permits and tests' ? t.kind == kindCompliance : t.kind == kind)))
        .toList();
    if (list.isEmpty) return [const EmptyBox('No maintenance tasks yet. Tap Task to add one.', icon: Icons.handyman_outlined), ..._recentNotices(context)];
    return [
      for (final t in list)
        RCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text(t.title, style: hd(16))),
                Pill(taskState(t).$1, tone: toneFromLevel(taskState(t).$2)),
              ]),
              if (t.kind != kindRoutine) ...[
                const SizedBox(height: 4),
                Align(alignment: Alignment.centerLeft, child: Pill(kindLabel(t.kind), tone: Tone.info)),
              ],
              const SizedBox(height: 3),
              Text('${maint.equipOf(t).isEmpty ? 'No equipment' : maint.equipOf(t)} · ${t.every}', style: TextStyle(color: muted(context), fontSize: 12.5)),
              const SizedBox(height: 6),
              Text('Next due ${shortDate(t.due)}${t.lastDone == null ? '' : ' · last done ${shortDate(t.lastDone!)}'}', style: const TextStyle(fontSize: 13)),
              Text(maint.assigneeOf(t).isEmpty ? 'Not assigned yet' : 'Assigned to ${maint.assigneeOf(t)}',
                  style: TextStyle(color: muted(context), fontSize: 13)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () => showDoneSheet(context, t),
                    child: const Text('Mark done'),
                  ),
                ),
                IconButton(tooltip: 'Notify residents', onPressed: () => showNotifySheet(context, t), icon: const Icon(Icons.campaign_outlined)),
                IconButton(tooltip: 'Edit', onPressed: () => showTaskSheet(context, task: t), icon: const Icon(Icons.edit_outlined)),
                IconButton(
                  tooltip: 'Delete',
                  onPressed: () async {
                    final ok = await confirmDialog(context, 'Delete task', 'Delete “${t.title}”? This cannot be undone.', confirm: 'Delete', destructive: true);
                    if (ok) maint.deleteTask(t, app);
                  },
                  icon: const Icon(Icons.delete_outline_rounded, color: danger),
                ),
              ]),
            ],
          ),
        ),
      ..._recentNotices(context),
    ];
  }

  List<Widget> _recentNotices(BuildContext context) {
    return [
      const SizedBox(height: 4),
      Row(children: [
        Expanded(child: Text('Recent notices', style: hd(17))),
        TextButton.icon(onPressed: () => showNotifySheet(context), icon: const Icon(Icons.campaign_outlined), label: const Text('New notice')),
      ]),
      if (maint.notices.isEmpty)
        Text('Nothing sent yet. Tap Notify on a task, or New notice, to choose who to tell.', style: TextStyle(color: muted(context), fontSize: 12.5))
      else
        for (final n in maint.notices.take(6))
          RCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(n.title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                '${shortDate(n.at)} · ${n.everyone ? 'All residents' : '${n.count} resident${n.count == 1 ? '' : 's'}'}'
                '${n.text ? ' · dashboard, app and text message to ${n.textCount}${n.noPhone > 0 ? ' (${n.noPhone} had no mobile number)' : ''}' : ' · dashboard and app only'}',
                style: TextStyle(color: muted(context), fontSize: 12.5),
              ),
            ]),
          ),
    ];
  }

  List<Widget> _equipment(BuildContext context) {
    final list = [...maint.equipment]..sort((a, b) => a.name.compareTo(b.name));
    if (list.isEmpty) return const [EmptyBox('No equipment listed yet. Tap Equipment to add one.', icon: Icons.precision_manufacturing_outlined)];
    return [
      for (final e in list)
        RCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text(e.name, style: hd(16))),
                Pill(e.status, tone: equipmentTone(e.status)),
              ]),
              const SizedBox(height: 3),
              Text('${e.category} · ${e.location}${e.vendor.isEmpty ? '' : ' · ${e.vendor}'}', style: TextStyle(color: muted(context), fontSize: 12.5)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(e.lastService == null ? 'Never serviced' : 'Last service ${shortDate(e.lastService!)}', style: const TextStyle(fontSize: 13)),
                if (maint.openRepairsFor(app, e.id) > 0) Pill('${maint.openRepairsFor(app, e.id)} open repair', tone: Tone.warn),
                if (e.warranty != null) _warranty(e.warranty!),
                if (maint.spentOn(e.id) > 0) Text('Spent ${peso(maint.spentOn(e.id))}', style: const TextStyle(fontSize: 13)),
              ]),
              if (e.facility.isNotEmpty && e.closes) ...[
                const SizedBox(height: 4),
                Text('Closes ${e.facility} to booking while not working', style: TextStyle(color: muted(context), fontSize: 12.5)),
              ],
              const SizedBox(height: 6),
              Row(children: [
                TextButton.icon(onPressed: () => showEquipmentSheet(context, item: e), icon: const Icon(Icons.edit_outlined, size: 18), label: const Text('Edit')),
                TextButton.icon(
                  onPressed: () async {
                    final ok = await confirmDialog(context, 'Delete equipment', 'Delete “${e.name}”? This cannot be undone.', confirm: 'Delete', destructive: true);
                    if (!ok || !context.mounted) return;
                    final problem = maint.deleteEquipment(e, app);
                    if (problem != null) msg(context, problem);
                  },
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: danger),
                  label: const Text('Delete', style: TextStyle(color: danger)),
                ),
              ]),
            ],
          ),
        ),
    ];
  }

  Widget _warranty(DateTime d) {
    final n = daysFromToday(d);
    if (n < 0) return const Pill('Warranty expired', tone: Tone.bad);
    if (n <= 30) return Pill('Warranty ends in $n day${n == 1 ? '' : 's'}', tone: Tone.warn);
    return Text('Warranty until ${shortDate(d)}', style: const TextStyle(fontSize: 13));
  }

  List<Widget> _staff(BuildContext context) {
    final list = [...maint.staff]..sort((a, b) => a.name.compareTo(b.name));
    if (list.isEmpty) return const [EmptyBox('No maintenance staff yet. Tap Staff to add one.', icon: Icons.engineering_outlined)];
    return [
      for (final s in list)
        RCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.name, style: hd(16)),
              const SizedBox(height: 3),
              Text('${s.role}${s.phone.isEmpty ? '' : ' · ${s.phone}'}', style: TextStyle(color: muted(context), fontSize: 12.5)),
              const SizedBox(height: 6),
              Text('${maint.openWorkOf(s, app)} open assignment(s)', style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 6),
              Row(children: [
                TextButton.icon(onPressed: () => showStaffSheet(context, person: s), icon: const Icon(Icons.edit_outlined, size: 18), label: const Text('Edit')),
                TextButton.icon(
                  onPressed: () async {
                    final ok = await confirmDialog(context, 'Delete staff member', 'Delete “${s.name}”? This cannot be undone.', confirm: 'Delete', destructive: true);
                    if (!ok || !context.mounted) return;
                    final problem = maint.deleteStaff(s, app);
                    if (problem != null) msg(context, problem);
                  },
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: danger),
                  label: const Text('Delete', style: TextStyle(color: danger)),
                ),
              ]),
            ],
          ),
        ),
    ];
  }
}
