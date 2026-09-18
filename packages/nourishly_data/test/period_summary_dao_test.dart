import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly_data/nourishly_data.dart';
import 'package:nutrition_core/nutrition_core.dart' hide NutrientTarget;

/// End to end over the real schema: days logged, summaries materialised,
/// a week and a month read back out of them.
void main() {
  late NourishlyDatabase db;
  late String ownerId;

  // A fixed Wednesday, so "the week containing this" is a stable answer
  // and a month boundary is not wherever the suite happens to run.
  final wednesday = DateTime(2026, 9, 9);
  final monday = DateTime(2026, 9, 7);
  // Everything is scored as if it were the following month, so no day of
  // the period is still in progress.
  final now = DateTime(2026, 10, 5, 9);

  setUp(() async {
    db = NourishlyDatabase.forTesting();
    ownerId = await ensureDefaultOwner(db);

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
      batch.insert(
        db.mealSlots,
        MealSlotsCompanion.insert(
          id: 'breakfast',
          key: 'breakfast',
          displayName: 'Breakfast',
          sortOrder: 0,
        ),
      );
    });

    await RdaImporter(db).importFromString(
      File('../../app/assets/reference/rda_icmr_nin_2020.json')
          .readAsStringSync(),
    );

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
      effectiveFrom: DateTime(2026, 8, 1),
    );
  });

  tearDown(() => db.close());

  Future<void> logDay(
    DateTime date, {
    double energy = 2000,
    double protein = 95,
    double fibre = 18,
    double waterMl = 2200,
  }) async {
    final key = '${date.year}-${date.month}-${date.day}';
    await db.batch((batch) {
      batch.insert(
        db.foodItems,
        FoodItemsCompanion.insert(
          id: 'food-$key',
          kind: 'dish',
          canonicalName: 'Whole day $key',
          qualityTier: 'verified',
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
          mealSlotId: 'breakfast',
          foodId: 'food-$key',
          foodRevision: 1,
          quantity: 1,
          gramsConsumed: 500,
          loggedAt: date,
          source: 'manual',
        ),
        mode: InsertMode.insertOrReplace,
      );
      for (final entry in {
        'energy': energy,
        'protein': protein,
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
    if (waterMl > 0) {
      await WaterLogDao(db)
          .logWater(ownerId: ownerId, volumeMl: waterMl, logDate: date);
    }
  }

  Future<PeriodSummary> week() =>
      PeriodSummaryDao(db)
          .week(ownerId: ownerId, containing: wednesday, now: now);

  group('date arithmetic', () {
    test('a week runs from the configured start day', () {
      expect(startOfWeek(wednesday, DateTime.monday), monday);
      expect(startOfWeek(wednesday, DateTime.sunday), DateTime(2026, 9, 6));
      // A Monday is already the start of its own Monday-week.
      expect(startOfWeek(monday, DateTime.monday), monday);
    });

    test('a month ends on its own last day, February included', () {
      expect(endOfMonth(DateTime(2026, 9, 9)), DateTime(2026, 9, 30));
      expect(endOfMonth(DateTime(2026, 2, 3)), DateTime(2026, 2, 28));
      expect(
        endOfMonth(DateTime(2028, 2, 3)),
        DateTime(2028, 2, 29),
        reason: 'a leap year, without a table of month lengths',
      );
    });
  });

  test('a week covers all seven days, logged or not', () async {
    await logDay(monday);
    await logDay(monday.add(const Duration(days: 1)));

    final summary = await week();
    expect(summary.start, monday);
    expect(summary.end, monday.add(const Duration(days: 6)));
    expect(summary.calendarDayCount, 7);
    expect(summary.loggedDayCount, 2);
    expect(
      summary.meetsLoggingThreshold,
      isFalse,
      reason: 'two days is below §25.6s threshold',
    );
  });

  test('logged days come back with their stored score and totals', () async {
    for (var i = 0; i < 4; i++) {
      await logDay(monday.add(Duration(days: i)));
    }

    final summary = await week();
    expect(summary.averagedDayCount, 4);
    expect(summary.averageEnergyKcal, closeTo(2000, 1e-9));
    expect(summary.averageWaterMl, closeTo(2200, 1e-9));
    expect(summary.averageScore, isNotNull);
    expect(
      summary.scoreSeries.skip(4).map((p) => p.score),
      everyElement(isNull),
      reason: 'the unlogged tail of the week is a gap',
    );
  });

  test(
    'nutrient averages carry the target that applied and the days met',
    () async {
      for (var i = 0; i < 5; i++) {
        await logDay(monday.add(Duration(days: i)));
      }

      final summary = await week();
      final protein = summary.nutrientAverage('protein')!;
      expect(protein.average, closeTo(95, 1e-9));
      expect(protein.daysAveraged, 5);
      expect(
        protein.targetAmount,
        closeTo(1.2 * 71, 0.01),
        reason: 'the derived target, effective-dated to the day',
      );
      expect(protein.daysMet, 5, reason: '95 g clears the 85.2 g floor');

      final fibre = summary.nutrientAverage('fibre')!;
      expect(fibre.daysMet, 0, reason: '18 g against a 14 g/1,000 kcal floor');
      expect(fibre.daysMissed, 5);
    },
  );

  test('nutrients come back in registry order', () async {
    for (var i = 0; i < 3; i++) {
      await logDay(monday.add(Duration(days: i)));
    }
    expect((await week()).nutrientAverages.map((n) => n.nutrientId), [
      'energy',
      'protein',
      'fibre',
    ]);
  });

  test('a water-only day counts as logged', () async {
    for (var i = 0; i < 3; i++) {
      await logDay(monday.add(Duration(days: i)));
    }
    await WaterLogDao(db).logWater(
      ownerId: ownerId,
      volumeMl: 1500,
      logDate: monday.add(const Duration(days: 5)),
    );

    final summary = await week();
    expect(summary.loggedDayCount, 4);
    final waterOnly = summary.days[5];
    expect(waterOnly.wasLogged, isTrue);
    expect(waterOnly.entryCount, 0);
    expect(waterOnly.waterMl, 1500);
    expect(
      waterOnly.waterTargetMl,
      closeTo(35 * 71 + 150, 0.01),
      reason: 'the derived target still applies to a food-free day',
    );
  });

  test(
    'a day that looks incompletely logged is held out of the averages',
    () async {
      for (var i = 0; i < 4; i++) {
        await logDay(monday.add(Duration(days: i)));
      }
      // The forgotten dinner: a quarter of the target, and no water either.
      await logDay(
        monday.add(const Duration(days: 4)),
        energy: 500,
        protein: 20,
        fibre: 4,
        waterMl: 0,
      );

      final summary = await week();
      expect(summary.loggedDayCount, 5);
      expect(summary.averagedDayCount, 4);
      expect(summary.averageEnergyKcal, closeTo(2000, 1e-9));
      expect(
        summary.daysExcludedAsIncomplete.single.date,
        monday.add(const Duration(days: 4)),
      );
    },
  );

  test('an edit marks the day stale and the next read picks it up', () async {
    for (var i = 0; i < 3; i++) {
      await logDay(monday.add(Duration(days: i)));
    }
    expect((await week()).averageEnergyKcal, closeTo(2000, 1e-9));

    // Log more on the Monday. The write marks it stale; nothing else has
    // to remember to recompute.
    await db
        .into(db.logEntryNutrients)
        .insert(
          LogEntryNutrientsCompanion.insert(
            entryId: 'entry-2026-9-7',
            nutrientId: 'energy',
            amount: 2400,
          ),
          mode: InsertMode.insertOrReplace,
        );
    await DailySummaryDao(db).markStale(ownerId: ownerId, logDate: monday);

    expect(
      (await week()).averageEnergyKcal,
      closeTo((2400 + 2000 + 2000) / 3, 1e-9),
    );
  });

  test('a month spans its own calendar days', () async {
    await logDay(DateTime(2026, 9, 2));
    await logDay(DateTime(2026, 9, 20));
    await logDay(DateTime(2026, 9, 30));
    // Just outside, in both directions.
    await logDay(DateTime(2026, 8, 31));
    await logDay(DateTime(2026, 10, 1));

    final summary = await PeriodSummaryDao(db)
        .month(ownerId: ownerId, containing: wednesday, now: now);

    expect(summary.start, DateTime(2026, 9, 1));
    expect(summary.end, DateTime(2026, 9, 30));
    expect(summary.calendarDayCount, 30);
    expect(summary.loggedDayCount, 3, reason: 'neither neighbour leaks in');
  });

  test(
    'a month with nothing in it writes nothing and averages nothing',
    () async {
      final summary = await PeriodSummaryDao(db)
          .month(ownerId: ownerId, containing: DateTime(2026, 5, 12), now: now);

      expect(summary.loggedDayCount, 0);
      expect(summary.meetsLoggingThreshold, isFalse);
      expect(summary.nutrientAverages, isEmpty);
      expect(
        await db.select(db.dailySummaries).get(),
        isEmpty,
        reason: 'opening an untouched month must not materialise 31 rows',
      );
    },
  );

  test('two months compare through the same engine', () async {
    for (var i = 1; i <= 10; i++) {
      await logDay(DateTime(2026, 8, i), energy: 1800);
    }
    for (var i = 1; i <= 10; i++) {
      await logDay(DateTime(2026, 9, i), energy: 2400);
    }

    final dao = PeriodSummaryDao(db);
    final comparison = PeriodComparison.between(
      current: await dao.month(
        ownerId: ownerId,
        containing: DateTime(2026, 9, 15),
        now: now,
      ),
      previous: await dao.month(
        ownerId: ownerId,
        containing: DateTime(2026, 8, 15),
        now: now,
      ),
    );

    expect(comparison.isAvailable, isTrue);
    expect(comparison.energyKcal!.previous, closeTo(1800, 1e-9));
    expect(comparison.energyKcal!.current, closeTo(2400, 1e-9));
    expect(comparison.energyKcal!.direction, TrendDirection.up);
  });
}
