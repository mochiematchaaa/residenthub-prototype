// ADMIN page: Home overview.

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../widgets/widgets.dart';
import 'admin_screens.dart';
import 'pay_check.dart';

/// Administrator dashboard (tab 1).
class AdminHome extends StatelessWidget {
  const AdminHome({super.key});

  @override
  Widget build(BuildContext context) {
    final recent = app.announcements.take(3).toList();
    final upcoming = app.upcomingBookings;
    final settled = app.dues.length - app.unpaidCount;

    return TabPage(
      header: AppHeader(
        initials: initialsOf(app.adminName),
        greeting: 'Hello, ${app.adminFirstName}!',
        photo: app.adminPhoto,
        onAvatar: () => go(context, const AdminSettings()),
        actions: [
          CircleBtn(Icons.search_rounded, tooltip: 'Search', onTap: () => showQuickSearch(context, adminSearchItems(context))),
          CircleBtn(Icons.notifications_none_rounded, badge: app.bellBadge(adminBellItems()), tooltip: 'Needs attention', onTap: () => showAdminAttention(context)),
        ],
      ),
      children: [
        // --- quick actions
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              ActionPill(Icons.calendar_month_rounded, 'Calendar', () => go(context, const CalendarScreen(admin: true))),
              ActionPill(Icons.campaign_outlined, 'Create announcement', () => adminJump(context, 5)),
              ActionPill(Icons.celebration_outlined, 'Add event', () => adminJump(context, 5)),
              ActionPill(Icons.request_quote_outlined, 'Finance', () => adminJump(context, 3)),
              ActionPill(Icons.upload_file_outlined, 'Upload file', () => adminJump(context, 13)),
              ActionPill(Icons.home_work_outlined, 'Unit status', () => adminJump(context, 12)),
            ],
          ),
        ),

        // --- charges that may already be paid: "Did they pay?"
        PayCheckCard(
          limit: 3,
          onOpenAll: () {
            financeTabRequest.value = 'Check';
            adminJump(context, 3);
          },
        ),

        // --- overview
        DashSection(
          title: 'Overview',
          child: Column(
            children: [
              PastelCard(
                color: Pastel.lavender,
                padding: const EdgeInsets.all(20),
                onTap: () => app.setAdminTab(3),
                child: Row(
                  children: [
                    RingGauge(
                      value: app.dues.isEmpty ? 0 : settled / app.dues.length, // empty ring when there are no charges yet
                      size: 124,
                      center: '$settled/${app.dues.length}',
                      caption: 'units settled',
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Dues collection', style: hd(20)),
                          const SizedBox(height: 4),
                          Text('${peso(app.collectedThisMonth)} collected this month', style: const TextStyle(color: inkSoft, fontSize: 13, height: 1.3)),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: () => app.setAdminTab(3),
                            style: FilledButton.styleFrom(
                              backgroundColor: ink,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 40),
                              padding: const EdgeInsets.symmetric(horizontal: 22),
                            ),
                            child: const Text('Check'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              PastelCard(
                color: Pastel.pink,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text('City Residences', style: hd(18))),
                        const GlassIcon(Icons.apartment_rounded, size: 36),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text('Condominium Corporation overview', style: TextStyle(color: inkSoft, fontSize: 12.5)),
                    const SizedBox(height: 18),
                    StatsRow([
                      ['Units', '${app.units.length}'],
                      ['Residents', '${app.trusted.where((a) => a.role == 'Resident').length}'],
                      ['Documents', '${app.communityDocs.length + app.financeDocs.length}'],
                      ['Bookings', '${app.bookings.where((b) => b.status == 'Pending' || b.status == 'Approved').length}'],
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),

        // --- needs attention
        DashSection(
          title: 'Needs attention',
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 0.74,
            children: staggered([
              ImageTile(
                title: 'Unpaid dues',
                metric: '${app.unpaidCount}',
                subtitle: 'units have not settled',
                image: 'assets/images/need_dues.png',
                color: Pastel.coral,
                cta: 'Collect',
                onTap: () => adminJump(context, 3),
              ),
              ImageTile(
                title: 'Pending bookings',
                metric: '${app.pendingBookings}',
                subtitle: 'requests to approve',
                image: 'assets/images/need_bookings.png',
                color: Pastel.peach,
                cta: 'Review',
                onTap: () => adminJump(context, 2),
              ),
              ImageTile(
                title: 'Unit status',
                metric: '${app.newStatusUpdates}',
                subtitle: app.newStatusUpdates == 0 ? 'new updates. All caught up' : 'new update(s) from residents',
                image: 'assets/images/need_units.png',
                color: Pastel.mint,
                cta: 'View',
                onTap: () => adminJump(context, 12),
              ),
              ImageTile(
                title: 'Complaints',
                metric: '${app.openGrievances}',
                subtitle: 'open concern(s)',
                image: 'assets/images/need_grievances.png',
                color: Pastel.sky,
                cta: 'Resolve',
                onTap: () => adminJump(context, 11),
              ),
            ]),
          ),
        ),

        // --- finance
        DashSection(
          title: 'Finance',
          action: 'Open',
          onAction: () => adminJump(context, 3),
          child: RCard(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Earnings trend', style: hd(18))),
                    const Pill('₱ pesos', tone: Tone.info),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  app.totalCollected == 0
                      ? 'No payments recorded yet. The chart fills in as you record payments.'
                      : 'Payments recorded in the last 6 months · ${peso(app.collectedThisMonth)} this month',
                  style: TextStyle(color: muted(context), fontSize: 12),
                ),
                const SizedBox(height: 14),
                SmoothLineChart(
                  values: app.collectionTrend(),
                  labels: app.collectionTrendLabels(),
                  floorAtZero: true,
                  format: (v) => v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : v.round().toString(),
                ),
              ],
            ),
          ),
        ),

        // --- calendar
        const DashSection(title: 'Calendar', child: CalendarCard(admin: true)),

        // --- announcements
        DashSection(
          title: 'Announcements',
          action: 'See all',
          onAction: () => adminJump(context, 5),
          child: RCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                for (final a in recent)
                  ListTile(
                    title: Text(a.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                    subtitle: Text('${a.status} · ${a.date}'),
                    trailing: a.type == 'General' ? null : Pill(a.type, tone: a.type == 'Emergency' ? Tone.bad : Tone.warn),
                  ),
              ],
            ),
          ),
        ),

        // --- upcoming bookings
        DashSection(
          title: 'Upcoming facility bookings',
          action: 'See all',
          onAction: () => adminJump(context, 2),
          child: Column(
            children: [
              if (upcoming.isEmpty)
                RCard(
                  child: Text('No approved or pending bookings right now.', style: TextStyle(color: muted(context), fontSize: 13)),
                ),
              for (var i = 0; i < upcoming.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: PastelCard(
                    color: const [Pastel.butter, Pastel.mint, Pastel.peach][i],
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        GlassIcon(amenityIcon(upcoming[i].place), size: 44),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(upcoming[i].place, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                              Text('${upcoming[i].who} · ${upcoming[i].when}', style: const TextStyle(color: inkSoft, fontSize: 12.5)),
                            ],
                          ),
                        ),
                        Pill(upcoming[i].status, tone: upcoming[i].status == 'Approved' ? Tone.good : Tone.warn),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),

        // --- recent activity
        DashSection(
          title: 'Recent activity',
          child: RCard(
            child: app.activityLog.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text('Nothing yet. Bookings, payments, complaints and announcements appear here as they happen.',
                        style: TextStyle(color: muted(context), fontSize: 13, height: 1.35)),
                  )
                : Column(
                    children: [
                      for (var i = 0; i < app.activityLog.take(6).length; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  margin: const EdgeInsets.only(top: 4),
                                  decoration: const BoxDecoration(color: lavDeep, shape: BoxShape.circle),
                                ),
                                if (i < app.activityLog.take(6).length - 1)
                                  Container(width: 2, height: 30, color: Theme.of(context).colorScheme.outlineVariant),
                              ]),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(app.activityLog[i].title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                                    Text('${app.activityLog[i].area} · ${AppState.ago(app.activityLog[i].at)}',
                                        style: TextStyle(color: muted(context), fontSize: 12)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
