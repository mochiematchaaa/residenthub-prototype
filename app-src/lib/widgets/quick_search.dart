// The quick search box that jumps to pages and records.

import 'package:flutter/material.dart';

import 'common.dart';

class SearchItem {
  final String label;
  final String hint;
  final IconData icon;
  final VoidCallback onTap;
  const SearchItem(this.label, this.hint, this.icon, this.onTap);
}

/// Search sheet that jumps to any screen in the app.
void showQuickSearch(BuildContext context, List<SearchItem> items) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _QuickSearch(items: items),
  );
}

class _QuickSearch extends StatefulWidget {
  final List<SearchItem> items;
  const _QuickSearch({required this.items});

  @override
  State<_QuickSearch> createState() => _QuickSearchState();
}

class _QuickSearchState extends State<_QuickSearch> {
  String q = '';

  @override
  Widget build(BuildContext context) {
    final s = q.trim().toLowerCase();
    final list = widget.items.where((i) => s.isEmpty || '${i.label} ${i.hint}'.toLowerCase().contains(s)).toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Search', style: hd(22)),
            const SizedBox(height: 12),
            TextField(
              autofocus: true,
              onChanged: (v) => setState(() => q = v),
              decoration: const InputDecoration(hintText: 'Find a screen or feature…', prefixIcon: Icon(Icons.search_rounded)),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (list.isEmpty) const EmptyBox('Nothing matches that search.', icon: Icons.search_off_rounded),
                  for (final i in list)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: IconBadge(i.icon, accent: true, size: 40),
                      title: Text(i.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(i.hint),
                      onTap: () {
                        Navigator.pop(context);
                        i.onTap();
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
