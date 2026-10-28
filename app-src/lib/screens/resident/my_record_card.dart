// RESIDENT: "My household record". What the office keeps on file for the unit, drawn like the office sees it.
// The resident can edit the household, emergency contact and vehicles; the office keeps the rest.

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../widgets/widgets.dart';
import '../shared/record_sheet.dart';

class MyRecordCard extends StatelessWidget {
  const MyRecordCard({super.key});

  void _edit(BuildContext context, Unit u) {
    showFormSheet(
      context,
      title: 'Edit my details',
      subtitle: 'The office sees what you save. Your name, mobile number and unit are kept by the office, so ask them if one of those is wrong.',
      fields: [
        FieldSpec('members', 'People living here (one per line, e.g. Ana Reyes, spouse)', hint: 'The number of people is counted from this list.', lines: 4, initial: u.members),
        FieldSpec('pets', 'Pets', hint: 'e.g. 1 dog', initial: u.pets),
        FieldSpec('emergencyName', 'Emergency contact name', initial: u.emergencyName),
        FieldSpec('emergencyRelation', 'Relationship', hint: 'e.g. Sister', initial: u.emergencyRelation),
        FieldSpec('emergencyPhone', 'Emergency contact number', type: TextInputType.phone, initial: u.emergencyPhone),
        FieldSpec('vehicles', 'Vehicles', hint: 'One per line, e.g. Motorcycle · ABC 1234', lines: 3, initial: u.vehicles),
      ],
      submit: 'Save my details',
      onSubmit: (v) {
        app.saveMyRecord({for (final e in v.entries) e.key: (e.value ?? '').toString()});
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final u = app.myUnitRec;
        if (u == null) return const SizedBox.shrink();
        return RecordSheet(
          u: u,
          admin: false,
          email: app.me?.email ?? '',
          action: FilledButton.icon(onPressed: () => _edit(context, u), icon: const Icon(Icons.edit_outlined, size: 18), label: const Text('Edit my details')),
        );
      },
    );
  }
}
