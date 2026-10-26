// The notification list (bell) for residents.

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../widgets/widgets.dart';

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
                        : Icons.info_outline_rounded,
                tone: n[1] == 'good'
                    ? Tone.good
                    : n[1] == 'bad'
                        ? Tone.bad
                        : Tone.info,
                size: 40,
              ),
              title: Text(n[0], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            ),
        ],
      ),
    );
    },
  );
}
