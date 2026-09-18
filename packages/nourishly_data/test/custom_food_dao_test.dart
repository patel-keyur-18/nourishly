import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly_data/nourishly_data.dart';

void main() {
  late NourishlyDatabase db;
  late CustomFoodDao dao;
  late String ownerId;

  setUp(() async {
    db = NourishlyDatabase.forTesting();
    final seed = jsonDecode(
      File('../../app/assets/catalog/seed_v1.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    await CatalogImporter(db).importIfNeeded(seed);
    ownerId = await ensureDefaultOwner(db);
    dao = CustomFoodDao(db);
  });
  tearDown(() => db.close());

  Future<String> createThepla() => dao.createCustomFood(
    ownerId: ownerId,
    name: "Mummy's thepla",
    servingLabel: '1 piece',
    servingGrams: 45,
    nutrientsPerServing: {'energy': 135, 'protein': 3.6},
  );

  test(
    'a custom food is owned, user-tier, and loggable like any food',
    () async {
      final foodId = await createThepla();

      final food = await (db.select(
        db.foodItems,
      )..where((f) => f.id.equals(foodId))).getSingle();
      expect(food.ownerId, ownerId);
      expect(food.kind, 'user_custom');
      expect(food.qualityTier, 'user');

      final servings = await (db.select(
        db.servingSizes,
      )..where((s) => s.foodId.equals(foodId))).get();
      expect(servings, hasLength(1));
      expect(servings.single.grams, 45);
      expect(servings.single.isDefault, isTrue);
    },
  );

  test(
    'per-serving figures are stored per 100 g like every other food',
    () async {
      final foodId = await createThepla();

      final values = await (db.select(
        db.foodNutrientValues,
      )..where((v) => v.foodId.equals(foodId))).get();

      final energy = values.firstWhere((v) => v.nutrientId == 'energy');
      // 135 kcal in 45 g -> 300 kcal per 100 g.
      expect(energy.amountPer100g, closeTo(300, 0.0001));
      expect(energy.valueSource, 'estimated');
    },
  );

  test(
    'a nutrient the user did not enter is absent, never zero (AP-4)',
    () async {
      final foodId = await createThepla();

      final values = await (db.select(
        db.foodNutrientValues,
      )..where((v) => v.foodId.equals(foodId))).get();

      expect(
        values.map((v) => v.nutrientId),
        containsAll(['energy', 'protein']),
      );
      expect(values.map((v) => v.nutrientId), isNot(contains('carbs')));
    },
  );

  test('it is findable by search straight away (UX-6)', () async {
    await createThepla();

    final results = await FoodSearchDao(db).search('thepla');

    expect(results.map((f) => f.canonicalName), contains("Mummy's thepla"));
  });

  test('a serving must weigh something', () async {
    expect(
      () => dao.createCustomFood(
        ownerId: ownerId,
        name: 'Nothing',
        servingLabel: '1 piece',
        servingGrams: 0,
        nutrientsPerServing: const {},
      ),
      throwsArgumentError,
    );
  });
}
