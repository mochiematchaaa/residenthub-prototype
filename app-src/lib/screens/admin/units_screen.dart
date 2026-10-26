// ADMIN page: Units (list, add, edit, import, export).

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../widgets/widgets.dart';
import '../shared/import_sheet.dart';
import 'admin_screens.dart';

class AdminUnits extends StatefulWidget {
  const AdminUnits({super.key});

  @override
  State<AdminUnits> createState() => _AdminUnitsState();
}

class _AdminUnitsState extends State<AdminUnits> {
  static const filters = ['All units', 'Vacant', 'Overdue dues', 'Rented / business'];
  String filter = filters[0];
  String q = '';

  @override
  Widget build(BuildContext context) {
    final rows = app.units.where((u) {
      final okFilter = filter == filters[0] ||
          (filter == filters[1] && u.status == 'Vacant') ||
          (filter == filters[2] && app.unpaidCountFor(u.unit) > 0) ||
          (filter == filters[3] && const ['tenant', 'shortterm', 'business'].contains(u.usage));
      final s = q.trim().toLowerCase();
      return okFilter && (s.isEmpty || '${u.unit} ${u.name} ${u.contact}'.toLowerCase().contains(s));
    }).toList();

    return TabPage(
      title: 'Units & residents',
      subtitle: 'Maintain unit, occupancy and resident records.',
      children: [
        const ImportBar(['units']),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _unitForm(context),
            icon: const Icon(Icons.add_home_outlined),
            label: const Text('Add a unit'),
          ),
        ),
        TextField(
          onChanged: (v) => setState(() => q = v),
          decoration: const InputDecoration(hintText: 'Search unit, name or contact…', prefixIcon: Icon(Icons.search_rounded)),
        ),
        FilterRow(options: filters, selected: filter, onSelect: (v) => setState(() => filter = v)),
        Text('${rows.length} of ${app.units.length} units on record', style: TextStyle(color: muted(context), fontWeight: FontWeight.w600)),
        if (rows.isEmpty)
          EmptyBox(app.units.isEmpty ? 'No units yet. Tap "Add a unit" to start.' : 'No units match your search.',
              icon: app.units.isEmpty ? Icons.add_home_outlined : Icons.search_off_rounded),
        for (final u in rows)
          RCard(
            onTap: () => _unitSheet(context, u),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(color: u.status == 'Vacant' ? toneOf(context, Tone.warn).bg : ink, borderRadius: BorderRadius.circular(14)),
                  alignment: Alignment.center,
                  child: Text(u.unit.replaceFirst('Unit ', ''), style: TextStyle(fontWeight: FontWeight.w800, color: u.status == 'Vacant' ? toneOf(context, Tone.warn).fg : lav)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(u.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text('${u.type} · ${u.contact}', style: TextStyle(color: muted(context), fontSize: 12.5)),
                      const SizedBox(height: 6),
                      Pill(usageLabel(u.usage), tone: statusOf(u.usage).tone),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Pill(u.status, tone: u.status == 'Vacant' ? Tone.warn : Tone.good),
                    if (app.unpaidCountFor(u.unit) > 0) ...[
                      const SizedBox(height: 6),
                      Text('${app.unpaidCountFor(u.unit)} open charge${app.unpaidCountFor(u.unit) == 1 ? '' : 's'}', style: const TextStyle(color: danger, fontSize: 11.5, fontWeight: FontWeight.w700)),
                    ],
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _unitForm(BuildContext context, {Unit? edit}) {
    showFormSheet(
      context,
      title: edit == null ? 'Add a unit' : 'Edit ${edit.unit}',
      subtitle: edit == null ? 'The unit name links accounts, charges, bookings and parking together.' : null,
      fields: [
        if (edit == null) const FieldSpec('unit', 'Unit name', hint: 'e.g. Unit 12A'),
        FieldSpec('name', 'Household / owner name', hint: 'e.g. Reyes Household', initial: edit?.name == '—' ? '' : (edit?.name ?? '')),
        FieldSpec('contact', 'Contact number', type: TextInputType.phone, hint: 'e.g. 0917 555 0000', initial: edit?.contact == '—' ? '' : (edit?.contact ?? '')),
      ],
      choices: [ChoiceSpec('type', 'Occupancy', const ['Owner', 'Tenant'], edit?.type == 'Tenant' ? 'Tenant' : 'Owner')],
      submit: edit == null ? 'Add unit' : 'Save',
      onSubmit: (v) {
        if (edit == null) {
          return app.addUnit(v['unit'] as String, v['name'] as String, v['type'] as String, v['contact'] as String);
        }
        app.updateUnit(edit, v['name'] as String, v['type'] as String, v['contact'] as String);
        return null;
      },
    );
  }

  void _unitSheet(BuildContext context, Unit u) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(u.unit, style: hd(24)),
            Text(u.name, style: TextStyle(color: muted(context))),
            const SizedBox(height: 14),
            _kv(context, 'Occupancy', u.type),
            _kv(context, 'Status', u.status),
            _kv(context, 'Contact', u.contact),
            _kv(context, 'Open charges', app.unpaidCountFor(u.unit) == 0 ? 'None' : '${app.unpaidCountFor(u.unit)} · ${peso(app.balanceFor(u.unit))}'),
            _kv(context, 'Unit state', usageLabel(u.usage)),
            if (usageInfoRows(u.usage, u.usageInfo).isNotEmpty)
              for (final r in usageInfoRows(u.usage, u.usageInfo)) _kv(context, r[0], r[1])
            else if (u.statusNote.isNotEmpty)
              _kv(context, 'Note', u.statusNote),
            if (u.statusDate.isNotEmpty) _kv(context, 'Updated', u.statusDate),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  showAdminStatusSheet(context, u);
                },
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Update status'),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _unitForm(context, edit: u);
                    },
                    icon: const Icon(Icons.badge_outlined),
                    label: const Text('Edit details'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: danger),
                    onPressed: () async {
                      final nav = Navigator.of(ctx);
                      final ok = await confirmDialog(ctx, 'Remove ${u.unit}?', 'This removes the unit and its charges. Payments already recorded stay on file.', confirm: 'Remove', destructive: true);
                      if (!ok) return;
                      final err = app.removeUnit(u);
                      nav.pop();
                      if (err != null && context.mounted) msg(context, err);
                    },
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Remove'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


Widget _kv(BuildContext context, String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(k, style: TextStyle(color: muted(context), fontWeight: FontWeight.w600))),
          Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w700))),
        ],
      ),
    );
