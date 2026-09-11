import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly/app/app.dart';
import 'package:nourishly/app/router.dart';
import 'package:nourishly/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:nourishly/features/food_catalog/data/food_catalog_providers.dart';
import 'package:nourishly/features/food_logging/presentation/screens/food_logging_screen.dart';
import 'package:nourishly/features/goals/presentation/screens/goals_screen.dart';
import 'package:nourishly/features/reports/presentation/screens/reports_screen.dart';
import 'package:nourishly/features/settings/presentation/screens/settings_screen.dart';
import 'package:nourishly/features/water/presentation/screens/water_screen.dart';
import 'package:nourishly_data/nourishly_data.dart';
import 'package:nourishly_ui/nourishly_ui.dart';

/// Navigation is verified by which screen widget is on stage.
///
/// The tab screens carry their title inline rather than in an [AppBar]
/// (the prototype has no app bar on a root tab), and their titles collide
/// with the nav bar's own labels — so the screen type is both the more
/// robust assertion and the one that survives a copy change. Inactive
/// branches of the shell's `IndexedStack` are `Offstage`, which finders
/// skip by default, so only the visible tab matches.
void main() {
  late NourishlyDatabase db;

  setUp(() => db = NourishlyDatabase.forTesting());
  // Runs even when the test body throws — required so a failed assertion
  // doesn't leak a database into the next test.
  tearDown(() => db.close());

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nourishlyDatabaseProvider.overrideWithValue(db),
          catalogReadyProvider.overrideWith((ref) async {}),
        ],
        child: const NourishlyApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder appBarTitle(String text) =>
      find.descendant(of: find.byType(AppBar), matching: find.text(text));

  /// Scoped to the nav bar: the dashboard now carries its own "Water" row
  /// label, so a bare `find.text('Water')` matches twice.
  Finder navLabel(String text) => find.descendant(
    of: find.byType(NourishlyBottomNav),
    matching: find.text(text),
  );

  testWidgets('starts on Today with all four tabs and the centre action', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(navLabel('Insights'), findsOneWidget);
    expect(navLabel('Water'), findsOneWidget);
    expect(navLabel('Profile'), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
  });

  testWidgets('tapping a nav destination switches the visible tab', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(navLabel('Water'));
    await tester.pumpAndSettle();
    expect(find.byType(WaterScreen), findsOneWidget);
    expect(find.byType(DashboardScreen), findsNothing);

    await tester.tap(navLabel('Insights'));
    await tester.pumpAndSettle();
    expect(find.byType(ReportsScreen), findsOneWidget);

    await tester.tap(navLabel('Today'));
    await tester.pumpAndSettle();
    expect(find.byType(DashboardScreen), findsOneWidget);
  });

  testWidgets(
    'the centre action opens the log flow modally and dismisses back',
    (tester) async {
      await pumpApp(tester);

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(FoodLoggingScreen), findsOneWidget);
      expect(appBarTitle('Add food'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(FoodLoggingScreen), findsNothing);
      expect(find.byType(DashboardScreen), findsOneWidget);
    },
  );

  testWidgets('Profile tab pushes to the nested Goals screen', (tester) async {
    await pumpApp(tester);

    await tester.tap(navLabel('Profile'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('Goals & targets'), findsOneWidget);

    appRouter.go('/profile/goals');
    await tester.pumpAndSettle();
    expect(find.byType(GoalsScreen), findsOneWidget);
    expect(appBarTitle('Goals & targets'), findsOneWidget);
  });
}
