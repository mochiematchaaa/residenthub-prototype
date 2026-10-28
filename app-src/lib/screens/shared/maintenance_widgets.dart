// DEMO ONLY: small pieces and popup forms shared by the maintenance screens (admin and resident).

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../widgets/widgets.dart';

/// Pill color for a task state level: 0 fine, 1 soon, 2 overdue.
Tone toneFromLevel(int level) => level == 2 ? Tone.bad : level == 1 ? Tone.warn : Tone.good;

/// Pill color for the condition of a piece of equipment.
Tone equipmentTone(String status) =>
    status == 'Working' ? Tone.good : status == 'Under maintenance' ? Tone.warn : Tone.bad;

/// A small card with a label and a big number.
class MaintStat extends StatelessWidget {
  final String label;
  final int value;
  final Tone? tone;

  /// When set, the card can be tapped and shows a "View" hint.
  final VoidCallback? onTap;
  const MaintStat(this.label, this.value, {super.key, this.tone, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = tone == null ? null : toneOf(context, tone!).fg;
    return RCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$value', style: hd(26, color: c)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: muted(context), fontSize: 12, fontWeight: FontWeight.w600)),
          if (onTap != null) ...[
            const SizedBox(height: 4),
            Text('View details \u203A', style: TextStyle(color: c ?? lavDeep, fontSize: 11.5, fontWeight: FontWeight.w800)),
          ],
        ],
      ),
    );
  }
}

/// The page behind one of the three Maintenance numbers: [which] is 'overdue', 'week' or 'fix'.
class MaintStatPage extends StatelessWidget {
  final String which;
  const MaintStatPage(this.which, {super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([app, maint]),
      builder: (context, _) {
        final fix = which == 'fix';
        final tasks = maint.sortedTasks.where((t) {
          final n = daysFromToday(t.due);
          return which == 'overdue' ? n < 0 : (n >= 0 && n <= 7);
        }).toList();
        final equip = maint.equipment.where((e) => e.status != 'Working').toList()..sort((a, b) => a.name.compareTo(b.name));
        final title = which == 'overdue' ? 'Overdue tasks' : fix ? 'Equipment to fix' : 'Due in 7 days';
        final sub = which == 'overdue'
            ? 'Tasks whose due date has passed. Mark them done, or move the date by editing the task.'
            : fix
                ? 'Equipment that is not working. A facility tied to it cannot be booked until it works again.'
                : 'Tasks coming up in the next 7 days.';
        return SubPage(
          title: title,
          subtitle: sub,
          children: [
            if (!fix && tasks.isEmpty) const EmptyBox('Nothing here. All caught up.', icon: Icons.check_circle_outline_rounded),
            if (fix && equip.isEmpty) const EmptyBox('Everything is working.', icon: Icons.check_circle_outline_rounded),
            if (!fix)
              for (final t in tasks)
                RCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(t.title, style: hd(16))),
                      Pill(taskState(t).$1, tone: toneFromLevel(taskState(t).$2)),
                    ]),
                    const SizedBox(height: 3),
                    Text('${maint.equipOf(t).isEmpty ? 'No equipment' : maint.equipOf(t)} \u00B7 ${t.every}', style: TextStyle(color: muted(context), fontSize: 12.5)),
                    const SizedBox(height: 6),
                    Text('Next due ${shortDate(t.due)}', style: const TextStyle(fontSize: 13)),
                    Text(maint.assigneeOf(t).isEmpty ? 'Not assigned yet' : 'Assigned to ${maint.assigneeOf(t)}', style: TextStyle(color: muted(context), fontSize: 13)),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: FilledButton(onPressed: () => showDoneSheet(context, t), child: const Text('Mark done'))),
                      IconButton(tooltip: 'Edit', onPressed: () => showTaskSheet(context, task: t), icon: const Icon(Icons.edit_outlined)),
                    ]),
                  ]),
                ),
            if (fix)
              for (final e in equip)
                RCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(e.name, style: hd(16))),
                      Pill(e.status, tone: equipmentTone(e.status)),
                    ]),
                    const SizedBox(height: 3),
                    Text('${e.category} \u00B7 ${e.location}${e.vendor.isEmpty ? '' : ' \u00B7 ${e.vendor}'}', style: TextStyle(color: muted(context), fontSize: 12.5)),
                    if (maint.openRepairsFor(app, e.id) > 0) ...[
                      const SizedBox(height: 6),
                      Pill('${maint.openRepairsFor(app, e.id)} open repair', tone: Tone.warn),
                    ],
                    if (e.facility.isNotEmpty && e.closes) ...[
                      const SizedBox(height: 4),
                      Text('${e.facility} is closed to booking while this is not working.', style: TextStyle(color: muted(context), fontSize: 12.5)),
                    ],
                    const SizedBox(height: 6),
                    TextButton.icon(onPressed: () => showEquipmentSheet(context, item: e), icon: const Icon(Icons.edit_outlined, size: 18), label: const Text('Edit or change status')),
                  ]),
                ),
          ],
        );
      },
    );
  }
}

/// Who is fixing a grievance, by when, and any note. Residents only see it once someone is assigned.
class RepairInfo extends StatelessWidget {
  final Grievance g;
  final bool admin;
  const RepairInfo(this.g, {super.key, this.admin = false});

  @override
  Widget build(BuildContext context) {
    final a = maint.repairs[g.id];
    final who = maint.staffById(a?.staffId);
    if (a == null || who == null) {
      if (!admin) return const SizedBox.shrink();
      return _box(context, [Text('Not assigned to anyone yet.', style: TextStyle(color: muted(context), fontSize: 13))]);
    }
    final late = admin && g.stage < 2 && a.target != null && daysFromToday(a.target!) < 0;
    final equip = maint.equipById(a.equipId);
    return _box(context, [
      Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text.rich(TextSpan(children: [
            const TextSpan(text: 'Assigned to '),
            TextSpan(text: who.name, style: const TextStyle(fontWeight: FontWeight.w700)),
            if (a.target != null && g.stage < 2) TextSpan(text: ' · target ${shortDate(a.target!)}'),
          ]), style: const TextStyle(fontSize: 13)),
          if (admin) Pill(a.priority, tone: a.priority == 'Urgent' ? Tone.bad : a.priority == 'High' ? Tone.warn : Tone.info),
          if (late) const Pill('Late', tone: Tone.bad),
        ],
      ),
      if (equip != null) Text(admin ? 'Equipment: ${equip.name}' : 'Related to: ${equip.name}', style: TextStyle(color: muted(context), fontSize: 12.5)),
      if (a.notes.isNotEmpty && g.stage < 2)
        Text(admin ? '“${a.notes}”' : 'Update from the office: ${a.notes}',
            style: TextStyle(color: muted(context), fontSize: 12.5, fontStyle: FontStyle.italic)),
      if (g.stage >= 2 && (a.completion.isNotEmpty || (admin && a.cost > 0)))
        Text(
            '${admin ? 'Done' : 'Completed'}${a.resolvedOn == null ? '' : ' ${shortDate(a.resolvedOn!)}'}'
            '${a.completion.isEmpty ? '' : ': ${a.completion}'}'
            '${admin && a.cost > 0 ? ' · cost ${peso(a.cost)}' : ''}',
            style: TextStyle(color: muted(context), fontSize: 12.5)),
    ]);
  }

  Widget _box(BuildContext context, List<Widget> kids) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < kids.length; i++) ...[
              if (i > 0) const SizedBox(height: 3),
              kids[i],
            ],
          ],
        ),
      ),
    );
  }
}

DateTime? _targetFrom(String label) {
  switch (label) {
    case 'Today':
      return inDays(0);
    case 'Tomorrow':
      return inDays(1);
    case 'In 3 days':
      return inDays(3);
    case 'In 1 week':
      return inDays(7);
    case 'In 2 weeks':
      return inDays(14);
    case 'In 1 month':
      return inDays(30);
    default:
      return null; // 'Keep current date'
  }
}

const String _keep = 'Keep current date';

/// Popup to assign (or reassign) the repair of a grievance.
void showAssignSheet(BuildContext context, Grievance g) {
  final a = maint.repairs[g.id];
  final hasTarget = a?.target != null;
  showFormSheet(
    context,
    title: 'Assign repair',
    subtitle: g.title,
    fields: [FieldSpec('notes', 'Note for the repair', hint: 'What needs to be done?', lines: 3, initial: a?.notes ?? '')],
    choices: [
      ChoiceSpec('staff', 'Assigned to', ['Unassigned', ...maint.staff.map((s) => s.name)], maint.staffById(a?.staffId)?.name ?? 'Unassigned'),
      ChoiceSpec('priority', 'Priority', repairPriorities, a?.priority ?? 'Normal'),
      ChoiceSpec('target', 'Target completion date',
          [if (hasTarget) _keep, 'Today', 'Tomorrow', 'In 3 days', 'In 1 week', 'In 2 weeks'], hasTarget ? _keep : 'In 3 days'),
      ChoiceSpec('equip', 'Related equipment (optional)', ['None', ...maint.equipment.map((e) => e.name)], maint.equipById(a?.equipId)?.name ?? 'None'),
    ],
    submit: 'Save assignment',
    onSubmit: (v) {
      maint.assign(
        app,
        g,
        who: maint.staffByName(v['staff'] as String),
        target: _targetFrom(v['target'] as String),
        equip: maint.equipByName(v['equip'] as String),
        notes: (v['notes'] as String).trim(),
        priority: v['priority'] as String,
      );
      return null;
    },
  );
}

const String _newKindChoice = '+ Add new type';

/// Popup to rename a task type you created.
void showRenameKindSheet(BuildContext context, String kind, {required void Function(String newName) onRenamed}) {
  showFormSheet(
    context,
    title: 'Rename type',
    subtitle: 'Every task of this type is renamed too.',
    fields: [FieldSpec('name', 'Type name', initial: kind)],
    submit: 'Save name',
    onSubmit: (v) {
      final r = maint.renameKind(kind, v['name'] as String, app);
      if (r.$1 == null) onRenamed(r.$2);
      return r.$1;
    },
  );
}

/// Popup to add or edit a maintenance task.
void showTaskSheet(BuildContext context, {MTask? task}) {
  showFormSheet(
    context,
    title: task == null ? 'Add maintenance task' : 'Edit maintenance task',
    fields: [
      FieldSpec('title', 'Task', hint: 'e.g. Elevator inspection', initial: task?.title ?? ''),
      FieldSpec('newKind', 'Name of the new type', hint: 'e.g. Inspection', onlyWhenKey: 'kind', onlyWhenValue: _newKindChoice, belowChoice: true),
    ],
    choices: [
      ChoiceSpec('kind', 'Type', [...maint.kinds.map(kindLabel), _newKindChoice], kindLabel(task?.kind ?? kindRoutine)),
      // (the name box for a new type is the field with belowChoice, listed in `fields` above)
      ChoiceSpec('equip', 'Equipment (optional)', ['None', ...maint.equipment.map((e) => e.name)], maint.equipById(task?.equipId)?.name ?? 'None'),
      ChoiceSpec('every', 'Repeats', maintFrequencies.map((f) => f.$1).toList(), task?.every ?? 'Monthly'),
      ChoiceSpec('due', 'Next due',
          [if (task != null) _keep, 'Today', 'In 3 days', 'In 1 week', 'In 2 weeks', 'In 1 month'], task != null ? _keep : 'Today'),
      ChoiceSpec('staff', 'Assigned to', ['Unassigned', ...maint.staff.map((s) => s.name)], maint.staffById(task?.staffId)?.name ?? 'Unassigned'),
    ],
    submit: 'Save task',
    onSubmit: (v) {
      final title = (v['title'] as String).trim();
      if (title.isEmpty) return 'Enter the task.';
      final picked = v['kind'] as String;
      String? kindName;
      if (picked == _newKindChoice) {
        kindName = maint.addKind(v['newKind'] as String);
        if (kindName == null) return 'Type the name of the new type, or pick a type from the list.';
      }
      maint.saveTask(
        app,
        existing: task,
        title: title,
        kind: kindName ?? kindFromLabel(picked),
        every: v['every'] as String,
        due: _targetFrom(v['due'] as String),
        equip: maint.equipByName(v['equip'] as String),
        who: maint.staffByName(v['staff'] as String),
      );
      return null;
    },
  );
}

/// Popup to add or edit a piece of equipment.
void showEquipmentSheet(BuildContext context, {Equipment? item}) {
  showFormSheet(
    context,
    title: item == null ? 'Add equipment' : 'Edit equipment',
    fields: [
      FieldSpec('name', 'Name', hint: 'e.g. Elevator A', initial: item?.name ?? ''),
      FieldSpec('location', 'Location', hint: 'e.g. Basement pump room', initial: item?.location ?? ''),
      FieldSpec('vendor', 'Supplier or service company', initial: item?.vendor ?? ''),
      FieldSpec('warranty', 'Warranty ends (optional)', hint: 'e.g. Mar 5, 2027', initial: item?.warranty == null ? '' : shortDate(item!.warranty!)),
    ],
    choices: [
      ChoiceSpec('category', 'Category', equipmentCategories, item?.category ?? equipmentCategories.first),
      ChoiceSpec('status', 'Condition', equipmentStatuses, item?.status ?? 'Working'),
      ChoiceSpec('facility', 'Part of a bookable facility?', ['None', ...app.amenities.map((a) => a.name)], (item?.facility ?? '').isEmpty ? 'None' : item!.facility),
      ChoiceSpec('closes', 'If it is not working', ['Keep the facility open', 'Close the facility to booking'], (item?.closes ?? false) ? 'Close the facility to booking' : 'Keep the facility open'),
    ],
    submit: 'Save equipment',
    onSubmit: (v) {
      final name = (v['name'] as String).trim();
      if (name.isEmpty) return 'Enter the equipment name.';
      final warrantyText = (v['warranty'] as String).trim();
      final warranty = warrantyText.isEmpty ? null : parseShortDate(warrantyText);
      if (warrantyText.isNotEmpty && warranty == null) return 'Enter the warranty date like "Mar 5, 2027".';
      final facility = v['facility'] as String;
      maint.saveEquipment(
        app,
        existing: item,
        name: name,
        category: v['category'] as String,
        location: (v['location'] as String).trim(),
        status: v['status'] as String,
        facility: facility == 'None' ? '' : facility,
        closes: facility != 'None' && v['closes'] == 'Close the facility to booking',
        vendor: (v['vendor'] as String).trim(),
        warranty: warranty,
      );
      return null;
    },
  );
}

/// Popup to add or edit a maintenance staff member.
void showStaffSheet(BuildContext context, {StaffMember? person}) {
  showFormSheet(
    context,
    title: person == null ? 'Add staff member' : 'Edit staff member',
    fields: [
      FieldSpec('name', 'Name', initial: person?.name ?? ''),
      FieldSpec('role', 'Role', hint: 'e.g. Plumber', initial: person?.role ?? ''),
      FieldSpec('phone', 'Phone', type: TextInputType.phone, initial: person?.phone ?? ''),
    ],
    submit: 'Save staff member',
    onSubmit: (v) {
      final name = (v['name'] as String).trim();
      if (name.isEmpty) return 'Enter the name.';
      maint.saveStaff(app, existing: person, name: name, role: (v['role'] as String).trim(), phone: (v['phone'] as String).trim());
      return null;
    },
  );
}

/// Reads a peso amount. Returns null when the text is not a number; an empty text means 0.
num? _parseCost(String raw) {
  final t = raw.trim().replaceAll(',', '');
  if (t.isEmpty) return 0;
  final n = double.tryParse(t);
  return (n == null || n < 0) ? null : n;
}

/// Popup for Mark done on a routine task, with an optional cost that goes to Expenses.
void showDoneSheet(BuildContext context, MTask t) {
  showFormSheet(
    context,
    title: 'Mark done',
    subtitle: t.title,
    fields: const [FieldSpec('cost', 'Cost of the service (₱, optional)', type: TextInputType.number)],
    submit: 'Mark done',
    onSubmit: (v) {
      final cost = _parseCost(v['cost'] as String);
      if (cost == null) return 'Enter the cost as a number.';
      maint.markDone(t, app, cost: cost);
      return null;
    },
  );
}

/// Popup for Mark resolved on a grievance: what was done and what it cost.
void showResolveSheet(BuildContext context, Grievance g) {
  showFormSheet(
    context,
    title: 'Mark resolved',
    subtitle: g.title,
    fields: const [
      FieldSpec('cost', 'Cost of the repair (₱, optional)', type: TextInputType.number),
      FieldSpec('note', 'What was done', hint: 'Short note for the record', lines: 3),
    ],
    submit: 'Mark resolved',
    onSubmit: (v) {
      final cost = _parseCost(v['cost'] as String);
      if (cost == null) return 'Enter the cost as a number.';
      maint.resolve(app, g, note: (v['note'] as String).trim(), cost: cost);
      return null;
    },
  );
}
