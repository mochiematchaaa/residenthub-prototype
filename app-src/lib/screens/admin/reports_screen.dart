// ADMIN page: Reports.

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../services/doc_files.dart';
import '../../widgets/widgets.dart';
import '../shared/document_viewer_screen.dart';

/// Administrator: one-page summary of the community, with Word and Excel export.
class AdminReports extends StatelessWidget {
  const AdminReports({super.key});

  List<List<String>> _usage() => [
        for (final o in statusOptions) [o.label, '${app.units.where((u) => u.usage == o.key).length}'],
      ];

  List<List<String>> _ageing() {
    final open = app.dues.where((d) => !d.paid).toList();
    num sum(bool Function(Due) f) => open.where(f).fold<num>(0, (s, d) => s + d.amt);
    int n(bool Function(Due) f) => open.where(f).length;
    return [
      ['Open, not yet due', '${n((d) => !d.overdue)}', peso(sum((d) => !d.overdue))],
      ['Overdue', '${n((d) => d.overdue)}', peso(sum((d) => d.overdue))],
    ];
  }

  List<List<String>> _facility() => [
        for (final f in app.amenities)
          [f.name, '${app.bookings.where((b) => b.place == f.name && b.status != 'Denied').length}'],
      ];

  List<DocBlock> _blocks() {
    final labels = app.collectionTrendLabels();
    final values = app.collectionTrend();
    return [
      const DocBlock.h1('Community report'),
      const DocBlock.p('City Residences Condominium Corporation'),
      const DocBlock.h2('Collections, last 6 months'),
      DocBlock.table([
        const ['Month', 'Collected'],
        for (var i = 0; i < labels.length; i++) [labels[i], peso(values[i])],
      ]),
      const DocBlock.h2('Unpaid charges'),
      DocBlock.table([const ['Status', 'Charges', 'Amount'], ..._ageing()]),
      const DocBlock.h2('How units are used'),
      DocBlock.table([const ['Status', 'Units'], ..._usage()]),
      const DocBlock.h2('Complaints'),
      DocBlock.table([
        const ['Stage', 'Count'],
        for (var s = 0; s < 3; s++) [const ['Open', 'In progress', 'Resolved'][s], '${app.grievances.where((g) => g.stage == s).length}'],
      ]),
      const DocBlock.h2('Facility bookings'),
      DocBlock.table([const ['Place', 'Bookings'], ..._facility()]),
      const DocBlock.h2('Poll turnout'),
      DocBlock.table([
        const ['Poll', 'Status', 'Votes'],
        for (final p in app.polls) [p.question, p.open ? 'Open' : 'Closed', '${p.total}'],
      ]),
    ];
  }

  Widget _bars(BuildContext context, List<String> labels, List<double> values) {
    final top = values.fold<double>(0, (m, v) => v > m ? v : m);
    return SizedBox(
      height: 130,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(peso(values[i]), style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: top == 0 ? 0 : values[i] / top),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, __) => Container(
                        height: 4 + 70 * v,
                        decoration: BoxDecoration(color: i == values.length - 1 ? lavDeep : lav, borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(labels[i], style: TextStyle(fontSize: 11, color: muted(context))),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _rows(BuildContext context, List<List<String>> rows) => Column(
        children: [
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(child: Text(r[0], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5))),
                  for (final c in r.skip(1))
                    Padding(
                      padding: const EdgeInsets.only(left: 14),
                      child: Text(c, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                    ),
                ],
              ),
            ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final open = app.dues.where((d) => !d.paid).fold<num>(0, (s, d) => s + d.amt);
        return SubPage(
          title: 'Reports',
          subtitle: 'A summary of collections, units, concerns and bookings.',
          children: [
            PastelCard(
              color: Pastel.mint,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: StatsRow([
                ['This month', peso(app.collectedThisMonth)],
                ['Unpaid', peso(open)],
                ['Spent', peso(app.spentThisMonth)],
              ]),
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => runSave(context, 'Word file', () => exportDocx('Community report', _blocks())),
                    icon: const Icon(Icons.description_outlined),
                    label: const Text('Word'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => runSave(context, 'Excel file', () => exportXlsx('Community report', _blocks())),
                    icon: const Icon(Icons.table_chart_outlined),
                    label: const Text('Excel'),
                  ),
                ),
              ],
            ),
            RCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Collections', style: hd(17)),
                  const SizedBox(height: 12),
                  _bars(context, app.collectionTrendLabels(), app.collectionTrend()),
                ],
              ),
            ),
            RCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Unpaid charges', style: hd(17)),
                  const SizedBox(height: 6),
                  _rows(context, _ageing()),
                ],
              ),
            ),
            RCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('How units are used', style: hd(17)),
                  const SizedBox(height: 6),
                  _rows(context, _usage()),
                ],
              ),
            ),
            RCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Complaints', style: hd(17)),
                  const SizedBox(height: 6),
                  _rows(context, [
                    for (var s = 0; s < 3; s++) [const ['Open', 'In progress', 'Resolved'][s], '${app.grievances.where((g) => g.stage == s).length}'],
                  ]),
                ],
              ),
            ),
            RCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Facility bookings', style: hd(17)),
                  const SizedBox(height: 6),
                  _rows(context, _facility()),
                ],
              ),
            ),
            RCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Poll turnout', style: hd(17)),
                  const SizedBox(height: 6),
                  _rows(context, [for (final p in app.polls) [p.question, '${p.total}']]),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
