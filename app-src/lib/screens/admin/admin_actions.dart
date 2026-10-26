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

/// "Needs attention" sheet opened from the bell button.
void showAdminAttention(BuildContext context) {
  final items = [
    [Icons.event_note_outlined, '${app.pendingBookings} booking request(s) to review', 2],
    [Icons.payments_outlined, '${app.unpaidCount} unit(s) with unpaid dues', 3],
    [Icons.home_work_outlined, '${app.newStatusUpdates} new rental update(s)', 12],
    [Icons.two_wheeler_outlined, '${app.pendingParking} parking request(s)', 15],
    [Icons.fact_check_outlined, '${app.rentalsToReview} unit declaration(s) to review', 12],
  ];
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Needs attention', style: hd(22)),
          const SizedBox(height: 8),
          for (final it in items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: IconBadge(it[0] as IconData, tone: Tone.warn, size: 40),
              title: Text(it[1] as String, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.pop(ctx);
                adminJump(context, it[2] as int);
              },
            ),
        ],
      ),
    ),
  );
}

/// Items for the quick-search sheet on the admin home.
List<SearchItem> adminSearchItems(BuildContext context) => [
      SearchItem('Calendar', 'Events and facility bookings', Icons.calendar_month_rounded, () => go(context, const CalendarScreen(admin: true))),
      SearchItem('Units & residents', 'Search units, usage, status', Icons.apartment_rounded, () => app.setAdminTab(1)),
      SearchItem('Facility booking', 'Approve requests, block slots', Icons.event_available_rounded, () => app.setAdminTab(2)),
      SearchItem('Finance', 'Dues, charges, motor parking rate', Icons.payments_rounded, () => app.setAdminTab(3)),
      SearchItem('Announcements & events', 'Post news, send alerts', Icons.campaign_rounded, () => go(context, const AdminAnnouncements())),
      SearchItem('Grievances', 'Move concerns to resolved', Icons.build_circle_outlined, () => go(context, const AdminGrievances())),
      SearchItem('Unit status', 'Review declarations, occupancy registry', Icons.home_work_rounded, () => go(context, const AdminUnitStatus())),
      SearchItem('Profile and settings', 'Edit your profile, photo, password', Icons.settings_outlined, () => go(context, const AdminSettings())),
      SearchItem('Polls & voting', 'Publish polls, see results', Icons.how_to_vote_outlined, () => go(context, const AdminPolls())),
      SearchItem('Motor parking', 'Assign and release slots', Icons.two_wheeler_outlined, () => go(context, const AdminParking())),
      SearchItem('Reports', 'Collections, units, concerns, export', Icons.bar_chart_rounded, () => go(context, const AdminReports())),
      SearchItem('Activity log', 'Everything that happened', Icons.history_rounded, () => go(context, const AdminActivity())),
      SearchItem('Expenses', 'Record purchases, monthly expense report', Icons.north_east_rounded, () => go(context, const AdminExpenses())),
      SearchItem('Finance documents', 'Client records, payments, receipts', Icons.lock_outline_rounded, () => go(context, const AdminFinanceDocs())),
      SearchItem('Community documents', 'Rules, forms, notices, minutes', Icons.folder_copy_outlined, () => go(context, const AdminDocs())),
      SearchItem('Manage access', 'Accounts, suspend, revoke', Icons.admin_panel_settings_outlined, () => go(context, const AdminAccess())),
    ];
