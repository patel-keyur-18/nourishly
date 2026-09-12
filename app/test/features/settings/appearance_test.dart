import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly/app/app.dart';
import 'package:nourishly/app/providers.dart';
import 'package:nourishly/app/router.dart';
import 'package:nourishly/features/food_catalog/data/food_catalog_providers.dart';
import 'package:nourishly/features/reminders/data/local_notification_scheduler.dart';
import 'package:nourishly/features/reminders/data/reminder_providers.dart';
import 'package:nourishly/features/settings/presentation/appearance.dart';
import 'package:nourishly_data/nourishly_data.dart' hide ReminderRule;
import 'package:nourishly_domain/nourishly_domain.dart';

/// FR-S-09 and §27.13: dark mode is not "supported" if nobody can reach
/// it.
///
/// The palette, the theme and the column all existed from Phase 1, and
/// `MaterialApp` read the column correctly — but nothing wrote it, so
/// every profile was pinned to light forever and the dark half of the
/// design system was only ever seen by tests. These assertions run the
/// whole path a person does: open Settings, tap the row, pick a value,
/// and check that the *app* changed rather than just the database.
void main() {
  late NourishlyDatabase db;
  late String ownerId;
  final now = DateTime(2026, 9, 9, 10, 0);

  setUp(() async {
    db = NourishlyDatabase.forTesting();
    ownerId = await ensureDefaultOwner(db);
    await PreferencesDao(db).update(ownerId, onboardingSeen: true);
  });

  tearDown(() => db.close());

  Future<void> pumpSettings(WidgetTester tester) async {
    // Tall enough that the "What you see" group is built: a ListView is
    // lazy, and a row below the fold is not in the tree to be tapped.
    tester.view.physicalSize = const Size(390, 2400) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nourishlyDatabaseProvider.overrideWithValue(db),
          catalogReadyProvider.overrideWith((ref) async {}),
          clockProvider.overrideWithValue(FakeClock(now)),
          reminderSchedulerProvider.overrideWithValue(NoopReminderScheduler()),
        ],
        child: const NourishlyApp(),
      ),
    );
    await tester.pump();
    appRouter.go('/profile');
    await tester.pumpAndSettle();
  }

  ThemeMode themeModeOf(WidgetTester tester) =>
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode!;

  Future<void> choose(WidgetTester tester, String label) async {
    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('the row is there, and starts on Light', (tester) async {
    await pumpSettings(tester);

    expect(find.text('Appearance'), findsOneWidget);
    // §27.14: light is the default, because the palette was drawn
    // light-first and the prototype was approved in it.
    expect(find.text('Light'), findsOneWidget);
    expect(themeModeOf(tester), ThemeMode.light);
  });

  testWidgets('choosing Dark changes the app, not just the row', (
    tester,
  ) async {
    await pumpSettings(tester);
    await choose(tester, 'Dark');

    expect(
      themeModeOf(tester),
      ThemeMode.dark,
      reason: 'the whole app should be in dark mode, not only the label',
    );
    expect(find.text('Dark'), findsWidgets);
  });

  testWidgets('"Match my phone" hands the choice back to the OS', (
    tester,
  ) async {
    await pumpSettings(tester);
    await choose(tester, 'Match my phone');

    expect(themeModeOf(tester), ThemeMode.system);
  });

  testWidgets('the choice survives a restart', (tester) async {
    await pumpSettings(tester);
    await choose(tester, 'Dark');

    // A fresh widget tree against the same database — what relaunching
    // the app amounts to. A preference that only lives in memory would
    // pass every assertion above and still be useless.
    await pumpSettings(tester);
    expect(themeModeOf(tester), ThemeMode.dark);

    final stored = await PreferencesDao(db).forOwner(ownerId);
    expect(stored.theme, 'dark');
  });

  testWidgets('switching back to Light works too', (tester) async {
    await PreferencesDao(db).update(ownerId, theme: 'dark');
    await pumpSettings(tester);
    expect(themeModeOf(tester), ThemeMode.dark);

    await choose(tester, 'Light');
    expect(themeModeOf(tester), ThemeMode.light);
  });

  group('the stored value', () {
    test('maps to the right ThemeMode in both directions', () {
      for (final appearance in Appearance.values) {
        expect(Appearance.fromId(appearance.id), appearance);
      }
      expect(Appearance.light.themeMode, ThemeMode.light);
      expect(Appearance.dark.themeMode, ThemeMode.dark);
      expect(Appearance.system.themeMode, ThemeMode.system);
    });

    test('an unreadable value falls back to light rather than throwing', () {
      // The column can hold a string this build does not know — an import
      // from a newer version, or a hand-edited archive. Refusing to start
      // over a colour scheme would be a poor trade.
      expect(Appearance.fromId('solarized'), Appearance.light);
      expect(Appearance.fromId(null), Appearance.light);
    });
  });
}
