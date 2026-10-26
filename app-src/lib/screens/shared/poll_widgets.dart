// Poll and election pieces used by both the administrator and the resident pages:
// the poll card, the ballot, the result bars, the "who voted" list and the category filter.

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../core/rich_text.dart';
import '../../services/poll_export.dart';
import '../../widgets/widgets.dart';
import 'document_viewer_screen.dart';

const _barColors = [Color(0xFF7873D9), Color(0xFFF2B04C), Color(0xFFE88A9E), Color(0xFF5BC2A8), Color(0xFF6FA8E8)];

String _plural(int n, String one, [String? many]) => '$n ${n == 1 ? one : (many ?? '${one}s')}';

/// The little labels on a poll card: its kind and its category.
class PollChips extends StatelessWidget {
  final Poll poll;
  const PollChips(this.poll, {super.key});

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          Pill(poll.isElection ? 'Election' : 'Poll', tone: poll.isElection ? Tone.warn : Tone.info),
          Pill(poll.category),
        ],
      );
}

/// Lays the poll cards out in a grid: one column on a phone, two on a tablet. Polls with many questions use the full width.
class PollGrid extends StatelessWidget {
  final List<Poll> polls;
  final Widget Function(Poll) item;
  const PollGrid(this.polls, this.item, {super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final two = c.maxWidth >= 720;
      if (!two) return Column(children: [for (final p in polls) item(p)]);
      final half = (c.maxWidth - 12) / 2;
      return Wrap(
        spacing: 12,
        runSpacing: 0,
        children: [
          for (final p in polls) SizedBox(width: p.questions.length > 1 ? c.maxWidth : half, child: item(p)),
        ],
      );
    });
  }
}

/// "All categories" / one category, for the list of polls.
class PollCategoryFilter extends StatelessWidget {
  final List<Poll> polls;
  final String value;
  final ValueChanged<String> onChanged;
  const PollCategoryFilter({super.key, required this.polls, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final used = [for (final c in app.pollCategoryChoices) if (polls.any((p) => p.category == c)) c];
    if (used.length < 2) return const SizedBox.shrink();
    final cur = value == 'all' || used.contains(value) ? value : 'all';
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text('Category', style: TextStyle(color: muted(context), fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: cur,
                items: [
                  DropdownMenuItem(value: 'all', child: Text('All categories (${polls.length})')),
                  for (final c in used) DropdownMenuItem(value: c, child: Text('$c (${polls.where((p) => p.category == c).length})')),
                ],
                onChanged: (v) => onChanged(v ?? 'all'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- results

/// Result bars for every question of a poll. [mine] marks the answers of the signed-in unit; [admin] also shows written answers.
class PollResults extends StatelessWidget {
  final Poll poll;
  final PollBallot? mine;
  final bool admin;
  const PollResults(this.poll, {super.key, this.mine, this.admin = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < poll.questions.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          _head(context, i),
          const SizedBox(height: 8),
          _body(context, poll.questions[i]),
        ],
      ],
    );
  }

  Widget _head(BuildContext context, int i) {
    final q = poll.questions[i];
    if (poll.legacy) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!poll.isElection) Padding(padding: const EdgeInsets.only(right: 6), child: Text('${i + 1}.', style: const TextStyle(fontWeight: FontWeight.w800))),
        Expanded(child: RichView(q.html, fallback: q.text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.35))),
      ],
    );
  }

  Widget _bar(BuildContext context, String label, int votes, double frac, int color, {bool mark = false, String chip = ''}) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: label + (mark ? ' · your vote' : ''), style: TextStyle(fontWeight: mark ? FontWeight.w800 : FontWeight.w600, fontSize: 13.5)),
                  if (chip.isNotEmpty) WidgetSpan(alignment: PlaceholderAlignment.middle, child: Padding(padding: const EdgeInsets.only(left: 6), child: Pill(chip, tone: chip == 'Tie' ? Tone.warn : Tone.good))),
                ])),
              ),
              const SizedBox(width: 8),
              Text(_plural(votes, 'vote'), style: TextStyle(color: muted(context), fontSize: 12)),
              const SizedBox(width: 8),
              Text('${(frac * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: frac),
              duration: const Duration(milliseconds: 650),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => LinearProgressIndicator(value: v, minHeight: 8, color: _barColors[color % _barColors.length], backgroundColor: cs.outlineVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, PollQuestion q) {
    final picked = <int>[];
    final a = mine?.answers[q.id];
    if (a is List) {
      for (final x in a) {
        if (x is num) picked.add(x.toInt());
      }
    } else if (a is num) {
      picked.add(a.toInt());
    }
    if (q.isChoice) {
      final status = app.electedStatus(poll, q);
      return Column(
        children: [
          for (var i = 0; i < q.options.length; i++)
            _bar(context, q.options[i], q.counts[i], q.n == 0 ? 0 : q.counts[i] / q.n, i, mark: picked.contains(i), chip: status[i]),
        ],
      );
    }
    if (q.type == 'rating') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text.rich(TextSpan(children: [
              TextSpan(text: q.n == 0 ? '—' : (q.ratingSum / q.n).toStringAsFixed(1), style: hd(22)),
              TextSpan(text: ' out of 5 · ${_plural(q.n, 'response')}${picked.isNotEmpty ? ' · you gave ${picked.first}' : ''}', style: TextStyle(color: muted(context), fontSize: 12.5)),
            ])),
          ),
          for (var s = 5; s >= 1; s--)
            _bar(context, _plural(s, 'star'), q.stars[s - 1], q.n == 0 ? 0 : q.stars[s - 1] / q.n, 5 - s, mark: picked.isNotEmpty && picked.first == s),
        ],
      );
    }
    if (!admin) {
      return Text('${_plural(q.n, 'written answer')} received. Only the office reads them.', style: TextStyle(color: muted(context), fontSize: 12.5));
    }
    if (q.written.isEmpty) return Text('No written answers yet.', style: TextStyle(color: muted(context), fontSize: 12.5));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final w in q.written.take(40))
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Theme.of(context).colorScheme.outlineVariant.withAlpha(90)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(w.text, style: const TextStyle(fontSize: 13.5, height: 1.35)),
                const SizedBox(height: 2),
                Text(w.unit, style: TextStyle(color: muted(context), fontSize: 11.5)),
              ],
            ),
          ),
        if (q.written.length > 40) Text('+ ${q.written.length - 40} more in the Excel file.', style: TextStyle(color: muted(context), fontSize: 12)),
      ],
    );
  }
}

// ---------------------------------------------------------------- ballot

/// The form a resident fills in. One ballot per unit; it cannot be changed after sending.
class PollBallotForm extends StatefulWidget {
  final Poll poll;
  const PollBallotForm(this.poll, {super.key});

  @override
  State<PollBallotForm> createState() => _PollBallotFormState();
}

class _PollBallotFormState extends State<PollBallotForm> {
  final Map<String, dynamic> _a = {};
  final Map<String, TextEditingController> _t = {};

  @override
  void dispose() {
    for (final c in _t.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _send() async {
    final p = widget.poll;
    final answers = Map<String, dynamic>.from(_a);
    for (final q in p.questions) {
      if (q.isWritten) {
        final t = _t[q.id]?.text.trim() ?? '';
        if (t.isNotEmpty) answers[q.id] = t;
      }
    }
    if (p.isElection) {
      final ok = await confirmDialog(context, 'Submit your ballot?', 'Each unit has one ballot. It is secret and cannot be changed after you submit.', confirm: 'Submit ballot');
      if (!ok || !mounted) return;
    }
    final err = app.castVote(p, answers);
    if (!mounted) return;
    msg(context, err ?? (p.isElection ? 'Your ballot was recorded. Thank you for voting!' : 'Your answers were recorded. Thank you!'));
  }

  Widget _option(BuildContext context, bool on, bool radio, String text, VoidCallback onTap) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: on ? lavDeep : cs.outlineVariant, width: on ? 2 : 1),
            color: on ? lav.withAlpha(50) : null,
          ),
          child: Row(
            children: [
              Icon(
                radio ? (on ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded) : (on ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded),
                color: on ? lavDeep : muted(context),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _question(BuildContext context, int i, PollQuestion q) {
    final p = widget.poll;
    String hint = '';
    Widget body;
    if (q.type == 'choice') {
      if (p.isElection) hint = 'Choose one candidate. Leave it blank to abstain.';
      body = Column(children: [
        for (var k = 0; k < q.options.length; k++)
          _option(context, _a[q.id] == k, true, q.options[k], () => setState(() {
                if (_a[q.id] == k) {
                  _a.remove(q.id);
                } else {
                  _a[q.id] = k;
                }
              })),
      ]);
    } else if (q.type == 'multi') {
      hint = q.max > 0 ? 'Choose up to ${q.max}.${p.isElection ? ' Leave it blank to abstain.' : ''}' : 'Choose all that apply.';
      final cur = <int>[...((_a[q.id] as List?)?.cast<int>() ?? const <int>[])];
      body = Column(children: [
        for (var k = 0; k < q.options.length; k++)
          _option(context, cur.contains(k), false, q.options[k], () {
            final next = [...cur];
            if (next.contains(k)) {
              next.remove(k);
            } else {
              if (q.max > 0 && next.length >= q.max) {
                msg(context, 'You can choose up to ${q.max}.');
                return;
              }
              next.add(k);
            }
            setState(() {
              if (next.isEmpty) {
                _a.remove(q.id);
              } else {
                _a[q.id] = next;
              }
            });
          }),
      ]);
    } else if (q.type == 'rating') {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var s = 1; s <= 5; s++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => setState(() => _a[q.id] = s),
                      child: Container(
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: _a[q.id] == s ? lavDeep : null,
                          border: Border.all(color: _a[q.id] == s ? lavDeep : Theme.of(context).colorScheme.outlineVariant),
                        ),
                        child: Text('$s', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: _a[q.id] == s ? Colors.white : null)),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Not satisfied', style: TextStyle(color: muted(context), fontSize: 11.5)),
            Text('Very satisfied', style: TextStyle(color: muted(context), fontSize: 11.5)),
          ]),
        ],
      );
    } else {
      final c = _t.putIfAbsent(q.id, () => TextEditingController());
      body = TextField(
        controller: c,
        maxLength: q.type == 'para' ? 1000 : 200,
        minLines: q.type == 'para' ? 3 : 1,
        maxLines: q.type == 'para' ? 6 : 1,
        decoration: const InputDecoration(hintText: 'Your answer'),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!p.legacy)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!p.isElection) Padding(padding: const EdgeInsets.only(right: 6), child: Text('${i + 1}.', style: const TextStyle(fontWeight: FontWeight.w800))),
                  Expanded(
                    child: Text.rich(TextSpan(children: [
                      WidgetSpan(child: RichView(q.html, fallback: q.text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.35))),
                      if (q.required) const TextSpan(text: ' *', style: TextStyle(color: danger, fontWeight: FontWeight.w800)),
                    ])),
                  ),
                ],
              ),
            ),
          if (hint.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(hint, style: TextStyle(color: muted(context), fontSize: 12.5))),
          body,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.poll;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < p.questions.length; i++) _question(context, i, p.questions[i]),
        SizedBox(
          width: double.infinity,
          child: FilledButton(onPressed: _send, child: Text(p.isElection ? 'Submit my ballot' : 'Submit my answers')),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- who voted

/// The units that voted (and, for a normal poll, their answers) and the units that have not voted yet.
/// In an election the choices stay secret.
class PollVoters extends StatefulWidget {
  final Poll poll;
  const PollVoters(this.poll, {super.key});

  @override
  State<PollVoters> createState() => _PollVotersState();
}

class _PollVotersState extends State<PollVoters> {
  bool _voted = true;

  String _who(String unit) {
    final u = app.units.where((u) => u.unit == unit).firstOrNull;
    return u == null || u.name == '—' ? '' : u.name;
  }

  String _when(String iso) {
    final d = DateTime.tryParse(iso);
    return d == null ? '' : shortDate(d.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.poll;
    final ballots = app.ballotsOf(p);
    final byUnit = {for (final b in ballots) b.unit: b};
    final not = [for (final u in app.units) if (!byUnit.containsKey(u.unit)) u];
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: Theme.of(context).colorScheme.outlineVariant)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(label: Text('Voted (${ballots.length})'), selected: _voted, onSelected: (_) => setState(() => _voted = true)),
              ChoiceChip(label: Text('Not yet voted (${not.length})'), selected: !_voted, onSelected: (_) => setState(() => _voted = false)),
            ],
          ),
          if (p.isElection)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('This is a secret ballot: you can see who voted, not who they voted for.', style: TextStyle(color: muted(context), fontSize: 12.5)),
            ),
          const SizedBox(height: 8),
          if (_voted && ballots.isEmpty) Text('Nobody has voted yet.', style: TextStyle(color: muted(context))),
          if (!_voted && not.isEmpty) Text('Every unit has voted.', style: TextStyle(color: muted(context))),
          if (_voted)
            for (final b in ballots)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text('${b.unit}${_who(b.unit).isEmpty ? '' : ' · ${_who(b.unit)}'}', style: const TextStyle(fontWeight: FontWeight.w700))),
                        Text(_when(b.at), style: TextStyle(color: muted(context), fontSize: 12)),
                      ],
                    ),
                    if (!p.isElection)
                      for (var i = 0; i < p.questions.length; i++)
                        if (answerText(p.questions[i], b.answers[p.questions[i].id]).isNotEmpty)
                          Text(
                            '${p.questions.length == 1 ? '' : '${i + 1}. '}${answerText(p.questions[i], b.answers[p.questions[i].id])}',
                            style: TextStyle(color: muted(context), fontSize: 12.5),
                          ),
                  ],
                ),
              )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final u in not) Pill(u.unit)],
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- the card

/// One poll or election. Residents fill in the ballot once per unit; the administrator sees the results,
/// who voted, and can close, reopen, export or delete it.
class PollCard extends StatefulWidget {
  final Poll poll;
  final bool admin;
  const PollCard(this.poll, {super.key, this.admin = false});

  @override
  State<PollCard> createState() => _PollCardState();
}

class _PollCardState extends State<PollCard> {
  bool _voters = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.poll;
    final mine = widget.admin ? null : app.myBallot(p.id);
    final hidden = p.isElection && p.resultsHidden;
    final canSee = widget.admin ? !hidden : (!p.open || (mine != null && p.showResults != 'closed'));
    final units = app.units.length;
    final turnout = units == 0 ? 0.0 : (p.ballots / units).clamp(0, 1).toDouble();
    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: PollChips(p)),
              const SizedBox(width: 8),
              Pill(p.open ? 'Open' : 'Closed', tone: p.open ? Tone.good : Tone.info),
            ],
          ),
          const SizedBox(height: 10),
          RichView(p.titleHtml, fallback: p.question, style: hd(17).copyWith(height: 1.25)),
          if (p.descHtml.isNotEmpty) ...[
            const SizedBox(height: 6),
            RichView(p.descHtml, style: TextStyle(fontSize: 13.5, height: 1.4, color: muted(context))),
          ],
          const SizedBox(height: 6),
          Text(
            '${p.open ? 'Closes' : 'Closed'} ${p.closes}${p.legacy ? '' : ' · ${p.questions.length} ${p.isElection ? 'position' : 'question'}${p.questions.length == 1 ? '' : 's'}'}${!widget.admin && p.isElection ? ' · secret ballot, one ballot per unit' : ''}',
            style: TextStyle(color: muted(context), fontSize: 12),
          ),
          const SizedBox(height: 14),
          if (!widget.admin && p.open && mine == null)
            PollBallotForm(p)
          else if (canSee) ...[
            PollResults(p, mine: mine, admin: widget.admin),
            if (!widget.admin)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text('${_plural(p.ballots, p.isElection ? 'ballot' : 'response')} so far${mine != null ? ' · thank you for voting' : ''}', style: TextStyle(color: muted(context), fontSize: 12)),
              ),
          ] else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: lav.withAlpha(40)),
              child: Text(
                widget.admin
                    ? 'Ballots are secret. The results stay hidden until the election closes, so nobody can see who is ahead.'
                    : 'Your ballot was recorded. The results are shown when voting closes on ${p.closes}.',
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
            ),
          if (widget.admin) ...[
            if (units > 0) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: Text('Units that voted', style: TextStyle(color: muted(context), fontSize: 12.5, fontWeight: FontWeight.w600))),
                  Text('${p.ballots} of $units', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                ],
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(value: turnout, minHeight: 8, color: const Color(0xFF5BC2A8), backgroundColor: Theme.of(context).colorScheme.outlineVariant),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(onPressed: () => setState(() => _voters = !_voters), child: Text(_voters ? 'Hide voters' : 'Who voted (${p.ballots})')),
                OutlinedButton(onPressed: () => app.togglePoll(p), child: Text(p.open ? (p.isElection ? 'Close election' : 'Close poll') : 'Reopen')),
                OutlinedButton.icon(
                  onPressed: hidden ? null : () => runSave(context, 'Excel file', () => exportPoll(p)),
                  icon: const Icon(Icons.table_chart_outlined, size: 18),
                  label: const Text('Export to Excel'),
                ),
                TextButton(
                  onPressed: () async {
                    final ok = await confirmDialog(context, 'Delete this poll?', 'The poll and its results will be removed.', confirm: 'Delete', destructive: true);
                    if (ok) app.deletePoll(p);
                  },
                  child: const Text('Delete', style: TextStyle(color: danger)),
                ),
              ],
            ),
            if (_voters) PollVoters(p),
          ],
        ],
      ),
    );
  }
}
