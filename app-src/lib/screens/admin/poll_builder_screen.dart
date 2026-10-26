// ADMIN page: build a new poll (like a form) or an election.

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../widgets/widgets.dart';
import 'poll_categories.dart';

const _boardPositions = ['President', 'Vice President', 'Secretary', 'Treasurer', 'Auditor'];

/// One question or position being edited.
class _QDraft {
  final RtController text;
  String type;
  bool required;
  int max; // checkboxes: most choices (0 = no limit)
  int seats; // election: seats to fill
  final List<TextEditingController> opts;

  _QDraft({String html = '', this.type = 'choice', this.required = false, this.max = 0, this.seats = 1, List<String> options = const ['', '']})
      : text = RtController(html),
        opts = [for (final o in options) TextEditingController(text: o)];

  _QDraft copy() => _QDraft(html: text.toHtml(), type: type, required: required, max: max, seats: seats, options: [for (final o in opts) o.text]);

  void dispose() {
    text.dispose();
    for (final o in opts) {
      o.dispose();
    }
  }
}

class PollBuilder extends StatefulWidget {
  final String kind; // poll | election
  const PollBuilder({super.key, required this.kind});

  @override
  State<PollBuilder> createState() => _PollBuilderState();
}

class _PollBuilderState extends State<PollBuilder> {
  late final bool el = widget.kind == 'election';
  late String category = el ? 'Governance & elections' : 'General';
  late DateTime closes = DateTime.now().add(Duration(days: el ? 14 : 7));
  late String showResults = el ? 'closed' : 'vote';
  final title = RtController();
  final desc = RtController();
  final List<_QDraft> qs = [];
  String? error;

  @override
  void initState() {
    super.initState();
    qs.add(_blank());
  }

  _QDraft _blank() => el ? _QDraft() : _QDraft(options: const ['Option 1', 'Option 2']);

  @override
  void dispose() {
    title.dispose();
    desc.dispose();
    for (final q in qs) {
      q.dispose();
    }
    super.dispose();
  }

  void _publish() {
    final questions = <PollQuestion>[];
    for (var i = 0; i < qs.length; i++) {
      final q = qs[i];
      questions.add(PollQuestion('q${i + 1}', q.type, q.text.toHtml(), q.text.plain, q.required, el ? q.seats : (q.type == 'multi' ? q.max : 0), [for (final o in q.opts) o.text]));
    }
    final err = app.publishPoll(
      kind: widget.kind,
      category: category,
      titleHtml: title.toHtml(),
      descHtml: desc.toHtml(),
      closeKey: isoDay(closes),
      showResults: showResults,
      questions: questions,
    );
    if (err != null) {
      setState(() => error = err);
      msg(context, err);
      return;
    }
    Navigator.pop(context);
    msg(context, el ? 'Election opened. Residents can vote now.' : 'Poll published. Residents can answer now.');
  }

  Widget _label(String t, {String? small}) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: Row(children: [
          Text(t, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          if (small != null) ...[const SizedBox(width: 6), Text(small, style: TextStyle(color: muted(context), fontSize: 12))],
        ]),
      );

  Widget _step(int n, String t, {Widget? trailing}) => Row(children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: lavDeep, shape: BoxShape.circle),
          child: Text('$n', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(t, style: hd(17))),
        if (trailing != null) trailing,
      ]);

  Widget _stepper(String label, int value, int min, int max, ValueChanged<int> on, {String? note}) => Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600))),
          IconButton(visualDensity: VisualDensity.compact, onPressed: value > min ? () => on(value - 1) : null, icon: const Icon(Icons.remove_circle_outline_rounded)),
          SizedBox(width: 28, child: Text('$value', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
          IconButton(visualDensity: VisualDensity.compact, onPressed: value < max ? () => on(value + 1) : null, icon: const Icon(Icons.add_circle_outline_rounded)),
          if (note != null) SizedBox(width: 74, child: Text(note, style: TextStyle(color: muted(context), fontSize: 11.5))),
        ],
      );

  Widget _options(_QDraft q, String noun) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var k = 0; k < q.opts.length; k++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(q.type == 'multi' ? Icons.check_box_outline_blank_rounded : Icons.radio_button_unchecked_rounded, color: muted(context), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: q.opts[k],
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(hintText: '$noun ${k + 1}', isDense: true),
                      onSubmitted: (_) => setState(() => q.opts.insert(k + 1, TextEditingController())),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Remove',
                    onPressed: q.opts.length > 1
                        ? () => setState(() {
                              q.opts.removeAt(k).dispose();
                            })
                        : null,
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
            ),
          TextButton.icon(onPressed: () => setState(() => q.opts.add(TextEditingController())), icon: const Icon(Icons.add_rounded), label: Text('Add ${noun.toLowerCase()}')),
        ],
      );

  Widget _questionCard(int i) {
    final q = qs[i];
    final choice = el || q.type == 'choice' || q.type == 'multi';
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: Theme.of(context).colorScheme.outlineVariant)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: lav.withAlpha(110), shape: BoxShape.circle),
                child: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              ),
              const SizedBox(width: 8),
              Text(el ? 'Position' : 'Question', style: const TextStyle(fontWeight: FontWeight.w800)),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Move up',
                onPressed: i == 0 ? null : () => setState(() => qs.insert(i - 1, qs.removeAt(i))),
                icon: const Icon(Icons.arrow_upward_rounded, size: 20),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Move down',
                onPressed: i == qs.length - 1 ? null : () => setState(() => qs.insert(i + 1, qs.removeAt(i))),
                icon: const Icon(Icons.arrow_downward_rounded, size: 20),
              ),
              IconButton(visualDensity: VisualDensity.compact, tooltip: 'Duplicate', onPressed: () => setState(() => qs.insert(i + 1, q.copy())), icon: const Icon(Icons.copy_rounded, size: 20)),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Delete',
                onPressed: () {
                  if (qs.length < 2) {
                    msg(context, el ? 'An election needs at least one position.' : 'A poll needs at least one question.');
                    return;
                  }
                  setState(() => qs.removeAt(i).dispose());
                },
                icon: const Icon(Icons.delete_outline_rounded, size: 20, color: danger),
              ),
            ],
          ),
          if (!el) ...[
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: q.type,
              decoration: const InputDecoration(labelText: 'Type of question', isDense: true),
              items: [for (final t in pollTypes) DropdownMenuItem(value: t[0], child: Text(t[1]))],
              onChanged: (v) => setState(() {
                q.type = v ?? 'choice';
                if ((q.type == 'choice' || q.type == 'multi') && q.opts.length < 2) {
                  q.opts
                    ..clear()
                    ..addAll([TextEditingController(text: 'Option 1'), TextEditingController(text: 'Option 2')]);
                }
              }),
            ),
          ],
          _label(el ? 'Position name' : 'Question'),
          RichField(q.text, hint: el ? 'e.g. President' : 'Type your question', maxLines: 4),
          if (choice) ...[
            _label(el ? 'Candidates' : 'Options', small: 'Tap Enter for the next one'),
            _options(q, el ? 'Candidate' : 'Option'),
          ] else
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Theme.of(context).colorScheme.outlineVariant.withAlpha(80)),
              child: Text(
                q.type == 'rating' ? 'Residents rate from 1 to 5.' : (q.type == 'text' ? 'Residents type a short answer.' : 'Residents type a long answer.'),
                style: TextStyle(color: muted(context), fontSize: 13),
              ),
            ),
          if (el) _stepper('Residents can vote for up to', q.seats, 1, 20, (v) => setState(() => q.seats = v), note: q.seats > 1 ? 'several seats' : 'one winner'),
          if (!el && q.type == 'multi') _stepper('Most choices allowed', q.max, 0, 20, (v) => setState(() => q.max = v), note: '0 = no limit'),
          if (!el) SwitchListTile(contentPadding: EdgeInsets.zero, dense: true, title: const Text('Required'), value: q.required, onChanged: (v) => setState(() => q.required = v)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final noun = el ? 'position' : 'question';
    final cats = app.pollCategoryChoices;
    final nOpts = qs.fold<int>(0, (s, q) => s + q.opts.where((o) => o.text.trim().isNotEmpty).length);
    return SubPage(
      title: el ? 'New election' : 'New poll',
      subtitle: el ? 'Each unit gets one secret ballot. Residents see the results only after the election closes.' : 'Ask one question or several, like a form. Each unit answers once.',
      children: [
        RCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _step(1, 'Details'),
              _label('Category'),
              DropdownButtonFormField<String>(
                value: cats.contains(category) ? category : 'General',
                isExpanded: true,
                decoration: const InputDecoration(isDense: true),
                items: [for (final c in cats) DropdownMenuItem(value: c, child: Text(c))],
                onChanged: (v) => setState(() => category = v ?? 'General'),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final n = await showNewCategory(context);
                      if (n != null) setState(() => category = n);
                    },
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('New category'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await showCategoryManager(context);
                      if (mounted && !app.pollCategoryChoices.contains(category)) setState(() => category = 'General');
                    },
                    icon: const Icon(Icons.edit_note_rounded, size: 18),
                    label: const Text('Edit / delete categories'),
                  ),
                ],
              ),
              _label(el ? 'Election title' : 'Poll title'),
              RichField(title, hint: el ? 'e.g. 2026 Board of Directors election' : 'e.g. Building facilities survey', maxLines: 3),
              _label('Description', small: 'optional'),
              RichField(desc, hint: 'Tell residents what this is for and how to answer', minLines: 2, maxLines: 6),
            ],
          ),
        ),
        RCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _step(2, el ? 'Positions and candidates' : 'Questions'),
              if (el)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() {
                      qs.removeWhere((q) {
                        final empty = q.text.plain.isEmpty && q.opts.every((o) => o.text.trim().isEmpty);
                        if (empty) q.dispose();
                        return empty;
                      });
                      for (final n in _boardPositions) {
                        qs.add(_QDraft(html: '<b>$n</b>'));
                      }
                    }),
                    icon: const Icon(Icons.groups_2_outlined),
                    label: const Text('Add standard board positions'),
                  ),
                ),
              const SizedBox(height: 8),
              for (var i = 0; i < qs.length; i++) _questionCard(i),
              OutlinedButton.icon(onPressed: () => setState(() => qs.add(_blank())), icon: const Icon(Icons.add_rounded), label: Text('Add $noun')),
            ],
          ),
        ),
        RCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _step(3, 'Settings'),
              _label('Closes on'),
              OutlinedButton.icon(
                onPressed: () async {
                  final today = DateTime.now();
                  final d = await showDatePicker(context: context, initialDate: closes.isBefore(today) ? today : closes, firstDate: DateTime(today.year, today.month, today.day), lastDate: DateTime(today.year + 3));
                  if (d != null) setState(() => closes = d);
                },
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                label: Text(shortDate(closes)),
              ),
              _label('Results for residents'),
              DropdownButtonFormField<String>(
                value: showResults,
                isExpanded: true,
                decoration: const InputDecoration(isDense: true),
                items: const [
                  DropdownMenuItem(value: 'vote', child: Text('Right after they vote')),
                  DropdownMenuItem(value: 'closed', child: Text('Only when it closes')),
                ],
                onChanged: (v) => setState(() => showResults = v ?? 'vote'),
              ),
              if (el) Padding(padding: const EdgeInsets.only(top: 10), child: Text('Ballots are secret. You can see who voted, but not who they voted for.', style: TextStyle(color: muted(context), fontSize: 12.5))),
              const SizedBox(height: 14),
              Text('${qs.length} $noun${qs.length == 1 ? '' : 's'}${nOpts > 0 ? ' · $nOpts ${el ? 'candidates' : 'options'}' : ''}', style: TextStyle(color: muted(context), fontWeight: FontWeight.w600)),
              if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: const TextStyle(color: danger, fontWeight: FontWeight.w600))),
              const SizedBox(height: 10),
              SizedBox(width: double.infinity, child: FilledButton(onPressed: _publish, child: Text(el ? 'Open the election' : 'Publish poll'))),
              const SizedBox(height: 6),
              Center(child: Text('Residents can vote right away.', style: TextStyle(color: muted(context), fontSize: 12))),
            ],
          ),
        ),
      ],
    );
  }
}
