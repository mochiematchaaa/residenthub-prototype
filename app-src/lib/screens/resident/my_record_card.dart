// RESIDENT: "My household record". What the office keeps on file for the unit. The office edits it and it shows up here.

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../widgets/widgets.dart';

class MyRecordCard extends StatelessWidget {
  const MyRecordCard({super.key});

  Widget _cell(BuildContext context, String k, String v, {String empty = 'Not on file'}) {
    final has = v.trim().isNotEmpty;
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(k.toUpperCase(), style: TextStyle(color: muted(context), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.7)),
          const SizedBox(height: 2),
          Text(has ? v : empty, style: TextStyle(fontWeight: has ? FontWeight.w700 : FontWeight.w500, fontSize: 13, color: has ? null : muted(context), height: 1.3)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = app.myUnitRec;
    if (u == null) return const SizedBox.shrink();
    final upd = u.profileUpdated > 0 ? shortDate(DateTime.fromMillisecondsSinceEpoch(u.profileUpdated)) : '';
    final emer = [u.emergencyName, if (u.emergencyRelation.isNotEmpty) '(${u.emergencyRelation})', u.emergencyPhone].where((x) => x.isNotEmpty).join(' ');
    final slot = app.slotOf(app.myUnit);
    final name = u.name == '—' ? (app.me?.name ?? '') : u.name;
    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const IconBadge(Icons.badge_outlined, accent: true),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('My household record', style: hd(17)),
                Text(upd.isEmpty ? 'The office keeps these details on file' : 'Updated by the office on $upd', style: TextStyle(color: muted(context), fontSize: 12)),
              ]),
            ),
          ]),
          if (u.noteResident.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: toneOf(context, Tone.warn).bg, borderRadius: BorderRadius.circular(12)),
              child: Text(u.noteResident, style: TextStyle(color: toneOf(context, Tone.warn).fg, fontSize: 13)),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(spacing: 14, runSpacing: 14, children: [
            _cell(context, 'Name', name),
            _cell(context, 'Occupancy', u.type),
            _cell(context, 'Mobile', u.contact == '—' ? '' : u.contact),
            _cell(context, 'Email', u.email.isNotEmpty ? u.email : (app.me?.email ?? '')),
            _cell(context, 'Moved in', u.moveIn.isEmpty ? '' : isoShort(u.moveIn)),
            _cell(context, 'People living here', u.residents > 0 ? '${u.residents}' : ''),
            _cell(context, 'Household members', u.members),
            _cell(context, 'Pets', u.pets, empty: 'None on file'),
            _cell(context, 'Emergency contact', emer),
            _cell(context, 'Vehicles', u.vehicles, empty: 'None on file'),
            _cell(context, 'Floor area', u.area > 0 ? '${u.area} sqm' : ''),
            _cell(context, 'Parking slot', slot == null ? '' : '${slot.id} · ${slot.size}', empty: 'None'),
          ]),
          const SizedBox(height: 12),
          Text('Something is wrong or out of date? Tell the office and they will update it here.', style: TextStyle(color: muted(context), fontSize: 12.5)),
        ],
      ),
    );
  }
}
