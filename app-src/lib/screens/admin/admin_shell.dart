// ignore_for_file: prefer_const_constructors
//
// The tab pages are deliberately created WITHOUT `const` inside build():
// a const widget is identical on every rebuild, so Flutter would skip it and
// the tab would not refresh after the shared AppState changes.
import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../widgets/widgets.dart';
import 'admin_screens.dart';

/// Administrator app frame: five tabs + the floating pill navigation bar.
class AdminShell extends StatelessWidget {
  const AdminShell({super.key});

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
