import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly/app/app.dart';
import 'package:nourishly/app/router.dart';
import 'package:nourishly/features/reminders/data/local_notification_scheduler.dart';
import 'package:nourishly/features/reminders/data/reminder_providers.dart';
import 'package:nourishly/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:nourishly/features/food_catalog/data/food_catalog_providers.dart';
import 'package:nourishly/features/food_logging/presentation/screens/food_logging_screen.dart';
import 'package:nourishly/features/goals/presentation/screens/goals_screen.dart';
import 'package:nourishly/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:nourishly/features/profile/presentation/screens/profile_screen.dart';
import 'package:nourishly/features/recipes/presentation/screens/recipes_screen.dart';
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

  setUp(() async {
    db = NourishlyDatabase.forTesting();
    // These tests are about navigation between tabs, so they start where a
    // returning user starts. First-run onboarding has its own test below.
    final ownerId = await ensureDefaultOwner(db);
    await PreferencesDao(db).update(ownerId, onboardingSeen: true);
    // The four slots the catalog import normally seeds. The dashboard's
    // meal rows are one of the ways into the logging flow, and with no
    // slots there are no rows to tap.
    for (final (key, name, order) in const [
      ('breakfast', 'Breakfast', 0),
      ('lunch', 'Lunch', 1),
      ('dinner', 'Dinner', 2),
      ('snack', 'Snack', 3),
    ]) {
      await db
          .into(db.mealSlots)
          .insert(
            MealSlotsCompanion.insert(
              id: 'slot-$key',
              key: key,
              displayName: name,
              sortOrder: order,
            ),
          );
    }
  });
  // Runs even when the test body throws — required so a failed assertion
  // doesn't leak a database into the next test.
  tearDown(() => db.close());

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nourishlyDatabaseProvider.overrideWithValue(db),
          catalogReadyProvider.overrideWith((ref) async {}),
          // No notification plugin answers a widget test, and a screen
          // that needs one is a screen that cannot be tested (§29.3's
          // port exists for exactly this).
          reminderSchedulerProvider.overrideWithValue(NoopReminderScheduler()),
        ],
        child: const NourishlyApp(),
      ),
    );
    await tester.pumpAndSettle();
    // `appRouter` is a top-level global, so its location survives from one
    // test to the next: without this, a test starts wherever the previous
    // one left off rather than where a user starts.
    appRouter.go('/today');
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

  testWidgets('a first run is sent to the welcome once (§27.1)', (
    tester,
  ) async {
    // A fresh profile: no preferences row, so `onboardingSeen` is false.
    final fresh = NourishlyDatabase.forTesting();
    addTearDown(fresh.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nourishlyDatabaseProvider.overrideWithValue(fresh),
          catalogReadyProvider.overrideWith((ref) async {}),
          // No notification plugin answers a widget test, and a screen
          // that needs one is a screen that cannot be tested (§29.3's
          // port exists for exactly this).
          reminderSchedulerProvider.overrideWithValue(NoopReminderScheduler()),
        ],
        child: const NourishlyApp(),
      ),
    );
    // Bounded pumps rather than pumpAndSettle: the redirect happens in a
    // post-frame callback, and the route transition it starts keeps
    // pumpAndSettle going.
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('Set up my profile'), findsOneWidget);
    expect(find.text('Skip for now'), findsOneWidget);

    // Skipping still counts as having seen it — §27.1 makes setup
    // optional, so asking again next launch would be nagging.
    await tester.tap(find.text('Skip for now'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final ownerId = await ensureDefaultOwner(fresh);
    final preferences = await PreferencesDao(fresh).forOwner(ownerId);
    expect(preferences.onboardingSeen, isTrue);
  });

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

  testWidgets('Profile tab opens Settings, which pushes to Goals', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(navLabel('Profile'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    // Prototype 13A's app bar and its three groups. "Goals & targets" is
    // no longer here — it moved to the profile screen with the rest of the
    // profile (2026-09-12 UX revision).
    expect(appBarTitle('Settings'), findsOneWidget);
    expect(find.text('Your recipes'), findsOneWidget);

    appRouter.go('/profile/goals');
    await tester.pumpAndSettle();
    expect(find.byType(GoalsScreen), findsOneWidget);
    expect(appBarTitle('Goals & targets'), findsOneWidget);
  });

  testWidgets('Settings pushes to the profile, and back returns to it', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(navLabel('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Your recipes'));
    await tester.pumpAndSettle();
    expect(find.byType(RecipesScreen), findsOneWidget);

    // Recipes stay in Settings; the profile is its own screen.
    await tester.pageBack();
    await tester.pumpAndSettle();
    appRouter.push('/profile/me');
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(appBarTitle('Profile'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  /// The regression the 2026-09-12 revision was reported for.
  ///
  /// The dashboard's meal rows used `go('/log')`, which replaces the stack:
  /// the logging screen had nothing under it, so its close button popped
  /// nothing, the shell and its nav bar were gone, and the app could not be
  /// navigated again without being killed.
  testWidgets('a meal row opens the log flow and closes back to Today', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.scrollUntilVisible(find.text('Breakfast'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Breakfast'));
    await tester.pumpAndSettle();
    expect(find.byType(FoodLoggingScreen), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(FoodLoggingScreen), findsNothing);
    expect(find.byType(DashboardScreen), findsOneWidget);
    // The nav bar is still there, which is the part that was broken: with
    // the shell replaced, nothing could be reached from here at all.
    expect(navLabel('Water'), findsOneWidget);

    await tester.tap(navLabel('Water'));
    await tester.pumpAndSettle();
    expect(find.byType(WaterScreen), findsOneWidget);
  });
}
