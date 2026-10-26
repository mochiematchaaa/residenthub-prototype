// ADMIN page: Emergency contacts and house rules.

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../widgets/widgets.dart';
import '../shared/import_sheet.dart';

/// Administrator: the contact numbers and house rules every resident sees under Directory.
class AdminDirectory extends StatelessWidget {
  const AdminDirectory({super.key});

  void _contactForm(BuildContext context, {int? index}) {
    final cur = index == null ? null : directoryContacts[index];
    showFormSheet(
      context,
      title: cur == null ? 'Add a contact' : 'Edit contact',
      fields: [
        FieldSpec('name', 'Name', hint: 'e.g. Security desk', initial: cur?.name ?? ''),
        FieldSpec('note', 'Details (optional)', hint: 'e.g. Open 24 hours · Gate and lobby', initial: cur?.note ?? ''),
        FieldSpec('tel', 'Number', hint: 'e.g. Local 101 or 0917 555 0000', initial: cur?.tel ?? ''),
      ],
      submit: 'Save',
      onSubmit: (v) {
        final name = (v['name'] as String).trim();
        final tel = (v['tel'] as String).trim();
        if (name.isEmpty || tel.isEmpty) return 'Enter a name and a number.';
        final list = [...directoryContacts];
        final item = ContactInfo(name, (v['note'] as String).trim(), tel);
        if (index == null) {
          list.add(item);
        } else {
          list[index] = item;
        }
        app.setDirectory(list, [...houseRules]);
        return null;
      },
    );
  }

  void _ruleForm(BuildContext context, {int? index}) {
    final cur = index == null ? null : houseRules[index];
    showFormSheet(
      context,
      title: cur == null ? 'Add a house rule' : 'Edit house rule',
      fields: [
        FieldSpec('title', 'Title', hint: 'e.g. Quiet hours', initial: cur?[0] ?? ''),
        FieldSpec('text', 'Rule', lines: 3, hint: 'e.g. Keep noise low from 10:00 PM to 6:00 AM.', initial: cur?[1] ?? ''),
      ],
      submit: 'Save',
      onSubmit: (v) {
        final t = (v['title'] as String).trim();
        final x = (v['text'] as String).trim();
        if (t.isEmpty || x.isEmpty) return 'Enter a title and the rule.';
        final list = [...houseRules];
        if (index == null) {
          list.add([t, x]);
        } else {
          list[index] = [t, x];
        }
        app.setDirectory([...directoryContacts], list);
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) => SubPage(
        title: 'Directory and house rules',
        subtitle: 'What residents see under Directory: who to call, and the rules of the building.',
        children: [
          const ImportBar(['directory']),
          Row(children: [
            Expanded(child: Text('Contacts', style: hd(18))),
            TextButton.icon(onPressed: () => _contactForm(context), icon: const Icon(Icons.add_rounded), label: const Text('Add')),
          ]),
          if (directoryContacts.isEmpty) const EmptyBox('No contacts yet.', icon: Icons.call_outlined),
          for (var i = 0; i < directoryContacts.length; i++)
            RCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(directoryContacts[i].name, style: const TextStyle(fontWeight: FontWeight.w700)),
                        if (directoryContacts[i].note.isNotEmpty)
                          Text(directoryContacts[i].note, style: TextStyle(color: muted(context), fontSize: 12.5)),
                        Text(directoryContacts[i].tel, style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () => _contactForm(context, index: i), icon: const Icon(Icons.edit_outlined)),
                  IconButton(
                    onPressed: () {
                      final list = [...directoryContacts]..removeAt(i);
                      app.setDirectory(list, [...houseRules]);
                    },
                    icon: const Icon(Icons.delete_outline_rounded, color: danger),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: Text('House rules', style: hd(18))),
            TextButton.icon(onPressed: () => _ruleForm(context), icon: const Icon(Icons.add_rounded), label: const Text('Add')),
          ]),
          if (houseRules.isEmpty) const EmptyBox('No house rules yet.', icon: Icons.rule_rounded),
          for (var i = 0; i < houseRules.length; i++)
            RCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(houseRules[i][0], style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(houseRules[i][1], style: TextStyle(color: muted(context), fontSize: 12.5, height: 1.4)),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () => _ruleForm(context, index: i), icon: const Icon(Icons.edit_outlined)),
                  IconButton(
                    onPressed: () {
                      final list = [...houseRules]..removeAt(i);
                      app.setDirectory([...directoryContacts], list);
                    },
                    icon: const Icon(Icons.delete_outline_rounded, color: danger),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
