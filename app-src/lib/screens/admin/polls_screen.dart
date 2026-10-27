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
  int _tab = 0; // 0 open, 1 closed, 2 categories
  String _cat = 'all';

  Widget _categories(BuildContext context) {
    final cats = app.pollCategoryChoices;
    return RCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('Poll categories', style: hd(18))),
          FilledButton.tonalIcon(onPressed: () => showCategoryManager(context), icon: const Icon(Icons.label_outline_rounded, size: 18), label: const Text('Manage')),
        ]),
        const SizedBox(height: 2),
        Text('Residents can filter the polls by category.', style: TextStyle(color: muted(context), fontSize: 12.5)),
        const SizedBox(height: 8),
        for (final c in cats)
          Builder(builder: (context) {
            final n = app.polls.where((p) => p.category == c).length;
            final o = app.polls.where((p) => p.category == c && p.open).length;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(c, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('$n poll${n == 1 ? '' : 's'}${o > 0 ? ' · $o open' : ''}'),
              trailing: TextButton(
                onPressed: () => setState(() {
                  _cat = c;
                  _tab = 0;
                }),
                child: const Text('View polls'),
              ),
            );
          }),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final open = app.polls.where((p) => p.open).length;
        final closed = app.polls.length - open;
        final shown = app.polls.where((p) => (_tab == 0) == p.open && (_cat == 'all' || p.category == _cat)).toList();
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
              ],
            ),
            SubTabs(
              items: [SubTabItem('Open', count: open, hot: true), SubTabItem('Closed', count: closed), SubTabItem('Categories', count: app.pollCategoryChoices.length)],
              index: _tab,
              onChanged: (i) => setState(() => _tab = i),
            ),
            if (_tab == 2)
              _categories(context)
            else ...[
              PollCategoryFilter(polls: app.polls, value: _cat, onChanged: (v) => setState(() => _cat = v)),
              if (shown.isEmpty) EmptyBox(_tab == 0 ? 'No open polls. Tap New poll to publish one.' : 'No closed polls yet.', icon: Icons.how_to_vote_outlined),
              PollGrid(shown, (p) => PollCard(p, admin: true, key: ValueKey(p.id))),
            ],
          ],
        );
      },
    );
  }
}
