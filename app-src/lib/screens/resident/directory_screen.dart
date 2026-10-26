// RESIDENT page: Who to call and house rules.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/core.dart';
import '../../widgets/widgets.dart';

/// Resident: who to call, house rules and common questions.
class ResDirectory extends StatelessWidget {
  const ResDirectory({super.key});

  @override
  Widget build(BuildContext context) {
    const colors = [Pastel.butter, Pastel.mint, Pastel.peach, Pastel.coral];
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) => SubPage(
      title: 'Directory',
      subtitle: 'Who to call, house rules, and answers to common questions.',
      children: [
        DashSection(
          title: 'Who to call',
          hint: 'Local numbers are dialled from the building intercom. Tap a card to copy the number.',
          child: Column(
            children: [
              if (directoryContacts.isEmpty) const EmptyBox('The office has not added any contacts yet.', icon: Icons.call_outlined),
              for (var i = 0; i < directoryContacts.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: PastelCard(
                    color: colors[i % colors.length],
                    padding: const EdgeInsets.all(16),
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: directoryContacts[i].tel));
                      if (context.mounted) msg(context, '${directoryContacts[i].tel} copied.');
                    },
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(directoryContacts[i].name, style: hd(16)),
                              const SizedBox(height: 3),
                              Text(directoryContacts[i].note, style: const TextStyle(color: inkSoft, fontSize: 12.5, height: 1.3)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(directoryContacts[i].tel, style: hd(16)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        DashSection(
          title: 'House rules',
          child: RCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (houseRules.isEmpty) Text('The office has not posted any house rules yet.', style: TextStyle(color: muted(context), fontSize: 13)),
                for (var i = 0; i < houseRules.length; i++)
                  Padding(
                    padding: EdgeInsets.only(top: i == 0 ? 0 : 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(houseRules[i][0], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                        const SizedBox(height: 2),
                        Text(houseRules[i][1], style: TextStyle(color: muted(context), fontSize: 13, height: 1.4)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        DashSection(
          title: 'Questions we hear a lot',
          child: RCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final f in directoryFaq)
                  ExpansionTile(
                    shape: const Border(),
                    collapsedShape: const Border(),
                    title: Text(f[0], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    children: [Text(f[1], style: TextStyle(color: muted(context), fontSize: 13, height: 1.45))],
                  ),
              ],
            ),
          ),
        ),
      ],
    ));
  }
}
