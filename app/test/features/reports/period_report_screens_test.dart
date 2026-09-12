import 'dart:io';

import 'package:drift/drift.dart' show InsertMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly/app/app.dart';
import 'package:nourishly/app/providers.dart';
import 'package:nourishly/app/router.dart';
import 'package:nourishly/features/reminders/data/local_notification_scheduler.dart';
import 'package:nourishly/features/reminders/data/reminder_providers.dart';
import 'package:nourishly/features/food_catalog/data/food_catalog_providers.dart';
import 'package:nourishly/features/reports/presentation/screens/daily_report_screen.dart';
import 'package:nourishly/shared/formatting.dart';
import 'package:nourishly_data/nourishly_data.dart';
import 'package:nourishly_domain/nourishly_domain.dart';
import 'package:nourishly_ui/nourishly_ui.dart';
import 'package:nutrition_core/nutrition_core.dart' hide NutrientTarget;

/// §25.6's rules have to hold in the UI, not only in the engine — the
/// spec says so explicitly. These drive the real screens through the real
/// database and check what actually reaches the glass.
void main() {
  late NourishlyDatabase db;
  late String ownerId;

  // A fixed Sunday in the recent past, so these tests do not depend on
  // what day the suite happens to run:
  //
  // * Sunday is the last day of a Monday-start week, so "N days ago" for
  //   N up to six stays inside the week under test rather than spilling
  //   into the previous one.
  // * Day 15 or later, so ten days back stays inside the same month.
  // * In the real past, so every day counts as finished (§21.5) instead of
  //   still running and therefore unaveraged.
  final today = _anchorSunday();

  setUp(() async {
    db = NourishlyDatabase.forTesting();
    ownerId = await ensureDefaultOwner(db);
    await PreferencesDao(db).update(ownerId, onboardingSeen: true);
    await _seedReference(db);
    await ProfileDao(db).saveProfileAndDeriveTargets(
      ownerId: ownerId,
      inputs: const ProfileInputs(
        ageYears: 34,
        heightCm: 174,
        weightKg: 71,
        activityLevel: ActivityLevel.light,
        biologicalSex: BiologicalSex.male,
      ),
      dateOfBirth: DateTime(1992, 3, 14),
      goal: GoalType.generalHealth,
      effectiveFrom: today.subtract(const Duration(days: 400)),
    );
  });

  tearDown(() => db.close());

  /// A finished day, [back] days ago.
  Future<void> logDay(int back, {double energy = 2000, double fibre = 18}) {
    final date = today.subtract(Duration(days: back));
    final key = 'd$back';
    return db.batch((batch) {
      batch.insert(
        db.foodItems,
        FoodItemsCompanion.insert(
          id: 'food-$key',
          kind: 'dish',
          canonicalName: 'A day of cooking',
          qualityTier: 'derived',
          provenanceSource: 'test',
        ),
        mode: InsertMode.insertOrReplace,
      );
      batch.insert(
        db.foodLogEntries,
        FoodLogEntriesCompanion.insert(
          id: 'entry-$key',
          ownerId: ownerId,
          logDate: date,
          mealSlotId: 'lunch',
          foodId: 'food-$key',
          foodRevision: 1,
          quantity: 1,
          gramsConsumed: 800,
          loggedAt: date,
          source: 'manual',
        ),
        mode: InsertMode.insertOrReplace,
      );
      for (final entry in {
        'energy': energy,
        'protein': 96.0,
        'carbs': 250.0,
        'fat': 62.0,
        'fibre': fibre,
      }.entries) {
        batch.insert(
          db.logEntryNutrients,
          LogEntryNutrientsCompanion.insert(
            entryId: 'entry-$key',
            nutrientId: entry.key,
            amount: entry.value,
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  Future<void> pumpTo(WidgetTester tester, String location) async {
    // A tall window so a whole report is on screen at once. A ListView
    // builds its children lazily, so on a phone-sized test view the
    // sections below the fold are simply not in the tree and nothing can
    // find them.
    tester.view.physicalSize = const Size(390 * 3, 4000 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nourishlyDatabaseProvider.overrideWithValue(db),
          catalogReadyProvider.overrideWith((ref) async {}),
          // No notification plugin answers a widget test, and a screen
          // that needs one is a screen that cannot be tested (§29.3's
          // port exists for exactly this).
          reminderSchedulerProvider.overrideWithValue(
            NoopReminderScheduler(),
          ),
          clockProvider.overrideWithValue(
            FakeClock(today.add(const Duration(hours: 9))),
          ),
        ],
        child: const NourishlyApp(),
      ),
    );
    await tester.pumpAndSettle();
    // appRouter is a module-level singleton, so its location carries over
    // between tests in this file.
    appRouter.go(location);
    await tester.pumpAndSettle();
  }

  group('the weekly report', () {
    testWidgets('under three logged days it shows no averages at all', (
      tester,
    ) async {
      await logDay(1);
      await logDay(2);
      await pumpTo(tester, '/insights/week');

      expect(
        find.textContaining('Averages need at least 3 logged days'),
        findsOneWidget,
      );
      expect(
        find.textContaining('over 2 logged days'),
        findsNothing,
        reason: '§25.6: below the threshold there is no average to state',
      );
    });

    testWidgets('with enough days every average states its denominator', (
      tester,
    ) async {
      for (var back = 1; back <= 4; back++) {
        await logDay(back);
      }
      await pumpTo(tester, '/insights/week');

      expect(find.text('Energy'), findsOneWidget);
      expect(
        find.textContaining('logged days'),
        findsWidgets,
        reason: 'the denominator travels with the number',
      );
      expect(find.textContaining('Averages need at least'), findsNothing);
    });

    testWidgets('a day nobody logged is named rather than left blank', (
      tester,
    ) async {
      for (var back = 1; back <= 4; back++) {
        await logDay(back);
      }
      await pumpTo(tester, '/insights/week');

      // Which days were missed is a fact about the week, and the chart
      // alone cannot say it.
      expect(find.textContaining('not logged'), findsWidgets);
    });

    testWidgets('the energy chart draws one bar per calendar day', (
      tester,
    ) async {
      for (var back = 1; back <= 4; back++) {
        await logDay(back);
      }
      await pumpTo(tester, '/insights/week');

      final chart = tester.widget<DayBarChart>(find.byType(DayBarChart));
      expect(chart.bars, hasLength(7));
      expect(
        chart.bars.where((b) => !b.wasLogged),
        isNotEmpty,
        reason: 'the unlogged days are in the chart, as unlogged days',
      );
      expect(chart.semanticsLabel, isNotNull);
    });

    testWidgets('a week with nothing in it is not a dead end (UX-6)', (
      tester,
    ) async {
      await pumpTo(tester, '/insights/week');

      expect(find.textContaining('Nothing logged this week'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('§27.9s remaining content and actions', () {
    testWidgets('the best day says what it did, not just what it scored', (
      tester,
    ) async {
      // Five ordinary days and one that clears the fibre floor nothing
      // else does. That is the reason the finding should give.
      for (var back = 1; back <= 5; back++) {
        await logDay(back);
      }
      await logDay(6, fibre: 45);
      await pumpTo(tester, '/insights/week');

      expect(find.textContaining('Best day was'), findsOneWidget);
      expect(
        find.textContaining('the only day Fibre was met'),
        findsOneWidget,
        reason: '§27.9 asks for the best day *with reason*',
      );
    });

    testWidgets('the consistency strip covers meals as well as days', (
      tester,
    ) async {
      for (var back = 1; back <= 4; back++) {
        await logDay(back);
      }
      await pumpTo(tester, '/insights/week');

      final grid = tester.widget<MealConsistencyGrid>(
        find.byType(MealConsistencyGrid),
      );
      expect(grid.meals.map((m) => m.label), ['Breakfast', 'Lunch', 'Dinner']);
      expect(
        grid.meals.every((m) => m.logged.length == 7),
        isTrue,
        reason: 'one cell per calendar day, so the gaps show',
      );
      // Everything is logged at lunch in this fixture and nothing at
      // breakfast, which is exactly the pattern the grid exists to show.
      expect(grid.meals[1].logged.where((l) => l).length, 4);
      expect(grid.meals[0].logged.where((l) => l).length, 0);
      expect(find.textContaining('was logged least often'), findsOneWidget);
    });

    testWidgets('tapping a nutrient opens its week', (tester) async {
      for (var back = 1; back <= 4; back++) {
        await logDay(back);
      }
      await pumpTo(tester, '/insights/week');

      await tester.tap(find.text('Protein'));
      await tester.pumpAndSettle();
      // NourishlySectionHeader uppercases its label.
      expect(find.text('ACROSS THE WEEK'), findsOneWidget);
      expect(find.text('DAY BY DAY'), findsOneWidget);
      // Its own chart of the nutrient, not the energy one.
      final chart = tester.widget<DayBarChart>(find.byType(DayBarChart));
      expect(chart.bars, hasLength(7));
      expect(chart.semanticsLabel, contains('Protein'));
    });

    testWidgets('a day with no value for the nutrient shows a dash, not 0', (
      tester,
    ) async {
      for (var back = 1; back <= 4; back++) {
        await logDay(back);
      }
      await pumpTo(tester, '/insights/week/nutrient/protein');

      // AP-4: the unlogged days of the week are em dashes.
      expect(find.text('\u2014'), findsWidgets);
      expect(find.text('0 g'), findsNothing);
    });

    testWidgets('the weekly detail states the coverage it is built on', (
      tester,
    ) async {
      for (var back = 1; back <= 4; back++) {
        await logDay(back);
      }
      await pumpTo(tester, '/insights/week/nutrient/protein');

      expect(find.text('Based on'), findsOneWidget);
      expect(
        find.textContaining('of the energy logged on those days reported it'),
        findsOneWidget,
        reason: '§20.8: an average has to say how much of the day it saw',
      );
    });
  });

  group('the monthly report', () {
    testWidgets(
      'a sparse previous month blocks the comparison, with a reason',
      (tester) async {
        // Enough days this month to average, nothing at all last month.
        for (var back = 1; back <= 6; back++) {
          await logDay(back);
        }
        await pumpTo(tester, '/insights/month');

        // Either the comparison is withheld with its reason, or the month
        // itself is too sparse to say anything — both are honest, and which
        // one depends on where in the month the suite runs.
        expect(find.textContaining('Not enough logged days'), findsWidgets);
        expect(find.text('Not compared'), findsWidgets);
      },
    );

    testWidgets('a logged day can be opened from the month (§27.10)', (
      tester,
    ) async {
      for (var back = 1; back <= 6; back++) {
        await logDay(back);
      }
      await pumpTo(tester, '/insights/month');

      // The chip row is horizontally scrollable and builds lazily, so
      // this picks a day near its start rather than the most recent one.
      final day = today.subtract(const Duration(days: 6));
      await tester.tap(find.widgetWithText(ActionChip, '${day.day}'));
      await tester.pumpAndSettle();

      expect(find.byType(DailyReportScreen), findsOneWidget);
      expect(
        find.text(formatLongDate(day)),
        findsOneWidget,
        reason: 'and it is that day, not merely some day',
      );
    });

    testWidgets('the score chart carries the smoothed line as well', (
      tester,
    ) async {
      for (var back = 1; back <= 10; back++) {
        await logDay(back);
      }
      await pumpTo(tester, '/insights/month');

      final sparkline = tester.widget<Sparkline>(find.byType(Sparkline));
      expect(
        sparkline.smoothed,
        isNotNull,
        reason: '§27.11: the smoothed line is the signal under a noisy month',
      );
      expect(sparkline.semanticsLabel, isNotNull);
    });
  });

  group('the insights hub', () {
    testWidgets('offers the week and the month, with their denominators', (
      tester,
    ) async {
      await logDay(1);
      await pumpTo(tester, '/insights');

      expect(find.text('REPORTS'), findsOneWidget);
      expect(find.textContaining('days logged'), findsWidgets);
    });

    testWidgets('tapping through to the week keeps the bottom nav', (
      tester,
    ) async {
      await logDay(1);
      await pumpTo(tester, '/insights');
      await tester.tap(find.textContaining('Week of'));
      await tester.pumpAndSettle();

      expect(find.byType(DayBarChart), findsOneWidget);
      expect(
        find.byType(NourishlyBottomNav),
        findsOneWidget,
        reason: 'the prototype keeps the nav on 10A; only 9C covers it',
      );
    });
  });
}

Future<void> _seedReference(NourishlyDatabase db) async {
  await db.batch((batch) {
    batch.insert(
      db.nutrientGroups,
      NutrientGroupsCompanion.insert(
        id: 'macronutrients',
        name: 'Macronutrients',
        sortOrder: 0,
      ),
    );
    var order = 0;
    for (final (id, name, unit, curve) in const [
      ('energy', 'Energy', 'kcal', 'range'),
      ('protein', 'Protein', 'g', 'floor'),
      ('carbs', 'Carbohydrate', 'g', 'range'),
      ('fat', 'Total fat', 'g', 'range'),
      ('fibre', 'Dietary fibre', 'g', 'floor'),
    ]) {
      batch.insert(
        db.nutrients,
        NutrientsCompanion.insert(
          id: id,
          groupId: 'macronutrients',
          displayName: name,
          canonicalUnit: unit,
          displayPrecision: 0,
          defaultCurveType: curve,
          isLimitNutrient: false,
          sortOrder: order++,
          isCore: true,
          minCoverageForScoring: 0.6,
        ),
      );
    }
    var slot = 0;
    for (final (id, name) in const [
      ('breakfast', 'Breakfast'),
      ('lunch', 'Lunch'),
      ('dinner', 'Dinner'),
    ]) {
      batch.insert(
        db.mealSlots,
        MealSlotsCompanion.insert(
          id: id,
          key: id,
          displayName: name,
          sortOrder: slot++,
        ),
      );
    }
  });

  await RdaImporter(db).importFromString(
    File('assets/reference/rda_icmr_nin_2020.json').readAsStringSync(),
  );
}

/// The most recent Sunday, at least eight days back and on the 15th of its
/// month or later. See the note where it is used.
DateTime _anchorSunday() {
  final now = DateTime.now();
  var day = DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(const Duration(days: 8));
  while (day.weekday != DateTime.sunday || day.day < 15) {
    day = day.subtract(const Duration(days: 1));
  }
  return day;
}
