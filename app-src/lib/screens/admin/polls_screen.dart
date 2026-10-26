// ADMIN page: Polls.

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../widgets/widgets.dart';
import '../shared/poll_widgets.dart';

/// Administrator: publish polls, see the results, close or delete them.
class AdminPolls extends StatefulWidget {
  const AdminPolls({super.key});

  @override
  State<AdminPolls> createState() => _AdminPollsState();
}

class _AdminPollsState extends State<AdminPolls> {
  String _filter = 'all';

  void _newPoll(BuildContext context) {
    showFormSheet(
      context,
      title: 'New poll',
      subtitle: 'Residents vote once per unit. The poll stays open for 7 days.',
      fields: const [
        FieldSpec('q', 'Question', hint: 'e.g. Repaint the lobby this year?', lines: 2),
        FieldSpec('opts', 'Options', hint: 'One option per line (at least two)', lines: 4),
      ],
      submit: 'Publish poll',
      onSubmit: (v) => app.addPoll(v['q'] as String, v['opts'] as String),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final open = app.polls.where((p) => p.open).length;
        final closed = app.polls.length - open;
        final labels = <String, String>{
          'all': 'All (${app.polls.length})',
          'open': 'Open ($open)',
          'closed': 'Closed ($closed)',
        };
        final shown = app.polls.where((p) => _filter == 'all' || (_filter == 'open') == p.open).toList();
        final votes = app.polls.fold<int>(0, (s, p) => s + p.total);
        return SubPage(
          title: 'Polls & voting',
          subtitle: 'Ask residents what they think and see the results as votes come in.',
          fab: FloatingActionButton.extended(
            onPressed: () => _newPoll(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('New poll'),
          ),
          children: [
            PastelCard(
              color: Pastel.sky,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: StatsRow([
                ['Open', '$open'],
                ['Closed', '$closed'],
                ['Votes', '$votes'],
              ]),
            ),
            FilterRow(
              options: labels.values.toList(),
              selected: labels[_filter]!,
              onSelect: (v) => setState(() => _filter = labels.entries.firstWhere((e) => e.value == v).key),
            ),
            if (shown.isEmpty) const EmptyBox('No polls here yet. Tap New poll to publish one.', icon: Icons.how_to_vote_outlined),
            for (final p in shown) PollCard(p, admin: true, key: ValueKey(p.id)),
          ],
        );
      },
    );
  }
}
