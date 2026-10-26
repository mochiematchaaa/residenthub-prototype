// The floating bottom navigation bar.

import 'package:flutter/material.dart';

import '../core/core.dart';

class NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int badge;
  const NavItem(this.icon, this.activeIcon, this.label, {this.badge = 0});
}

/// Floating pill navigation bar. Icons only; the selected one sits on a lavender pill.
class FloatingNav extends StatelessWidget {
  final List<NavItem> items;
  final int index;
  final ValueChanged<int> onTap;
  const FloatingNav({super.key, required this.items, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(color: ink.withAlpha(dark ? 90 : 36), blurRadius: 26, offset: const Offset(0, 10)),
            ],
          ),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++) _item(context, i),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(BuildContext context, int i) {
    final it = items[i];
    final sel = i == index;
    final cs = Theme.of(context).colorScheme;
    Widget icon = Icon(sel ? it.activeIcon : it.icon, size: 24, color: sel ? ink : cs.onSurfaceVariant);
    if (it.badge > 0) {
      icon = Badge(label: Text('${it.badge}'), child: icon);
    }
    return Expanded(
      child: Semantics(
        button: true,
        selected: sel,
        label: it.label,
        child: Tooltip(
          message: it.label,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onTap(i),
            // Fixed height: without it the cell would stretch to the full screen height.
            child: SizedBox(
              height: 50,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  width: 62,
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: sel ? lav : Colors.transparent,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: icon,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
