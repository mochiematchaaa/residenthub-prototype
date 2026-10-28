// The notification list behind the bell, laid out like Facebook's: newest first, unread ones highlighted
// with a dot, "New" and "Earlier" groups, All / Unread tabs and "Mark all as read".

import 'package:flutter/material.dart';

import '../core/core.dart';
import 'common.dart';

Tone _toneOf(String t) => t == 'good'
    ? Tone.good
    : t == 'bad'
        ? Tone.bad
        : t == 'warn'
            ? Tone.warn
            : Tone.info;

IconData _iconFor(NotifItem n) =>
    n.icon ??
    (n.tone == 'good'
        ? Icons.check_rounded
        : n.tone == 'bad'
            ? Icons.priority_high_rounded
            : n.tone == 'warn'
                ? Icons.schedule_rounded
                : Icons.info_outline_rounded);

/// Opens the notification sheet. [items] is called again whenever something changes. Tapping a line marks it
/// read, closes the sheet and calls [onOpen] (which usually goes to the right page).
void showNotifSheet(
  BuildContext context, {
  required String title,
  required String scope,
  required List<NotifItem> Function() items,
  required void Function(NotifItem n) onOpen,
  String emptyText = 'You are all caught up.',
}) {
  app.bellOpened(scope);
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _NotifSheet(title: title, items: items, onOpen: onOpen, emptyText: emptyText),
  );
}

class _NotifSheet extends StatefulWidget {
  final String title, emptyText;
  final List<NotifItem> Function() items;
  final void Function(NotifItem n) onOpen;
  const _NotifSheet({required this.title, required this.items, required this.onOpen, required this.emptyText});

  @override
  State<_NotifSheet> createState() => _NotifSheetState();
}

class _NotifSheetState extends State<_NotifSheet> {
  bool unreadOnly = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final all = widget.items();
        final unread = all.where((n) => n.unread).toList();
        final shown = unreadOnly ? unread : all;
        final fresh = shown.where((n) => n.unread).toList();
        final earlier = shown.where((n) => !n.unread).toList();
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(width: 42, height: 4, decoration: BoxDecoration(color: muted(context).withAlpha(90), borderRadius: BorderRadius.circular(9))),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: Text(widget.title, style: hd(24))),
                    if (unread.isNotEmpty)
                      TextButton(
                        onPressed: () => app.bellReadAll(all),
                        child: const Text('Mark all as read', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    ChoiceChip(label: const Text('All'), selected: !unreadOnly, onSelected: (_) => setState(() => unreadOnly = false)),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text(unread.isEmpty ? 'Unread' : 'Unread (${unread.length})'),
                      selected: unreadOnly,
                      onSelected: (_) => setState(() => unreadOnly = true),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (shown.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Center(
                      child: Column(children: [
                        Icon(Icons.notifications_none_rounded, size: 40, color: muted(context)),
                        const SizedBox(height: 8),
                        Text(unreadOnly ? 'No unread notifications.' : widget.emptyText, style: TextStyle(color: muted(context), fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  )
                else
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        if (fresh.isNotEmpty) _section(context, 'New'),
                        for (final n in fresh) _row(context, n),
                        if (earlier.isNotEmpty) _section(context, 'Earlier'),
                        for (final n in earlier) _row(context, n),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _section(BuildContext context, String t) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 10, 0, 6),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
      );

  Widget _row(BuildContext context, NotifItem n) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: n.unread ? lav.withAlpha(40) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            app.bellRead(n.key);
            Navigator.pop(context);
            widget.onOpen(n);
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconBadge(_iconFor(n), tone: _toneOf(n.tone), size: 42),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(n.text, style: TextStyle(fontWeight: n.unread ? FontWeight.w700 : FontWeight.w500, fontSize: 13.5, height: 1.35)),
                      const SizedBox(height: 3),
                      Text(agoText(n.at), style: TextStyle(fontSize: 12, fontWeight: n.unread ? FontWeight.w800 : FontWeight.w500, color: n.unread ? lavDeep : muted(context))),
                      if (n.dueId != null) ...[
                        const SizedBox(height: 6),
                        FilledButton(
                          style: FilledButton.styleFrom(minimumSize: const Size(0, 34), padding: const EdgeInsets.symmetric(horizontal: 16)),
                          onPressed: () {
                            app.bellRead(n.key);
                            Navigator.pop(context);
                            widget.onOpen(n);
                          },
                          child: const Text('Pay now'),
                        ),
                      ],
                    ],
                  ),
                ),
                if (n.unread)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, top: 14),
                    child: Container(width: 10, height: 10, decoration: const BoxDecoration(color: lavDeep, shape: BoxShape.circle)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
