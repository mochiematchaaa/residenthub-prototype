// RESIDENT page: Documents.

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../widgets/widgets.dart';
import '../shared/document_viewer_screen.dart';

class ResDocuments extends StatefulWidget {
  const ResDocuments({super.key});

  @override
  State<ResDocuments> createState() => _ResDocumentsState();
}

class _ResDocumentsState extends State<ResDocuments> {
  String filter = 'All';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final all = app.communityDocs;
        final shown = filter == 'All' ? all : all.where((d) => d.cat == filter).toList();
        return SubPage(
          title: 'Community documents',
          subtitle: 'Tap a document to read it. You can download any of them as Word or Excel.',
          children: [
            FilterRow(
              options: const ['All', ...communityCategories],
              selected: filter,
              onSelect: (v) => setState(() => filter = v),
            ),
            if (shown.isEmpty) EmptyBox('No $filter documents yet.', icon: Icons.folder_open_rounded),
            for (final d in shown) DocTile(doc: d, onTap: () => go(context, DocViewer(d))),
          ],
        );
      },
    );
  }
}
