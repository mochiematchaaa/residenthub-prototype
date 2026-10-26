// The poll card with result bars, used by both admin and resident.

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../services/doc_files.dart';
import '../../widgets/widgets.dart';
import 'document_viewer_screen.dart';

/// One poll. Residents pick an option and vote once per unit; the administrator
/// sees the results and can close, reopen, export or delete the poll.
class PollCard extends StatefulWidget {
  final Poll poll;
  final bool admin;
  const PollCard(this.poll, {super.key, this.admin = false});

  @override
  State<PollCard> createState() => _PollCardState();
}

class _PollCardState extends State<PollCard> {
  int? _picked;

  List<DocBlock> _blocks(Poll p) => [
        DocBlock.h1(p.question),
        DocBlock.p('${p.open ? 'Open, closes' : 'Closed'} ${p.closes}'),
        DocBlock.table([
          const ['Option', 'Votes'],
          for (final o in p.options) [o.text, '${o.votes}'],
        ]),
        DocBlock.p('${p.total} votes in total'),
      ];

  @override
  Widget build(BuildContext context) {
    final p = widget.poll;
    final mine = widget.admin ? null : app.myVote(p.id);
    final showResults = widget.admin || !p.open || mine != null;
    final total = p.total == 0 ? 1 : p.total;
    final cs = Theme.of(context).colorScheme;

    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.question, style: hd(16)),
                    const SizedBox(height: 4),
                    Text('${p.open ? 'Closes' : 'Closed'} ${p.closes}', style: TextStyle(color: muted(context), fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Pill(p.open ? 'Open' : 'Closed', tone: p.open ? Tone.good : Tone.info),
            ],
          ),
          const SizedBox(height: 14),
          if (showResults) ...[
            for (var i = 0; i < p.options.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${p.options[i].text}${mine == i ? ' · your vote' : ''}',
                            style: TextStyle(fontWeight: mine == i ? FontWeight.w800 : FontWeight.w600, fontSize: 13.5),
                          ),
                        ),
                        Text('${(p.options[i].votes / total * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: p.total == 0 ? 0 : p.options[i].votes / p.total),
                        duration: const Duration(milliseconds: 650),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, __) => LinearProgressIndicator(
                          value: v,
                          minHeight: 8,
                          color: mine == i ? lavDeep : lav,
                          backgroundColor: cs.outlineVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ] else ...[
            for (var i = 0; i < p.options.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => setState(() => _picked = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _picked == i ? lavDeep : cs.outlineVariant, width: _picked == i ? 2 : 1),
                      color: _picked == i ? lav.withAlpha(50) : null,
                    ),
                    child: Row(
                      children: [
                        Icon(_picked == i ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                            color: _picked == i ? lavDeep : muted(context), size: 20),
                        const SizedBox(width: 10),
                        Expanded(child: Text(p.options[i].text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _picked == null
                    ? null
                    : () {
                        final err = app.castVote(p, _picked!);
                        msg(context, err ?? 'Your vote was recorded. Thank you!');
                      },
                child: const Text('Submit my vote'),
              ),
            ),
          ],
          if (showResults)
            Text(
              '${p.total} vote${p.total == 1 ? '' : 's'} so far${mine != null ? ' · thank you for voting' : ''}',
              style: TextStyle(color: muted(context), fontSize: 12),
            ),
          if (widget.admin) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(onPressed: () => app.togglePoll(p), child: Text(p.open ? 'Close poll' : 'Reopen poll')),
                OutlinedButton(
                  onPressed: () => runSave(context, 'Excel file', () => exportXlsx('Poll results', _blocks(p))),
                  child: const Text('Export results'),
                ),
                TextButton(
                  onPressed: () async {
                    final ok = await confirmDialog(context, 'Delete poll?', 'The poll and its results will be removed.', confirm: 'Delete', destructive: true);
                    if (ok) app.deletePoll(p);
                  },
                  child: const Text('Delete', style: TextStyle(color: danger)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
