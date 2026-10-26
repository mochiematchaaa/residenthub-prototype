// ADMIN page: Activity log.

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../services/doc_files.dart';
import '../../widgets/widgets.dart';
import '../shared/document_viewer_screen.dart';

/// Administrator: the full log of what happened in the app.
class AdminActivity extends StatefulWidget {
  const AdminActivity({super.key});

  @override
  State<AdminActivity> createState() => _AdminActivityState();
}

class _AdminActivityState extends State<AdminActivity> {
  String _area = 'All';
  int _page = 0;
  static const _pageSize = 15;

  List<DocBlock> _blocks(List<ActivityEntry> list) => [
        const DocBlock.h1('Activity log'),
        const DocBlock.p('City Residences Condominium Corporation'),
        DocBlock.table([
          const ['When', 'Area', 'What happened'],
          for (final a in list) [shortDate(a.at), a.area, a.title],
        ]),
      ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final areas = ['All', ...{for (final a in app.activityLog) a.area}];
        if (!areas.contains(_area)) _area = 'All';
        final shown = app.activityLog.where((a) => _area == 'All' || a.area == _area).toList();
        final pages = shown.isEmpty ? 1 : (shown.length / _pageSize).ceil();
        final page = _page.clamp(0, pages - 1);
        final slice = shown.skip(page * _pageSize).take(_pageSize).toList();
        return SubPage(
          title: 'Activity log',
          subtitle: 'Everything that happened in the community, newest first.',
          children: [
            FilterRow(options: areas, selected: _area, onSelect: (v) => setState(() {
              _area = v;
              _page = 0;
            })),
            if (shown.isEmpty)
              const EmptyBox('Nothing has happened yet.', icon: Icons.history_rounded)
            else ...[
              OutlinedButton.icon(
                onPressed: () => runSave(context, 'Excel file', () => exportXlsx('Activity log', _blocks(shown))),
                icon: const Icon(Icons.download_rounded),
                label: const Text('Export to Excel'),
              ),
              RCard(
                child: Column(
                  children: [
                    for (final a in slice)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(a.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                        subtitle: Text('${a.area} · ${AppState.ago(a.at)}'),
                      ),
                  ],
                ),
              ),
              if (pages > 1)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    OutlinedButton.icon(
                      onPressed: page == 0 ? null : () => setState(() => _page = page - 1),
                      icon: const Icon(Icons.chevron_left_rounded),
                      label: const Text('Prev'),
                    ),
                    Column(
                      children: [
                        Text('Page ${page + 1} of $pages', style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text('${page * _pageSize + 1}–${page * _pageSize + slice.length} of ${shown.length}', style: TextStyle(color: muted(context), fontSize: 12)),
                      ],
                    ),
                    OutlinedButton(
                      onPressed: page >= pages - 1 ? null : () => setState(() => _page = page + 1),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [Text('Next'), Icon(Icons.chevron_right_rounded)]),
                    ),
                  ],
                ),
            ],
          ],
        );
      },
    );
  }
}
