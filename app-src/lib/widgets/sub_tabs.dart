// The sub-page bar: a pill-shaped switch with a count on each page. Used where a page is split up
// (Facility, Announcements, Polls) so each screen shows one thing.

import 'package:flutter/material.dart';

import '../core/core.dart';
import 'common.dart';

class SubTabItem {
  final String label;
  final int? count;

  /// A "hot" count is shown in colour: something is waiting for the administrator.
  final bool hot;
  const SubTabItem(this.label, {this.count, this.hot = false});
}

class SubTabs extends StatelessWidget {
  final List<SubTabItem> items;
  final int index;
  final ValueChanged<int> onChanged;
  const SubTabs({super.key, required this.items, required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(color: cs.surfaceContainerHighest.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < items.length; i++)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: i == index ? cs.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: i == index ? [BoxShadow(color: ink.withAlpha(30), blurRadius: 10, offset: const Offset(0, 3))] : null,
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(tr(items[i].label), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: i == index ? cs.onSurface : muted(context))),
                    if (items[i].count != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        constraints: const BoxConstraints(minWidth: 22),
                        height: 22,
                        padding: const EdgeInsets.symmetric(horizontal: 7),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: items[i].hot && items[i].count! > 0 ? const Color(0xFFE5A33A) : lavDeep.withAlpha(40),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text('${items[i].count}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: items[i].hot && items[i].count! > 0 ? const Color(0xFF2C1D00) : cs.onSurface)),
                      ),
                    ],
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
