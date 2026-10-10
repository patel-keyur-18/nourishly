import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly_data/nourishly_data.dart';

/// The Navmaas share file (ADR-012, docs/navmaas-share.md): what goes in,
/// and above all what never does.
void main() {
  late NourishlyDatabase db;
  late String ownerId;
  final now = DateTime(2026, 10, 10, 9, 40);
  final today = DateTime(2026, 10, 10);
  var n = 0;

  setUp(() async {
    n = 0;
    db = NourishlyDatabase.forTesting();
    ownerId = await ensureDefaultOwner(db);
    await db.batch((batch) {
      for (final (id, name) in const [
        ('macronutrients', 'Macronutrients'),
        ('minerals', 'Minerals'),
        ('vitamins', 'Vitamins'),
      ]) {
        batch.insert(
          db.nutrientGroups,
          NutrientGroupsCompanion.insert(id: id, name: name, sortOrder: 0),
        );
      }
      var order = 0;
      for (final (id, group, unit, precision) in const [
        ('energy', 'macronutrients', 'kcal', 0),
        ('protein', 'macronutrients', 'g', 1),
        ('fibre', 'macronutrients', 'g', 1),
        ('calcium', 'minerals', 'mg', 1),
        ('iron', 'minerals', 'mg', 1),
        ('folate', 'vitamins', 'ug', 1),
      ]) {
        batch.insert(
          db.nutrients,
          NutrientsCompanion.insert(
            id: id,
            groupId: group,
            displayName: id,
            canonicalUnit: unit,
            displayPrecision: precision,
            defaultCurveType: 'floor',
            isLimitNutrient: false,
            sortOrder: order++,
            isCore: true,
            minCoverageForScoring: 0.5,
          ),
        );
      }
      for (final (id, name, order) in const [
        ('breakfast', 'Breakfast', 0),
        ('lunch', 'Lunch', 1),
        ('dinner', 'Dinner', 3),
      ]) {
        batch.insert(
          db.mealSlots,
          MealSlotsCompanion.insert(
            id: id,
            key: id,
            displayName: name,
            sortOrder: order,
          ),
        );
      }
    });
  });

  tearDown(() => db.close());

  Future<void> log(
    String name, {
    required DateTime on,
    String slot = 'breakfast',
    String? label = '1 katori',
    double servingGrams = 150,
    double quantity = 1,
    Map<String, double> per100g = const {'energy': 100, 'protein': 3},
    String status = logStatusLogged,
    String? owner,
  }) async {
    final id = '${n++}';
    final grams = servingGrams * quantity;
    await db.batch((batch) {
      batch.insert(
        db.foodItems,
        FoodItemsCompanion.insert(
          id: 'food-$id',
          kind: 'ingredient',
          canonicalName: name,
          qualityTier: 'verified',
          provenanceSource: 'usda_fdc',
        ),
      );
      if (label != null) {
        batch.insert(
          db.servingSizes,
          ServingSizesCompanion.insert(
            id: 'serving-$id',
            foodId: 'food-$id',
            label: label,
            grams: servingGrams,
          ),
        );
      }
      batch.insert(
        db.foodLogEntries,
        FoodLogEntriesCompanion.insert(
          id: 'entry-$id',
          ownerId: owner ?? ownerId,
          logDate: on,
          mealSlotId: slot,
          foodId: 'food-$id',
          foodRevision: 1,
          servingSizeId: Value(label == null ? null : 'serving-$id'),
          quantity: quantity,
          gramsConsumed: grams,
          loggedAt: on,
          source: 'manual',
          status: Value(status),
        ),
      );
      for (final e in per100g.entries) {
        batch.insert(
          db.logEntryNutrients,
          LogEntryNutrientsCompanion.insert(
            entryId: 'entry-$id',
            nutrientId: e.key,
            amount: e.value * grams / 100,
          ),
        );
      }
    });
  }

  Future<Map<String, Object?>> build() =>
      buildNavmaasShare(db: db, ownerId: ownerId, today: today, now: now);

  List<Map<String, Object?>> daysOf(Map<String, Object?> share) =>
      (share['days']! as List).cast<Map<String, Object?>>();

  test('same shape as the shared sample', () async {
    await log('Poha', on: today);
    final share = await build();
    final sample = jsonDecode(
      File('test/fixtures/nourishly-share-v1.sample.json').readAsStringSync(),
    ) as Map<String, Object?>;
    expect(share.keys.toSet(), sample.keys.toSet());
    expect((share['format'], share['version']), ('nourishly-share', 1));
    expect(share['generatedAt'], startsWith('2026-10-10T09:40:00.000'));
    final day = daysOf(share).single;
    final sampleDay = daysOf(sample).first;
    expect(day.keys.toSet(), sampleDay.keys.toSet());
    final meal = (day['meals']! as List).cast<Map<String, Object?>>().single;
    expect(meal.keys.toSet(), {'slot', 'items'});
    expect((meal['items']! as List).single, {
      'name': 'Poha',
      'amount': '1 katori · 150 g',
    });
  });

  test(
    'only days with something eaten, newest first, slots in order',
    () async {
      final yesterday = today.subtract(const Duration(days: 1));
      await log('Khichdi', on: yesterday, slot: 'dinner');
      await log('Dal', on: yesterday, slot: 'lunch');
      await log('Poha', on: today);
      final days = daysOf(await build());
      expect(days.map((d) => d['date']), ['2026-10-10', '2026-10-09']);
      final meals = (days[1]['meals']! as List).cast<Map<String, Object?>>();
      expect(meals.map((m) => m['slot']), ['Lunch', 'Dinner']);
    },
  );

  test('the last 90 log dates, today included', () async {
    await log('In', on: today.subtract(const Duration(days: 89)));
    await log('Out', on: today.subtract(const Duration(days: 90)));
    final days = daysOf(await build());
    expect(days.map((d) => d['date']), ['2026-07-13']);
  });

  test('planned, skipped and deleted meals are never shared', () async {
    await log('Planned', on: today, status: logStatusPlanned);
    await log('Skipped', on: today, status: logStatusSkipped);
    await log('Deleted', on: today);
    await (db.update(db.foodLogEntries)..where((e) => e.id.equals('entry-2')))
        .write(FoodLogEntriesCompanion(deletedAt: Value(now)));
    expect(daysOf(await build()), isEmpty);
  });

  test('another profile is never shared', () async {
    await db
        .into(db.users)
        .insert(
          UsersCompanion.insert(
            id: 'other',
            displayName: 'Other',
            avatarColor: '#000000',
          ),
        );
    await log('Theirs', on: today, owner: 'other');
    expect(daysOf(await build()), isEmpty);
  });

  test('amounts: serving, quantity, plain grams', () async {
    await log('Poha', on: today);
    await log(
      'Phulka',
      on: today,
      label: '1 piece',
      servingGrams: 30,
      quantity: 2,
    );
    await log('Curd', on: today, label: null, servingGrams: 87.6);
    final items =
        ((daysOf(await build()).single['meals']! as List).single
                as Map<String, Object?>)['items']!
            as List;
    expect(items.map((i) => (i as Map)['amount']), [
      '1 katori · 150 g',
      '2 × 1 piece · 60 g',
      '88 g',
    ]);
  });

  test('totals: the six only, partial when some foods lack data', () async {
    await log(
      'Spinach',
      on: today,
      per100g: const {
        'energy': 23,
        'protein': 2.9,
        'iron': 2.7,
        'folate': 194,
        'calcium': 99,
        'fibre': 2.2,
      },
    );
    await log(
      'Rice',
      on: today,
      per100g: const {'energy': 130, 'protein': 2.7},
    );
    final day = daysOf(await build()).single;
    final totals = day['totals']! as Map<String, Object?>;
    expect(totals.keys.toSet(), {
      'energy',
      'protein',
      'iron',
      'calcium',
      'folate',
      'fibre',
    });
    expect(totals['energy'], 230);
    expect(
      day['partial'],
      unorderedEquals(['iron', 'calcium', 'folate', 'fibre']),
    );
  });

  test('a nutrient with no data that day is left out', () async {
    await log(
      'Rice',
      on: today,
      per100g: const {'energy': 130, 'protein': 2.7},
    );
    final day = daysOf(await build()).single;
    expect((day['totals']! as Map).keys.toSet(), {'energy', 'protein'});
    expect(day['partial'], isEmpty);
  });

  test('never targets, scores, profile, water or plans', () async {
    await log('Poha', on: today);
    await db
        .into(db.waterLogEntries)
        .insert(
          WaterLogEntriesCompanion.insert(
            id: 'w1',
            ownerId: ownerId,
            logDate: today,
            loggedAt: now,
            volumeMl: 250,
            source: 'quick_add',
          ),
        );
    final text = jsonEncode(await build()).toLowerCase();
    for (final word in [
      'target',
      'score',
      'insight',
      'status',
      'pct',
      'duedate',
      'lifestage',
      'water',
      'weight',
    ]) {
      expect(text, isNot(contains(word)), reason: word);
    }
  });

  test('a 1 am snack before a 4 am rollover stays on the day before', () async {
    final yesterday = today.subtract(const Duration(days: 1));
    await log('Late snack', on: yesterday);
    await (db.update(
      db.foodLogEntries,
    )..where((e) => e.id.equals('entry-0'))).write(
      FoodLogEntriesCompanion(
        loggedAt: Value(today.add(const Duration(hours: 1))),
      ),
    );
    expect(daysOf(await build()).single['date'], '2026-10-09');
  });

  test('90 full days build in well under the budget', () async {
    for (var d = 0; d < navmaasShareDays; d++) {
      for (final slot in ['breakfast', 'lunch', 'dinner']) {
        await log(
          'Food $d $slot',
          on: today.subtract(Duration(days: d)),
          slot: slot,
        );
      }
    }
    final watch = Stopwatch()..start();
    final days = daysOf(await build());
    watch.stop();
    expect(days, hasLength(navmaasShareDays));
    // Generous: the writer runs debounced and off the UI's frame budget.
    expect(watch.elapsed, lessThan(const Duration(seconds: 5)));
  });
}
