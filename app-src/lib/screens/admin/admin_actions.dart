// Shortcuts used by the admin screens: jump to a page, the 'needs attention' sheet, and quick search items.

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../widgets/widgets.dart';
import 'admin_screens.dart';

/// Jump targets used by the dashboard: 1-4 switch tabs, larger numbers push pages.
void adminJump(BuildContext context, int target) {
  switch (target) {
    case 1:
    case 2:
    case 3:
      app.setAdminTab(target);
      break;
    case 5:
      go(context, const AdminAnnouncements());
      break;
    case 11:
      go(context, const AdminGrievances());
      break;
    case 12:
      go(context, const AdminUnitStatus());
      break;
    case 13:
      go(context, const AdminDocs());
      break;
    case 14:
      go(context, const AdminPolls());
      break;
    case 15:
      go(context, const AdminParking());
      break;
    case 16:
      go(context, const AdminReports());
      break;
    case 17:
      go(context, const AdminActivity());
      break;
  }
}

/// What needs the administrator's attention, as notification lines (only the ones with something to do).
List<NotifItem> adminBellItems() {
  final raw = <(IconData, String, int)>[
    if (app.pendingBookings > 0) (Icons.event_note_outlined, '${app.pendingBookings} booking request(s) to review', 2),
    if (app.payCheckList.isNotEmpty) (Icons.help_outline_rounded, '${app.payCheckList.length} charge(s) to check: did they pay?', 3),
    if (app.unpaidCount > 0) (Icons.payments_outlined, '${app.unpaidCount} unit(s) with unpaid dues', 3),
    if (app.newStatusUpdates > 0) (Icons.home_work_outlined, '${app.newStatusUpdates} new rental update(s)', 12),
    if (app.pendingParking > 0) (Icons.two_wheeler_outlined, '${app.pendingParking} parking request(s)', 15),
    if (app.rentalsToReview > 0) (Icons.fact_check_outlined, '${app.rentalsToReview} unit declaration(s) to review', 12),
  ];
  return app.book.list('admin', [for (final r in raw) (text: r.$2, tone: 'warn', dueId: null, icon: r.$1, tab: r.$3)]);
}

/// "Needs attention" sheet opened from the bell button (same layout as the residents' notifications).
void showAdminAttention(BuildContext context) {
  showNotifSheet(
    context,
    title: 'Needs attention',
    scope: 'admin',
    items: adminBellItems,
    emptyText: 'Nothing needs your attention.',
    onOpen: (n) {
      if (context.mounted && n.tab != null) adminJump(context, n.tab!);
    },
  );
}

/// Items for the quick-search sheet on the admin home.
List<SearchItem> adminSearchItems(BuildContext context) => [
      SearchItem('Calendar', 'Events and facility bookings', Icons.calendar_month_rounded, () => go(context, const CalendarScreen(admin: true))),
      SearchItem('Units & residents', 'Search units, usage, status', Icons.apartment_rounded, () => app.setAdminTab(1)),
      SearchItem('Facility booking', 'Approve requests, block slots', Icons.event_available_rounded, () => app.setAdminTab(2)),
      SearchItem('Finance', 'Dues, charges, motor parking rate', Icons.payments_rounded, () => app.setAdminTab(3)),
      SearchItem('Announcements & events', 'Post news, send alerts', Icons.campaign_rounded, () => go(context, const AdminAnnouncements())),
      SearchItem('Complaints', 'Move concerns to resolved', Icons.build_circle_outlined, () => go(context, const AdminGrievances())),
      SearchItem('Unit status', 'Review declarations, occupancy registry', Icons.home_work_rounded, () => go(context, const AdminUnitStatus())),
      SearchItem('Profile and settings', 'Edit your profile, photo, password', Icons.settings_outlined, () => go(context, const AdminSettings())),
      SearchItem('Polls & voting', 'Publish polls, see results', Icons.how_to_vote_outlined, () => go(context, const AdminPolls())),
      SearchItem('Motor parking', 'Assign and release slots', Icons.two_wheeler_outlined, () => go(context, const AdminParking())),
      SearchItem('Reports', 'Collections, units, concerns, export', Icons.bar_chart_rounded, () => go(context, const AdminReports())),
      SearchItem('Activity log', 'Everything that happened', Icons.history_rounded, () => go(context, const AdminActivity())),
      SearchItem('Expenses', 'Record purchases, monthly expense report', Icons.north_east_rounded, () => go(context, const AdminExpenses())),
      SearchItem('Finance documents', 'Client records, payments, receipts', Icons.lock_outline_rounded, () => go(context, const AdminFinanceDocs())),
      SearchItem('Community documents', 'Rules, forms, notices, minutes', Icons.folder_copy_outlined, () => go(context, const AdminDocs())),
      SearchItem('Manage access', 'Settings: accounts, suspend, revoke', Icons.admin_panel_settings_outlined, () => go(context, const AdminAccess())),
      SearchItem('Resident profiles', 'Each unit\'s resident record and history, Excel export', Icons.manage_search_rounded, () => go(context, const UnitHistoryScreen())),
    ];
