// The notification list (bell) for residents, laid out like Facebook's.

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../widgets/widgets.dart';
import 'dues_screen.dart';
import 'parking_screen.dart';
import 'polls_screen.dart';

/// Opened by the bell button on the resident home screen.
void showResNotifications(BuildContext context) {
  showNotifSheet(
    context,
    title: 'Notifications',
    scope: app.bellScope,
    items: () => app.myBell,
    emptyText: 'No notifications yet.',
    onOpen: (n) => openResNotification(context, n),
  );
}

/// Goes to the page a notification is about.
void openResNotification(BuildContext context, NotifItem n) {
  if (!context.mounted) return;
  if (n.dueId != null) {
    final due = app.myDues.where((d) => '${d.id}' == n.dueId).firstOrNull;
    go(context, const ResDues());
    if (due != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) sendDueProof(context, due: due);
      });
    }
    return;
  }
  final t = n.text.toLowerCase();
  if (t.contains('parking')) {
    go(context, const ResParking());
  } else if (t.contains('poll')) {
    go(context, const ResPolls());
  } else if (t.contains('booking') || t.contains('request')) {
    app.setResTab(1);
  } else if (t.contains('charge') || t.contains('payment') || t.contains('overdue') || t.contains('reminder from the office')) {
    app.setResTab(3);
  }
}
