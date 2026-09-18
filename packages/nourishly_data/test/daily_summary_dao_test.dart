import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly_data/nourishly_data.dart';
import 'package:nutrition_core/nutrition_core.dart' hide NutrientTarget;

/// End to end over the real schema: profile in, targets derived, food
/// logged, day aggregated, scored and cached.
void main() {
  late NourishlyDatabase db;
  late String ownerId;

  final yesterday = dateOnly(DateTime.now().subtract(const Duration(days: 1)));

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
      batch.insert(
        db.nutrientGroups,
        NutrientGroupsCompanion.insert(
          id: 'minerals',
          name: 'Minerals',
          sortOrder: 1,
        ),
      );
      var order = 0;
      for (final (id, name, unit, curve) in const [
        ('energy', 'Energy', 'kcal', 'range'),
        ('protein', 'Protein', 'g', 'floor'),
        ('fibre', 'Dietary fibre', 'g', 'floor'),
        ('iron', 'Iron', 'mg', 'plateau'),
      ]) {
        batch.insert(
          db.nutrients,
          NutrientsCompanion.insert(
            id: id,
            groupId: id == 'iron' ? 'minerals' : 'macronutrients',
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
      batch.insert(
        db.mealSlots,
        MealSlotsCompanion.insert(
          id: 'dinner',
          key: 'dinner',
          displayName: 'Dinner',
          sortOrder: 3,
        ),
      );
    });

    await RdaImporter(db).importFromString(
      File('../../app/assets/reference/rda_icmr_nin_2020.json')
          .readAsStringSync(),
    );
  });

  tearDown(() => db.close());

  Future<void> logFood({
    required String name,
    required Map<String, double> per100g,
    required double grams,
    String slot = 'breakfast',
    DateTime? on,
  }) async {
    final foodId = 'food-${name.hashCode}';
    final servingId = 'serving-${name.hashCode}';
    final entryId = 'entry-${name.hashCode}-${on?.day ?? 0}-$slot';
    await db.batch((batch) {
      batch.insert(
        db.foodItems,
        FoodItemsCompanion.insert(
          id: foodId,
          kind: 'ingredient',
          canonicalName: name,
          qualityTier: 'verified',
          provenanceSource: 'usda_fdc',
        ),
        mode: InsertMode.insertOrReplace,
      );
      batch.insert(
        db.servingSizes,
        ServingSizesCompanion.insert(
          id: servingId,
          foodId: foodId,
          label: '100 g',
          grams: 100,
        ),
        mode: InsertMode.insertOrReplace,
      );
      batch.insert(
        db.foodLogEntries,
        FoodLogEntriesCompanion.insert(
          id: entryId,
          ownerId: ownerId,
          logDate: on ?? yesterday,
          mealSlotId: slot,
          foodId: foodId,
          foodRevision: 1,
          servingSizeId: Value(servingId),
          quantity: grams / 100,
          gramsConsumed: grams,
          loggedAt: on ?? yesterday,
          source: 'manual',
        ),
        mode: InsertMode.insertOrReplace,
      );
      for (final entry in per100g.entries) {
        batch.insert(
          db.logEntryNutrients,
          LogEntryNutrientsCompanion.insert(
            entryId: entryId,
            nutrientId: entry.key,
            amount: entry.value * grams / 100,
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  Future<void> setUpProfile({
    GoalType goal = GoalType.generalHealth,
    DateTime? from,
  }) async {
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
      goal: goal,
      effectiveFrom: from ?? yesterday.subtract(const Duration(days: 7)),
    );
  }

  test('targets are derived and stored, water included', () async {
    await setUpProfile();
    final set = await ProfileDao(db).targetSetOn(ownerId, yesterday);
    final targets = await ProfileDao(db).targetsIn(set!.id);

    expect(targets['energy']!.amount, closeTo(1632.5 * 1.375, 0.01));
    expect(targets['protein']!.amount, closeTo(1.2 * 71, 0.01));
    expect(targets['water']!.amount, closeTo(35 * 71 + 150, 0.01));
    expect(
      targets['iron']!.amount,
      19,
      reason: 'from the ICMR-NIN table, adult male',
    );
    expect(targets['iron']!.upperLimit, 45);
  });

  test('a female profile picks the sex-specific iron reference', () async {
    await ProfileDao(db).saveProfileAndDeriveTargets(
      ownerId: ownerId,
      inputs: const ProfileInputs(
        ageYears: 34,
        heightCm: 160,
        weightKg: 58,
        activityLevel: ActivityLevel.light,
        biologicalSex: BiologicalSex.female,
      ),
      dateOfBirth: DateTime(1992, 3, 14),
      goal: GoalType.generalHealth,
      effectiveFrom: yesterday,
    );
    final set = await ProfileDao(db).targetSetOn(ownerId, yesterday);
    final targets = await ProfileDao(db).targetsIn(set!.id);
    expect(targets['iron']!.amount, 29);
  });

  test('a day aggregates, scores, and caches', () async {
    await setUpProfile();
    await logFood(
      name: 'Thepla',
      per100g: {'energy': 300, 'protein': 8, 'fibre': 4, 'iron': 3},
      grams: 200,
    );
    await logFood(
      name: 'Gujarati dal',
      per100g: {'energy': 90, 'protein': 5, 'fibre': 3, 'iron': 2},
      grams: 400,
      slot: 'dinner',
    );

    final summary = await DailySummaryDao(db)
        .summaryFor(ownerId: ownerId, logDate: yesterday);

    expect(summary.totalEnergyKcal, closeTo(600 + 360, 0.01));
    expect(summary.entryCount, 2);
    expect(summary.nutrient('protein')!.amount, closeTo(16 + 20, 0.01));
    expect(summary.nutrient('protein')!.coverage, 1.0);
    expect(summary.meals.firstWhere((m) => m.slotKey == 'dinner').itemNames, [
      'Gujarati dal',
    ]);
    expect(
      summary.score.withheldReason,
      isNull,
      reason: 'a past day with plausible energy is scored',
    );
    expect(summary.score.composite, isNotNull);
    expect(summary.insights, isNotEmpty);

    // The point of the cache: the summary row exists and is not stale.
    final rows = await db.select(db.dailySummaries).get();
    expect(rows, hasLength(1));
    expect(rows.single.isStale, isFalse);
  });

  test(
    'logging again marks the day stale and the next read rebuilds it',
    () async {
      await setUpProfile();
      await logFood(
        name: 'Thepla',
        per100g: {'energy': 300, 'protein': 8},
        grams: 200,
      );
      final first = await DailySummaryDao(db)
          .summaryFor(ownerId: ownerId, logDate: yesterday);
      expect(first.totalEnergyKcal, closeTo(600, 0.01));

      await logFood(
        name: 'Rice',
        per100g: {'energy': 130, 'protein': 3},
        grams: 300,
        slot: 'dinner',
      );
      await DailySummaryDao(db).markStale(ownerId: ownerId, logDate: yesterday);

      final second = await DailySummaryDao(db)
          .summaryFor(ownerId: ownerId, logDate: yesterday);
      expect(second.totalEnergyKcal, closeTo(600 + 390, 0.01));
      expect(second.entryCount, 2);
    },
  );

  test(
    'an unmeasured food lowers coverage without lowering the amount',
    () async {
      await setUpProfile();
      // A big entry reporting only energy — a custom food with partial data,
      // which is exactly what §21.5 says usually causes this.
      await logFood(name: 'Mithai', per100g: {'energy': 400}, grams: 250);
      await logFood(
        name: 'Dal',
        per100g: {'energy': 90, 'protein': 5, 'fibre': 3, 'iron': 2},
        grams: 300,
        slot: 'dinner',
      );

      final summary = await DailySummaryDao(db)
          .summaryFor(ownerId: ownerId, logDate: yesterday);

      final protein = summary.nutrient('protein')!;
      expect(
        protein.amount,
        closeTo(15, 0.01),
        reason: 'only the dal reports it',
      );
      expect(
        protein.coverage,
        closeTo(270 / (1000 + 270), 1e-6),
        reason: 'energy-weighted, not entry-counted',
      );
      expect(protein.status, NutrientStatus.insufficientData);
    },
  );

  test('today is not scored — the dashboard shows progress instead', () async {
    await setUpProfile(from: dateOnly(DateTime.now()));
    await logFood(
      name: 'Poha',
      per100g: {'energy': 180, 'protein': 4},
      grams: 300,
      on: dateOnly(DateTime.now()),
    );
    final summary = await DailySummaryDao(db)
        .summaryFor(ownerId: ownerId, logDate: DateTime.now());
    expect(summary.score.withheldReason, ScoreWithheldReason.dayIncomplete);
    expect(summary.score.composite, isNull);
    expect(summary.energyRemainingKcal, isNotNull);
  });

  test('a day with no entries reads as empty rather than failing', () async {
    await setUpProfile();
    final summary = await DailySummaryDao(db)
        .summaryFor(ownerId: ownerId, logDate: yesterday);
    expect(summary.entryCount, 0);
    expect(summary.hasAnything, isFalse);
    expect(summary.meals, hasLength(2));
    expect(summary.meals.every((m) => m.isEmpty), isTrue);
    expect(summary.score.withheldReason, ScoreWithheldReason.nothingLogged);
  });

  group('effective dating (I-3)', () {
    test(
      'a target change does not move the targets a past day was scored against',
      () async {
        await setUpProfile();
        await logFood(
          name: 'Thepla',
          per100g: {'energy': 300, 'protein': 8},
          grams: 200,
        );
        final before = await DailySummaryDao(db)
            .summaryFor(ownerId: ownerId, logDate: yesterday);
        final energyTargetThen = before.energyTargetKcal;

        // Raise the energy target from today.
        await ProfileDao(db).overrideTarget(
          ownerId: ownerId,
          nutrientId: 'energy',
          amount: 2600,
          effectiveFrom: dateOnly(DateTime.now()),
        );

        await DailySummaryDao(db)
            .markStale(ownerId: ownerId, logDate: yesterday);
        final after = await DailySummaryDao(db)
            .summaryFor(ownerId: ownerId, logDate: yesterday);

        expect(after.energyTargetKcal, energyTargetThen);
        final today = await DailySummaryDao(db)
            .summaryFor(ownerId: ownerId, logDate: DateTime.now());
        expect(today.energyTargetKcal, 2600);
      },
    );

    test('an override survives a later profile change (FR-U-05)', () async {
      await setUpProfile();
      await ProfileDao(db).overrideTarget(
        ownerId: ownerId,
        nutrientId: 'water',
        amount: 3200,
        effectiveFrom: yesterday,
      );

      // Weight changes; targets are re-derived.
      await ProfileDao(db).saveProfileAndDeriveTargets(
        ownerId: ownerId,
        inputs: const ProfileInputs(
          ageYears: 34,
          heightCm: 174,
          weightKg: 68,
          activityLevel: ActivityLevel.light,
          biologicalSex: BiologicalSex.male,
        ),
        dateOfBirth: DateTime(1992, 3, 14),
        goal: GoalType.generalHealth,
        effectiveFrom: dateOnly(DateTime.now()),
      );

      final set = await ProfileDao(db).targetSetOn(ownerId, DateTime.now());
      final targets = await ProfileDao(db).targetsIn(set!.id);
      expect(targets['water']!.amount, 3200);
      expect(targets['water']!.isUserOverride, isTrue);
      expect(
        targets['energy']!.amount,
        isNot(closeTo(1632.5 * 1.375, 0.01)),
        reason: 'the derived ones did move with the new weight',
      );
    });

    test('reset-to-derived puts the computed value back', () async {
      await setUpProfile();
      await ProfileDao(db).overrideTarget(
        ownerId: ownerId,
        nutrientId: 'water',
        amount: 3200,
        effectiveFrom: yesterday,
      );
      await ProfileDao(db).resetTargetToDerived(
        ownerId: ownerId,
        nutrientId: 'water',
        inputs: const ProfileInputs(
          ageYears: 34,
          heightCm: 174,
          weightKg: 71,
          activityLevel: ActivityLevel.light,
          biologicalSex: BiologicalSex.male,
        ),
        goal: GoalType.generalHealth,
        effectiveFrom: dateOnly(DateTime.now()),
      );
      final set = await ProfileDao(db).targetSetOn(ownerId, DateTime.now());
      final targets = await ProfileDao(db).targetsIn(set!.id);
      expect(targets['water']!.amount, closeTo(35 * 71 + 150, 0.01));
      expect(targets['water']!.isUserOverride, isFalse);
    });
  });
}
