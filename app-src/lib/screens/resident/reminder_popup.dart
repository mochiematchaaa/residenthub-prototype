// The reminder pop-up on the resident home screen, and the preview the office sees when editing a reminder.

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../widgets/widgets.dart';
import 'dues_screen.dart';
import 'parking_screen.dart';

/// One reminder card. [onTap] is null in a preview.
class ReminderCard extends StatelessWidget {
  final Reminder r;
  final VoidCallback? onTap;
  const ReminderCard(this.r, {super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = toneOf(context, r.kind == 'custom' ? Tone.info : r.late ? Tone.bad : Tone.warn);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(22)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(r.kind == 'parking' ? Icons.two_wheeler_rounded : r.kind == 'custom' ? Icons.campaign_outlined : Icons.receipt_long_rounded, color: t.fg),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.title, style: TextStyle(fontWeight: FontWeight.w800, color: t.fg)),
                const SizedBox(height: 3),
                Text(r.text, style: TextStyle(color: t.fg, fontSize: 12.5, height: 1.35)),
                const SizedBox(height: 10),
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 36), padding: const EdgeInsets.symmetric(horizontal: 18)),
                  onPressed: onTap,
                  child: Text(r.btn),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows the pop-up when something is due and the office's "how often" rule allows it.
Future<void> showReminderPopup(BuildContext context) async {
  if (app.role != Role.resident || app.myUnit.isEmpty) return;
  final items = app.remPopupItems();
  if (items.isEmpty) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: muted(ctx).withAlpha(90), borderRadius: BorderRadius.circular(9)))),
          const SizedBox(height: 14),
          Text('Reminders', style: hd(24)),
          const SizedBox(height: 4),
          Text(items.length == 1 ? 'One thing needs your attention.' : '${items.length} things need your attention.', style: TextStyle(color: muted(ctx))),
          const SizedBox(height: 14),
          for (final r in items)
            ReminderCard(r, onTap: () {
              Navigator.pop(ctx);
              if (!context.mounted || r.kind == 'custom') return;
              if (r.dueId != null) {
                final due = app.myDues.where((d) => '${d.id}' == r.dueId).firstOrNull;
                go(context, const ResDues());
                if (due != null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (context.mounted) sendDueProof(context, due: due);
                  });
                }
              } else {
                go(context, const ResParking());
              }
            }),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Remind me later'))),
              const SizedBox(width: 10),
              Expanded(
                child: TextButton(
                  onPressed: () {
                    app.remSnoozeToday();
                    Navigator.pop(ctx);
                    if (context.mounted) msg(context, 'OK. No more reminder pop-ups today.');
                  },
                  child: const Text('Do not show again today', textAlign: TextAlign.center),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// A sample pop-up for the office, so it can see how a reminder looks.
void showReminderPreview(BuildContext context, String kind) {
  final r = kind == 'parking'
      ? Reminder('x', 'parking', 'Your parking rental is almost up',
          app.remText('parking', {'slot': 'M-07', 'date': 'Nov 28, 2026', 'days': 'in 3 days'}), 'Open Parking', false, 3)
      : Reminder('x', 'dues', 'Charge coming due',
          app.remText('dues', {'item': 'Association dues, November 2026', 'amount': peso(2550), 'when': remWhen(2), 'date': 'Nov 30, 2026'}), 'Pay now', false, 2);
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: muted(ctx).withAlpha(90), borderRadius: BorderRadius.circular(9)))),
          const SizedBox(height: 14),
          Text('Preview: what the resident sees', style: hd(22)),
          const SizedBox(height: 4),
          Text('A sample. The real pop-up uses the resident’s own charge or slot.', style: TextStyle(color: muted(ctx))),
          const SizedBox(height: 14),
          ReminderCard(r),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))),
        ],
      ),
    ),
  );
}
