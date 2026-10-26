// RESIDENT page: Polls, surveys and elections.

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../widgets/widgets.dart';
import '../shared/poll_widgets.dart';

/// Resident: open polls and elections, one ballot per unit.
class ResPolls extends StatefulWidget {
  const ResPolls({super.key});

  @override
  State<ResPolls> createState() => _ResPollsState();
}

class _ResPollsState extends State<ResPolls> {
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
        return SubPage(
          title: 'Polls & voting',
          subtitle: 'Have your say on community decisions. One ballot per unit.',
          children: [
            FilterRow(
              options: labels.values.toList(),
              selected: labels[_filter]!,
              onSelect: (v) => setState(() => _filter = labels.entries.firstWhere((e) => e.value == v).key),
            ),
            PollCategoryFilter(polls: app.polls, value: _cat, onChanged: (v) => setState(() => _cat = v)),
            if (shown.isEmpty) const EmptyBox('No polls here.', icon: Icons.how_to_vote_outlined),
            PollGrid(shown, (p) => PollCard(p, key: ValueKey(p.id))),
          ],
        );
      },
    );
  }
}
