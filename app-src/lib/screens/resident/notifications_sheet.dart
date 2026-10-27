// The notification list (bell) for residents.

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../widgets/widgets.dart';
import 'dues_screen.dart';

/// Bottom sheet opened by the bell button on the resident home screen.
void showResNotifications(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    builder: (ctx) {
      final notifs = app.myNotifs;
      return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Notifications', style: hd(22)),
          const SizedBox(height: 10),
          if (notifs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('No notifications yet.', style: TextStyle(color: muted(context))),
            ),
          for (final n in notifs)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: IconBadge(
                n[1] == 'good'
                    ? Icons.check_rounded
                    : n[1] == 'bad'
                        ? Icons.priority_high_rounded
                        : n[1] == 'warn'
                            ? Icons.schedule_rounded
                            : Icons.info_outline_rounded,
                tone: n[1] == 'good'
                    ? Tone.good
                    : n[1] == 'bad'
                        ? Tone.bad
                        : n[1] == 'warn'
                            ? Tone.warn
                            : Tone.info,
                size: 40,
              ),
              title: Text(n[0], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: n.length > 2
                  ? Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: FilledButton(
                          style: FilledButton.styleFrom(minimumSize: const Size(0, 34), padding: const EdgeInsets.symmetric(horizontal: 16)),
                          onPressed: () {
                            final due = app.myDues.where((d) => '${d.id}' == n[2]).firstOrNull;
                            Navigator.pop(ctx);
                            go(context, const ResDues());
                            if (due != null) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (context.mounted) sendDueProof(context, due: due);
                              });
                            }
                          },
                          child: const Text('Pay now'),
                        ),
                      ),
                    )
                  : null,
            ),
        ],
      ),
    );
    },
  );
}
