import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nourishly_ui/nourishly_ui.dart';

/// Wraps [StatefulNavigationShell] in the prototype's nav bar (§28.1).
///
/// Branch order must track [_items]' order exactly: Today, Insights,
/// Water, Settings (the `/profile` branch) — the same order the
/// prototype's nav bar renders them in, split around the centre log
/// action.
class NourishlyShell extends StatelessWidget {
  const NourishlyShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  // Labelled "Settings", not "Profile": the tab opens SettingsScreen
  // (app-bar title "Settings"), and the actual profile lives one level
  // deeper at /profile/me, reached from the first row inside Settings
  // (decisions.md, "Screen 13 — the profile is its own screen"). The
  // route path stays /profile — it's the branch's root, covering Goals,
  // Reminders and Data too — only the tab's label and icon change.
  static const _items = [
    NourishlyBottomNavItem(icon: Icons.access_time_rounded, label: 'Today'),
    NourishlyBottomNavItem(icon: Icons.bar_chart_rounded, label: 'Insights'),
    NourishlyBottomNavItem(icon: Icons.water_drop_rounded, label: 'Water'),
    NourishlyBottomNavItem(icon: Icons.settings_rounded, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NourishlyBottomNav(
        items: _items,
        currentIndex: navigationShell.currentIndex,
        // Tapping the already-active tab returns to its root (§28.4: tabs
        // preserve their own navigation stacks, but re-tapping resets —
        // matching both platforms' own tab-bar convention).
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        // Logging opens modally from the centre action and dismisses back
        // to the origin (§28.4) — never a fifth branch.
        onFabPressed: () => context.push('/log'),
      ),
    );
  }
}
