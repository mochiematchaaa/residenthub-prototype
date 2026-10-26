// RESIDENT page: Home.

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../widgets/widgets.dart';
import 'resident_screens.dart';

/// Resident dashboard (tab 1).
class ResHome extends StatelessWidget {
  const ResHome({super.key});

  @override
  Widget build(BuildContext context) {
    final me = app.me!;
    final first = me.name.split(' ').first;
    final rows = app.myDueRows;
    final paid = rows.where((d) => d.status == 'Paid').length;
    final unpaid = rows.length - paid;
    final posts = app.myAnnouncements.take(3).toList();
    final emergency = app.myAnnouncements.where((a) => a.type == 'Emergency').toList();
    final rec = app.myUnitRec;
    final upcoming = app.upcomingBooking;
    final openGr = app.myGrievances.where((g) => g.stage < 2).length;
    final pendingBk = app.myBookings.where((b) => b.status == 'Pending').length;

    return TabPage(
      header: AppHeader(
        initials: initialsOf(me.name),
        photo: me.photo,
        greeting: 'Hello, $first!',
        onAvatar: () => go(context, const ResSettings()),
        actions: [
          CircleBtn(Icons.search_rounded, tooltip: 'Search', onTap: () => showQuickSearch(context, _searchItems(context))),
          CircleBtn(Icons.notifications_none_rounded, dot: true, tooltip: 'Notifications', onTap: () => showResNotifications(context)),
        ],
      ),
      children: [
        for (final e in emergency)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFFF9F9F), borderRadius: BorderRadius.circular(26)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded, color: ink),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: e.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                      TextSpan(text: ' — ${e.body}'),
                    ]),
                    style: const TextStyle(color: ink, height: 1.35),
                  ),
                ),
              ],
            ),
          ),

        // --- quick actions
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              ActionPill(Icons.calendar_month_rounded, 'Calendar', () => go(context, const CalendarScreen(admin: false))),
              ActionPill(Icons.pool_rounded, 'Book', () => app.setResTab(1)),
              ActionPill(Icons.report_gmailerrorred_rounded, 'Report concern', () => go(context, const ResGrievances())),
              ActionPill(Icons.how_to_vote_outlined, 'Polls', () => go(context, const ResPolls())),
              ActionPill(Icons.celebration_outlined, 'Events', () => go(context, const ResEvents())),
              ActionPill(Icons.contacts_outlined, 'Directory', () => go(context, const ResDirectory())),
              ActionPill(Icons.folder_open_rounded, 'Documents', () => go(context, const ResDocuments())),
              ActionPill(Icons.event_note_rounded, 'My reservations', () => go(context, const ResReservations())),
            ],
          ),
        ),

        // --- overview
        DashSection(
          title: 'Overview',
          child: PastelCard(
            color: Pastel.lavender,
            padding: const EdgeInsets.all(20),
            onTap: () => app.setResTab(3),
            child: Row(
              children: [
                RingGauge(
                  value: rows.isEmpty ? 0 : paid / rows.length, // empty ring when there are no charges yet
                  size: 124,
                  center: '$paid/${rows.length}',
                  caption: 'months paid',
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your dues', style: hd(20)),
                      const SizedBox(height: 4),
                      Text(
                        rows.isEmpty ? 'No charges yet.' : unpaid == 0 ? 'All settled. Thank you!' : '${peso(app.myBalance)} due now',
                        style: const TextStyle(color: inkSoft, fontSize: 13, height: 1.3),
                      ),
                      const SizedBox(height: 4),
                      Text(app.myUnit, style: const TextStyle(color: inkSoft, fontSize: 12.5, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => app.setResTab(3),
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
        ),

        // --- quick access tiles
        DashSection(
          title: 'Quick access',
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 0.95,
            children: staggered([
                FeatureTile(
                  title: 'Book a facility',
                  metric: pendingBk > 0 ? '$pendingBk' : 'Open',
                  subtitle: pendingBk > 0 ? 'request(s) waiting for approval' : 'Pool, hall and more',
                  icon: Icons.pool_rounded,
                  color: Pastel.peach,
                  cta: 'Book now',
                  onTap: () => app.setResTab(1),
                ),
                FeatureTile(
                  title: 'Documents',
                  metric: '${app.communityDocs.length}',
                  subtitle: 'House rules, forms and minutes',
                  icon: Icons.folder_copy_outlined,
                  color: Pastel.mint,
                  cta: 'Browse',
                  onTap: () => go(context, const ResDocuments()),
                ),
                FeatureTile(
                  title: 'Grievances',
                  metric: '$openGr',
                  subtitle: openGr == 0 ? 'open concerns. All clear' : 'open concern(s) being handled',
                  icon: Icons.edit_note_rounded,
                  color: Pastel.butter,
                  cta: openGr == 0 ? 'Report one' : 'Track',
                  onTap: () => go(context, const ResGrievances()),
                ),
                FeatureTile(
                  title: 'Motor parking',
                  metric: app.slotOf(app.myUnit)?.id ?? (app.parkingRequested ? 'Pending' : 'None'),
                  subtitle: app.slotOf(app.myUnit) != null ? 'is your parking slot' : (app.parkingRequested ? 'request waiting for the office' : 'Request a slot for your motorcycle'),
                  icon: Icons.two_wheeler_rounded,
                  color: Pastel.mint,
                  cta: app.slotOf(app.myUnit) != null ? 'View' : 'Open',
                  onTap: () => app.setResTab(2),
                ),
                FeatureTile(
                  title: 'Unit status',
                  metric: statusOf(rec?.usage ?? 'owner').shortLabel,
                  subtitle: rec == null || rec.statusDate.isEmpty ? 'Tell the admin about your unit' : 'Updated ${rec.statusDate}',
                  icon: statusOf(rec?.usage ?? 'owner').icon,
                  color: Pastel.sky,
                  cta: 'Update',
                  onTap: () => go(context, const ResUnitStatus()),
                ),
            ]),
          ),
        ),

        // --- my unit
        DashSection(
          title: 'My unit',
          child: Column(
            children: [
              PastelCard(
                color: Pastel.pink,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text('Your unit at a glance', style: hd(18))),
                        GlassIcon(Icons.home_rounded, size: 36),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('${app.myUnit} · ${app.myHousehold}', style: const TextStyle(color: inkSoft, fontSize: 12.5)),
                    const SizedBox(height: 18),
                    StatsRow([
                      ['Open dues', '$unpaid'],
                      ['Bookings', '${app.myBookings.where((b) => b.status == 'Approved' || b.status == 'Pending').length}'],
                      ['Documents', '${app.communityDocs.length}'],
                      ['Concerns', '$openGr'],
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              PastelCard(
                color: Pastel.butter,
                onTap: () => go(context, const ResReservations()),
                child: Row(
                  children: [
                    const GlassIcon(Icons.event_available_rounded, size: 48),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Upcoming reservation', style: TextStyle(color: inkSoft, fontSize: 12.5, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(upcoming == null ? 'Nothing booked yet' : upcoming.place, style: hd(17)),
                          if (upcoming != null) Text('${upcoming.when} · ${upcoming.status}', style: const TextStyle(color: inkSoft, fontSize: 12.5)),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_rounded),
                  ],
                ),
              ),
            ],
          ),
        ),

        // --- calendar
        const DashSection(title: 'Calendar', child: CalendarCard(admin: false)),

        // --- announcements
        DashSection(
          title: 'Announcements',
          child: Column(
            children: [
              if (posts.isEmpty)
                RCard(child: Text('No announcements yet.', style: TextStyle(color: muted(context), fontSize: 13))),
              for (final p in posts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: RCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IconBadge(
                          p.type == 'Emergency'
                              ? Icons.warning_amber_rounded
                              : p.type == 'Maintenance' || p.type == 'Warning'
                                  ? Icons.build_circle_outlined
                                  : Icons.campaign_outlined,
                          tone: p.type == 'Emergency'
                              ? Tone.bad
                              : p.type == 'General'
                                  ? Tone.info
                                  : Tone.warn,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Expanded(child: Text(p.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
                                if (p.type != 'General') Pill(p.type, tone: p.type == 'Emergency' ? Tone.bad : Tone.warn),
                              ]),
                              const SizedBox(height: 3),
                              Text(p.body, style: TextStyle(color: muted(context), fontSize: 13, height: 1.4)),
                              const SizedBox(height: 6),
                              Text('${p.date}${p.sms ? '  ·  Texted to residents' : ''}', style: TextStyle(color: muted(context), fontSize: 11.5)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),

        // --- community events
        DashSection(
          title: 'Community events',
          child: SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: app.events.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (c, i) {
                final e = app.events[i];
                const colors = [Pastel.mint, Pastel.sky, Pastel.peach, Pastel.lavender, Pastel.butter];
                return SizedBox(
                  width: 208,
                  child: PastelCard(
                    color: colors[i % colors.length],
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const GlassIcon(Icons.celebration_outlined, size: 34),
                        Text(e.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        Text(e.date, style: const TextStyle(color: inkSoft, fontSize: 12)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  List<SearchItem> _searchItems(BuildContext context) => [
        SearchItem('Calendar', 'Events, bookings and due dates', Icons.calendar_month_rounded, () => go(context, const CalendarScreen(admin: false))),
        SearchItem('Book a facility', 'Pool, function hall and other amenities', Icons.pool_rounded, () => app.setResTab(1)),
        SearchItem('Dues & payment', 'Balance, payments and receipts', Icons.account_balance_wallet_rounded, () => app.setResTab(3)),
        SearchItem('Motor parking', 'Your slot, request and free slots', Icons.two_wheeler_rounded, () => app.setResTab(2)),
        SearchItem('My reservations', 'Booking requests and status', Icons.event_note_rounded, () => go(context, const ResReservations())),
        SearchItem('Grievances', 'Report or track a concern', Icons.edit_note_rounded, () => go(context, const ResGrievances())),
        SearchItem('Polls & voting', 'Vote on community decisions', Icons.how_to_vote_outlined, () => go(context, const ResPolls())),
        SearchItem('Events', 'Upcoming events, RSVP', Icons.celebration_outlined, () => go(context, const ResEvents())),
        SearchItem('Directory & house rules', 'Contacts, rules, FAQ', Icons.contacts_outlined, () => go(context, const ResDirectory())),
        SearchItem('Documents', 'House rules, forms, minutes', Icons.folder_copy_outlined, () => go(context, const ResDocuments())),
        SearchItem('Unit status', 'Declare how your unit is used', Icons.home_work_rounded, () => go(context, const ResUnitStatus())),
        SearchItem('Settings', 'Profile, password, dark mode, devices', Icons.settings_outlined, () => go(context, const ResSettings())),
      ];
}
