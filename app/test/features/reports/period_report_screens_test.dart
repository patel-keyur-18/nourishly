import 'dart:io';

import 'package:drift/drift.dart' show InsertMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly/app/app.dart';
import 'package:nourishly/app/router.dart';
import 'package:nourishly/app/providers.dart';
import 'package:nourishly/features/food_catalog/data/food_catalog_providers.dart';
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
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nourishlyDatabaseProvider.overrideWithValue(db),
          catalogReadyProvider.overrideWith((ref) async {}),
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
