import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly_ui/nourishly_ui.dart';

void main() {
  const items = [
    NourishlyBottomNavItem(icon: Icons.access_time_rounded, label: 'Today'),
    NourishlyBottomNavItem(icon: Icons.bar_chart_rounded, label: 'Insights'),
    NourishlyBottomNavItem(icon: Icons.water_drop_rounded, label: 'Water'),
    NourishlyBottomNavItem(icon: Icons.person_rounded, label: 'Profile'),
  ];

  Widget harness({
    required int currentIndex,
    required ValueChanged<int> onSelected,
    required VoidCallback onFab,
  }) {
    return MaterialApp(
      theme: NourishlyTheme.light(),
      home: Scaffold(
        bottomNavigationBar: NourishlyBottomNav(
          items: items,
          currentIndex: currentIndex,
          onDestinationSelected: onSelected,
          onFabPressed: onFab,
        ),
      ),
    );
  }

  testWidgets('renders all four destination labels', (tester) async {
    await tester.pumpWidget(
      harness(currentIndex: 0, onSelected: (_) {}, onFab: () {}),
    );

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Insights'), findsOneWidget);
    expect(find.text('Water'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });

  testWidgets('tapping a destination reports its index', (tester) async {
    int? tapped;
    await tester.pumpWidget(
      harness(currentIndex: 0, onSelected: (i) => tapped = i, onFab: () {}),
    );

    await tester.tap(find.text('Water'));
    expect(tapped, 2);
  });

  testWidgets(
    'tapping the centre action calls onFabPressed, not onDestinationSelected',
    (tester) async {
      var fabTapped = false;
      var destinationTapped = false;
      await tester.pumpWidget(
        harness(
          currentIndex: 0,
          onSelected: (_) => destinationTapped = true,
          onFab: () => fabTapped = true,
        ),
      );

      await tester.tap(find.byIcon(Icons.add_rounded));
      expect(fabTapped, isTrue);
      expect(destinationTapped, isFalse);
    },
  );

  testWidgets('the current index renders in the accent colour', (tester) async {
    await tester.pumpWidget(
      harness(currentIndex: 2, onSelected: (_) {}, onFab: () {}),
    );

    final icon = tester.widget<Icon>(find.byIcon(Icons.water_drop_rounded));
    expect(icon.color, NourishlyLightColors.accent);

    final inactiveIcon = tester.widget<Icon>(
      find.byIcon(Icons.access_time_rounded),
    );
    expect(inactiveIcon.color, NourishlyLightColors.ink3);
  });

  // Regression: `Scaffold` lays its `bottomNavigationBar` out with loose
  // constraints whose maxHeight is the whole screen. An unbounded-height
  // child in here (an `Align`/`Center`, a `Spacer`) therefore expands to
  // fill the screen, and the body collapses to nothing — which is exactly
  // how every tab rendered blank with the nav bar floating mid-screen.
  testWidgets('takes only its own height, never the whole screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: NourishlyTheme.light(),
        home: Scaffold(
          body: const Center(child: Text('body')),
          bottomNavigationBar: NourishlyBottomNav(
            items: const [
              NourishlyBottomNavItem(
                icon: Icons.access_time_rounded,
                label: 'Today',
              ),
              NourishlyBottomNavItem(
                icon: Icons.bar_chart_rounded,
                label: 'Insights',
              ),
              NourishlyBottomNavItem(
                icon: Icons.water_drop_rounded,
                label: 'Water',
              ),
              NourishlyBottomNavItem(
                icon: Icons.person_rounded,
                label: 'Profile',
              ),
            ],
            currentIndex: 0,
            onDestinationSelected: (_) {},
            onFabPressed: () {},
          ),
        ),
      ),
    );

    final screenHeight = tester.getSize(find.byType(Scaffold)).height;
    final navHeight = tester.getSize(find.byType(NourishlyBottomNav)).height;

    expect(navHeight, lessThan(screenHeight / 4));
    // The body must keep the rest of the screen.
    expect(
      tester.getSize(find.text('body')).height,
      greaterThan(0),
    );
    expect(
      tester.getBottomLeft(find.byType(NourishlyBottomNav)).dy,
      moreOrLessEquals(screenHeight, epsilon: 0.5),
    );
  });
}
