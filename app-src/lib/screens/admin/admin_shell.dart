// ignore_for_file: prefer_const_constructors
//
// The tab pages are deliberately created WITHOUT `const` inside build():
// a const widget is identical on every rebuild, so Flutter would skip it and
// the tab would not refresh after the shared AppState changes.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../widgets/widgets.dart';
import 'admin_screens.dart';

/// Administrator app frame: five tabs + the floating pill navigation bar.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  Timer? _auto;

  /// Posts the payments that matched their charge and waited long enough. In a live system this runs on the server.
  void _autoPost() {
    final n = app.autoPostCheck();
    if (n > 0 && mounted) msg(context, '$n payment${n == 1 ? ' was' : 's were'} posted automatically.');
    final late = app.autoLateFeeCheck();
    if (late > 0 && mounted) msg(context, '$late late charge${late == 1 ? ' was' : 's were'} added automatically. Residents were notified.');
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoPost());
    _auto = Timer.periodic(const Duration(seconds: 30), (_) => _autoPost());
  }

  @override
  void dispose() {
    _auto?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final pages = <Widget>[
          AdminHome(),
          AdminUnits(),
          AdminFacility(),
          AdminFinance(),
          AdminMore(),
        ];
        final moreBadge = app.openGrievances + app.newStatusUpdates;
        return BuildingBackdrop(
          child: Scaffold(
          backgroundColor: Colors.transparent,
          extendBody: true,
          body: SafeArea(
            bottom: false,
            child: IndexedStack(
              index: app.adminTab,
              children: [for (var i = 0; i < pages.length; i++) TabFadeIn(active: app.adminTab == i, child: pages[i])],
            ),
          ),
          bottomNavigationBar: FloatingNav(
            index: app.adminTab,
            onTap: app.setAdminTab,
            items: [
              const NavItem(Icons.dashboard_outlined, Icons.dashboard_rounded, 'Home'),
              const NavItem(Icons.apartment_outlined, Icons.apartment_rounded, 'Units'),
              NavItem(Icons.event_available_outlined, Icons.event_available_rounded, 'Facility', badge: app.pendingBookings),
              NavItem(Icons.payments_outlined, Icons.payments_rounded, 'Finance', badge: app.unpaidCount),
              NavItem(Icons.grid_view_outlined, Icons.grid_view_rounded, 'More', badge: moreBadge),
            ],
          ),
          ),
        );
      },
    );
  }
}
