import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly_data/nourishly_data.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Comparing a household's own version of a dish with the catalog recipe
/// it was forked from.
///
/// Every figure is a difference between two recipes each summed from its
/// own ingredients — nothing modelled, nothing estimated. What the tests
/// mostly pin is the honesty of the edges: an unknown is not a zero, a
/// heavier fork is not netted off, and a saving is only claimed where both
/// sides can actually be compared.
void main() {
  late NourishlyDatabase db;
  late ForkSavingsDao dao;
  late String ownerId;
  final day = DateTime(2026, 9, 12);

  setUp(() async {
    db = NourishlyDatabase.forTesting();
    dao = ForkSavingsDao(db);
    ownerId = await ensureDefaultOwner(db);
    await db
        .into(db.mealSlots)
        .insert(
          MealSlotsCompanion.insert(
            id: 'slot-lunch',
            key: 'lunch',
            displayName: 'Lunch',
            sortOrder: 0,
          ),
        );
  });

  tearDown(() => db.close());

  Future<String> recipe(
    String name, {
    String? owner,
    String? forkedFrom,
    double? energy,
    double? fat,
    double servingGrams = 120,
  }) async {
    final id = _uuid.v7();
    await db
        .into(db.foodItems)
        .insert(
          FoodItemsCompanion.insert(
            id: id,
            ownerId: Value(owner),
            kind: 'recipe',
            canonicalName: name,
            qualityTier: owner == null ? 'derived' : 'user',
            provenanceSource: owner == null
                ? 'catalog_pipeline_recipe'
                : 'user',
            forkedFromFoodId: Value(forkedFrom),
          ),
        );
    await db
        .into(db.servingSizes)
        .insert(
          ServingSizesCompanion.insert(
            id: _uuid.v7(),
            foodId: id,
            label: '1 katori',
            grams: servingGrams,
            isDefault: const Value(true),
          ),
        );
    for (final (nutrientId, amount) in [('energy', energy), ('fat', fat)]) {
      if (amount == null) continue;
      await db
          .into(db.foodNutrientValues)
          .insert(
            FoodNutrientValuesCompanion.insert(
              id: _uuid.v7(),
              foodId: id,
              nutrientId: nutrientId,
              amountPer100g: amount,
              valueSource: 'calculated',
            ),
          );
    }
    return id;
  }

  Future<void> log(String foodId, {double grams = 120, int times = 1}) async {
    for (var i = 0; i < times; i++) {
      await db
          .into(db.foodLogEntries)
          .insert(
            FoodLogEntriesCompanion.insert(
              id: _uuid.v7(),
              ownerId: ownerId,
              logDate: day,
              mealSlotId: 'slot-lunch',
              foodId: foodId,
              foodRevision: 1,
              quantity: 1,
              gramsConsumed: grams,
              loggedAt: day,
              source: 'manual',
            ),
          );
    }
  }

  test(
    'reports what the household version saves, per 100 g and per katori',
    () async {
      final parent = await recipe('Bataka nu shaak', energy: 120, fat: 7);
      final mine = await recipe(
        'Bataka nu shaak (our version)',
        owner: ownerId,
        forkedFrom: parent,
        energy: 90,
        fat: 3.5,
      );

      final saving = (await dao.savingFor(mine))!;
      expect(saving.parentName, 'Bataka nu shaak');
      expect(saving.energyPer100g, 30);
      expect(saving.fatPer100g, 3.5);
      // A saving people can picture: per katori, not per 100 g.
      expect(saving.energyPerServing, closeTo(36, 0.01));
      expect(saving.fatPerServing, closeTo(4.2, 0.01));
      expect(saving.isLighter, isTrue);
    },
  );

  test('a recipe that is not a fork has nothing to compare', () async {
    final own = await recipe('From scratch', owner: ownerId, energy: 90);
    expect(await dao.savingFor(own), isNull);
  });

  test('a missing nutrient is unknown, never a saving of zero', () async {
    // AP-4: "no saving" and "we cannot tell" are different claims.
    final parent = await recipe('Parent', energy: 120);
    final mine = await recipe(
      'Mine',
      owner: ownerId,
      forkedFrom: parent,
      fat: 3,
    );
    expect(await dao.savingFor(mine), isNull);
  });

  test('a heavier fork is reported honestly, not clamped', () async {
    final parent = await recipe('Parent', energy: 100, fat: 4);
    final mine = await recipe(
      'Mine, with ghee',
      owner: ownerId,
      forkedFrom: parent,
      energy: 140,
      fat: 9,
    );
    final saving = (await dao.savingFor(mine))!;
    expect(saving.energyPer100g, -40);
    expect(saving.isLighter, isFalse);
  });

  group('over a period', () {
    test('totals from what was actually eaten, by weight', () async {
      final parent = await recipe('Bataka nu shaak', energy: 120, fat: 7);
      final mine = await recipe(
        'Bataka nu shaak (our version)',
        owner: ownerId,
        forkedFrom: parent,
        energy: 90,
        fat: 3.5,
      );
      await log(mine, grams: 120, times: 3);

      final savings = await dao.savingsOver(
        ownerId,
        from: day.subtract(const Duration(days: 7)),
        to: day,
      );
      expect(savings.entryCount, 3);
      expect(savings.dishCount, 1);
      expect(savings.energy, closeTo(108, 0.01));
      expect(savings.fat, closeTo(12.6, 0.01));
    });

    test('a bigger helping saves proportionally more', () async {
      final parent = await recipe('Parent', energy: 200, fat: 10);
      final mine = await recipe(
        'Mine',
        owner: ownerId,
        forkedFrom: parent,
        energy: 100,
        fat: 5,
      );
      await log(mine, grams: 300);

      final savings = await dao.savingsOver(
        ownerId,
        from: day.subtract(const Duration(days: 1)),
        to: day,
      );
      expect(savings.energy, closeTo(300, 0.01));
    });

    test('a heavier fork is left out, not netted off', () async {
      // This answers "what did cooking lighter save". Quietly subtracting
      // the ghee somebody added would answer a different question while
      // looking like this one.
      final parent = await recipe('Parent', energy: 100, fat: 4);
      final lighter = await recipe(
        'Lighter',
        owner: ownerId,
        forkedFrom: parent,
        energy: 60,
        fat: 2,
      );
      final heavier = await recipe(
        'Heavier',
        owner: ownerId,
        forkedFrom: parent,
        energy: 300,
        fat: 20,
      );
      await log(lighter, grams: 100);
      await log(heavier, grams: 100);

      final savings = await dao.savingsOver(
        ownerId,
        from: day.subtract(const Duration(days: 1)),
        to: day,
      );
      expect(savings.energy, closeTo(40, 0.01));
      expect(savings.dishCount, 1);
    });

    test(
      'a period with no forked meals is empty, not zero-with-confidence',
      () async {
        final plain = await recipe('Catalog dish', energy: 100);
        await log(plain);
        final savings = await dao.savingsOver(
          ownerId,
          from: day.subtract(const Duration(days: 1)),
          to: day,
        );
        expect(savings.isEmpty, isTrue);
      },
    );
  });

  test('lists a profile\'s lighter versions, biggest saving first', () async {
    final p1 = await recipe('Sabzi', energy: 120, fat: 7);
    final p2 = await recipe('Pav bhaji', energy: 200, fat: 12);
    await recipe(
      'Sabzi (our version)',
      owner: ownerId,
      forkedFrom: p1,
      energy: 90,
      fat: 3.5,
    );
    await recipe(
      'Pav bhaji (our version)',
      owner: ownerId,
      forkedFrom: p2,
      energy: 130,
      fat: 6,
      servingGrams: 300,
    );

    final savings = await dao.savingsForOwner(ownerId);
    expect(savings.map((s) => s.name), [
      'Pav bhaji (our version)',
      'Sabzi (our version)',
    ]);
  });
}
