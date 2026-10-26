// ADMIN page: the 'More' menu.

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../services/demo.dart' show kDemo;
import '../../services/session.dart';
import '../../widgets/widgets.dart';
import 'admin_screens.dart';

class AdminMore extends StatelessWidget {
  const AdminMore({super.key});

  @override
  Widget build(BuildContext context) {
    return TabPage(
      title: 'More',
      subtitle: 'Community tools and administration.',
      children: [
        RCard(
          onTap: () => go(context, const AdminSettings()),
          child: Row(
            children: [
              Avatar(initialsOf(app.adminName), size: 54, photo: app.adminPhoto),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(app.adminName, style: hd(19)),
                    Text('Owner · Administrator · tap to edit profile', style: TextStyle(color: muted(context), fontSize: 12.5)),
                  ],
                ),
              ),
              IconButton(
                onPressed: app.toggleDark,
                icon: Icon(app.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
              ),
            ],
          ),
        ),
        NavGroup(label: 'Community', children: [
          NavTile(icon: Icons.calendar_month_rounded, title: 'Calendar', subtitle: 'Events and facility bookings', onTap: () => go(context, const CalendarScreen(admin: true))),
          NavTile(icon: Icons.campaign_outlined, title: 'Announcements & events', subtitle: '${app.announcements.length} announcements · ${app.events.length} events', onTap: () => go(context, const AdminAnnouncements())),
          NavTile(
            icon: Icons.build_circle_outlined,
            title: 'Grievances',
            subtitle: '${app.openGrievances} open',
            onTap: () => go(context, const AdminGrievances()),
            trailing: app.openGrievances > 0 ? Pill('${app.openGrievances}', tone: Tone.warn) : null,
          ),
          NavTile(
            icon: Icons.home_work_outlined,
            title: 'Unit status',
            subtitle: app.rentalsToReview > 0
                ? '${app.rentalsToReview} declaration(s) to review'
                : app.newStatusUpdates == 0 ? 'State of every unit' : '${app.newStatusUpdates} new update(s) from residents',
            onTap: () => go(context, const AdminUnitStatus()),
            trailing: app.newStatusUpdates > 0 ? Pill('${app.newStatusUpdates}', tone: Tone.warn) : null,
          ),
        ]),
        NavGroup(label: 'Operations', children: [
          NavTile(
            icon: Icons.how_to_vote_outlined,
            title: 'Polls & voting',
            subtitle: '${app.openPolls} open · ${app.polls.length} total',
            onTap: () => go(context, const AdminPolls()),
          ),
          NavTile(
            icon: Icons.two_wheeler_outlined,
            title: 'Motor parking',
            subtitle: '${app.slotsUsed} of ${app.slots.length} slots used${app.pendingParking > 0 ? ' · ${app.pendingParking} waiting' : ''}',
            onTap: () => go(context, const AdminParking()),
            trailing: app.pendingParking > 0 ? Pill('${app.pendingParking}', tone: Tone.warn) : null,
          ),
          if (kDemo)
            ListenableBuilder(
              listenable: maint,
              builder: (context, _) => NavTile(
                icon: Icons.handyman_outlined,
                title: 'Maintenance',
                subtitle: '${maint.tasks.length} tasks · ${maint.equipment.length} equipment · ${maint.staff.length} staff',
                onTap: () => go(context, const AdminMaintenance()),
                trailing: maint.overdueCount + maint.dueThisWeekCount > 0
                    ? Pill('${maint.overdueCount + maint.dueThisWeekCount} due', tone: maint.overdueCount > 0 ? Tone.bad : Tone.warn)
                    : null,
              ),
            ),
          NavTile(icon: Icons.bar_chart_rounded, title: 'Reports', subtitle: 'Collections, units, concerns, bookings', onTap: () => go(context, const AdminReports())),
          NavTile(icon: Icons.history_rounded, title: 'Activity log', subtitle: '${app.activityLog.length} recorded', onTap: () => go(context, const AdminActivity())),
        ]),
        NavGroup(label: 'Money and files', children: [
          NavTile(icon: Icons.north_east_rounded, title: 'Expenses', subtitle: '${app.expenses.length} purchases · ${peso(app.spentThisMonth)} this month · monthly report', onTap: () => go(context, const AdminExpenses())),
          NavTile(icon: Icons.lock_outline_rounded, title: 'Finance documents', subtitle: '${app.financeDocs.length} documents · ${app.payments.length} receipts', onTap: () => go(context, const AdminFinanceDocs())),
          NavTile(icon: Icons.folder_copy_outlined, title: 'Community documents', subtitle: '${app.communityDocs.length} files', onTap: () => go(context, const AdminDocs())),
        ]),
        NavGroup(label: 'Administration', children: [
          NavTile(icon: Icons.admin_panel_settings_outlined, title: 'Manage access', subtitle: '${app.trusted.length + 1} accounts', onTap: () => go(context, const AdminAccess())),
          NavTile(icon: Icons.contacts_outlined, title: 'Directory and house rules', subtitle: '${directoryContacts.length} contacts · ${houseRules.length} rules', onTap: () => go(context, const AdminDirectory())),
          NavTile(icon: Icons.settings_outlined, title: 'Settings', subtitle: 'Profile, photo, password, appearance', onTap: () => go(context, const AdminSettings())),
        ]),
        OutlinedButton.icon(
          onPressed: () async {
            if (await confirmDialog(context, 'Log out?', 'You will need to sign in again.', confirm: 'Log out')) session.signOut();
          },
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Log out'),
        ),
      ],
    );
  }
}
