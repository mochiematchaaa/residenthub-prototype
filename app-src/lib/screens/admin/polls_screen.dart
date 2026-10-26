// ADMIN page: Polls and elections.

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../widgets/widgets.dart';
import '../shared/poll_widgets.dart';
import 'poll_builder_screen.dart';
import 'poll_categories.dart';

/// Administrator: publish polls and elections, see the results and who voted, export to Excel, close or delete them.
class AdminPolls extends StatefulWidget {
  const AdminPolls({super.key});

  @override
  State<AdminPolls> createState() => _AdminPollsState();
}

class _AdminPollsState extends State<AdminPolls> {
  String _filter = 'open';
  String _cat = 'all';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final open = app.polls.where((p) => p.open).length;
        final closed = app.polls.length - open;
        final labels = <String, String>{
          'open': 'Open ($open)',
          'closed': 'Closed ($closed)',
          'all': 'All (${app.polls.length})',
        };
        final shown = app.polls
            .where((p) => (_filter == 'all' || (_filter == 'open') == p.open) && (_cat == 'all' || p.category == _cat))
            .toList();
        final ballots = app.polls.fold<int>(0, (s, p) => s + p.ballots);
        return SubPage(
          title: 'Polls & elections',
          subtitle: 'Ask residents what they think, run elections and see the results as votes come in.',
          children: [
            PastelCard(
              color: Pastel.sky,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: StatsRow([
                ['Open', '$open'],
                ['Closed', '$closed'],
                ['Ballots', '$ballots'],
              ]),
            ),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(onPressed: () => go(context, const PollBuilder(kind: 'poll')), icon: const Icon(Icons.add_rounded), label: const Text('New poll')),
                FilledButton.tonalIcon(onPressed: () => go(context, const PollBuilder(kind: 'election')), icon: const Icon(Icons.how_to_vote_outlined), label: const Text('New election')),
                OutlinedButton.icon(onPressed: () => showCategoryManager(context), icon: const Icon(Icons.label_outline_rounded), label: const Text('Manage categories')),
              ],
            ),
            FilterRow(
              options: labels.values.toList(),
              selected: labels[_filter]!,
              onSelect: (v) => setState(() => _filter = labels.entries.firstWhere((e) => e.value == v).key),
            ),
            PollCategoryFilter(polls: app.polls, value: _cat, onChanged: (v) => setState(() => _cat = v)),
            if (shown.isEmpty) const EmptyBox('No polls here yet. Tap New poll to publish one.', icon: Icons.how_to_vote_outlined),
            PollGrid(shown, (p) => PollCard(p, admin: true, key: ValueKey(p.id))),
          ],
        );
      },
    );
  }
}
