// Excel file with the results of one poll or election (same sheets as the website).

import '../core/core.dart';
import '../core/rich_text.dart';
import 'doc_files.dart';

String _pct(num a, num b) => b == 0 ? '—' : '${(a / b * 100).round()}%';

/// What a unit answered, written for the Responses sheet and the voters list.
String answerText(PollQuestion q, dynamic v) {
  if (v == null || v == '') return '';
  if (q.type == 'choice') {
    final i = v is num ? v.toInt() : -1;
    return i >= 0 && i < q.options.length ? q.options[i] : '';
  }
  if (q.type == 'multi') {
    return [
      for (final x in (v is List ? v : [v]))
        if (x is num && x.toInt() >= 0 && x.toInt() < q.options.length) q.options[x.toInt()],
    ].join(', ');
  }
  if (q.type == 'rating') return '$v / 5';
  return v.toString();
}

String _day(String iso) {
  final d = DateTime.tryParse(iso);
  return d == null ? '' : shortDate(d.toLocal());
}

List<XSheet> pollSheets(Poll p) {
  final el = p.isElection;
  final title = RtDoc.fromHtml(p.titleHtml).plain.isEmpty ? p.question : RtDoc.fromHtml(p.titleHtml).plain;
  final ballots = app.ballotsOf(p);
  final byUnit = {for (final b in ballots) b.unit: b};
  final units = [...app.units];
  final sheets = <XSheet>[];

  sheets.add(XSheet('Overview', [
    ['Item', 'Details'],
    ['Title', title],
    ['Type', el ? 'Election (secret ballot)' : 'Poll'],
    ['Category', p.category],
    ['Description', RtDoc.fromHtml(p.descHtml).plain],
    ['Status', p.open ? 'Open' : 'Closed'],
    ['Closes', p.closes],
    ['Results shown to residents', p.showResults == 'closed' ? 'Only when it closes' : 'Right after they vote'],
    [el ? 'Ballots cast' : 'Responses', '${p.ballots}'],
    ['Units in the building', '${units.length}'],
    ['Units that voted', '${byUnit.length}'],
    ['Turnout', _pct(byUnit.length, units.length)],
  ]));

  final results = <List<String>>[
    [el ? 'Position / question' : 'Question', 'Answer', 'Votes', 'Share of answers', 'Result'],
  ];
  for (var i = 0; i < p.questions.length; i++) {
    final q = p.questions[i];
    final label = '${el ? '' : '${i + 1}. '}${q.text}';
    if (q.isChoice) {
      final st = app.electedStatus(p, q);
      for (var k = 0; k < q.options.length; k++) {
        results.add([label, q.options[k], '${q.counts[k]}', _pct(q.counts[k], q.n), st[k]]);
      }
    } else if (q.type == 'rating') {
      for (var s = 5; s >= 1; s--) {
        results.add([label, '$s star${s == 1 ? '' : 's'}', '${q.stars[s - 1]}', _pct(q.stars[s - 1], q.n), '']);
      }
      results.add([label, 'Average rating', q.n == 0 ? '' : (q.ratingSum / q.n).toStringAsFixed(2), '', '']);
    } else {
      results.add([label, 'Written answers are on the Responses sheet', '${q.n}', '', '']);
    }
  }
  sheets.add(XSheet('Results', results));

  if (!el) {
    sheets.add(XSheet('Responses', [
      ['Unit', 'Resident', 'Submitted', for (var i = 0; i < p.questions.length; i++) '${i + 1}. ${p.questions[i].text}'],
      for (final b in ballots)
        [
          b.unit,
          app.units.where((u) => u.unit == b.unit).map((u) => u.name == '—' ? '' : u.name).firstOrNull ?? '',
          _day(b.at),
          for (final q in p.questions) answerText(q, b.answers[q.id]).replaceAll(' / 5', ''),
        ],
    ]));
  }

  sheets.add(XSheet('Turnout', [
    ['Unit', 'Resident', 'Voted'],
    for (final u in units) [u.unit, u.name == '—' ? '' : u.name, byUnit.containsKey(u.unit) ? 'Yes' : 'No'],
  ]));
  return sheets;
}

/// Saves the results of [p] as an Excel file.
Future<bool> exportPoll(Poll p) {
  final title = RtDoc.fromHtml(p.titleHtml).plain.isEmpty ? p.question : RtDoc.fromHtml(p.titleHtml).plain;
  final slug = title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '');
  final short = slug.length > 40 ? slug.substring(0, 40) : slug;
  return exportXlsxSheets('results-${short.isEmpty ? 'poll' : short}-${dayKey(DateTime.now())}', pollSheets(p));
}
