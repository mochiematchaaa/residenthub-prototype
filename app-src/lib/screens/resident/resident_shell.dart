// ignore_for_file: prefer_const_constructors
//
// The tab pages are deliberately created WITHOUT `const` inside build():
// a const widget is identical on every rebuild, so Flutter would skip it and
// the tab would not refresh after the shared AppState changes.
import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../widgets/widgets.dart';
import 'reminder_popup.dart';
import 'resident_screens.dart';

/// Resident app frame: five tabs + the floating pill navigation bar.
class ResidentShell extends StatefulWidget {
  const ResidentShell({super.key});

  @override
  State<ResidentShell> createState() => _ResidentShellState();
}

class _ResidentShellState extends State<ResidentShell> {
  int _lastTab = -1;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        // Every time the resident lands on the home page (signing in, or coming back to the Home tab), show the due reminders.
        if (app.resTab != _lastTab) {
          _lastTab = app.resTab;
          if (_lastTab == 0) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) showReminderPopup(context);
            });
          }
        }
        final pages = <Widget>[
          ResHome(),
          ResBook(),
          ResParking(tab: true),
          ResDues(),
          ResMore(),
        ];
        return BuildingBackdrop(
          child: Scaffold(
          backgroundColor: Colors.transparent,
          extendBody: true,
          body: SafeArea(
            bottom: false,
            child: IndexedStack(
              index: app.resTab,
              children: [for (var i = 0; i < pages.length; i++) TabFadeIn(active: app.resTab == i, child: pages[i])],
            ),
          ),
          bottomNavigationBar: FloatingNav(
            index: app.resTab,
            onTap: app.setResTab,
            items: [
              const NavItem(Icons.home_outlined, Icons.home_rounded, 'Home'),
              const NavItem(Icons.event_available_outlined, Icons.event_available_rounded, 'Book'),
              NavItem(Icons.local_parking_outlined, Icons.local_parking_rounded, 'Parking',
                  badge: app.freeSlotCount),
              NavItem(Icons.account_balance_wallet_outlined, Icons.account_balance_wallet_rounded, 'Dues',
                  badge: app.myDueRows.where((d) => d.status != 'Paid').length),
              const NavItem(Icons.grid_view_outlined, Icons.grid_view_rounded, 'More'),
            ],
          ),
          ),
        );
      },
    );
  }
}
