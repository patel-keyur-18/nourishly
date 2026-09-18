import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly_data/nourishly_data.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

void main() {
  late NourishlyDatabase db;
  late RecipeDao dao;
  late String ownerId;

  setUp(() async {
    db = NourishlyDatabase.forTesting();
    dao = RecipeDao(db);
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
      for (final (id, name, unit) in const [
        ('energy', 'Energy', 'kcal'),
        ('protein', 'Protein', 'g'),
        ('iron', 'Iron', 'mg'),
      ]) {
        batch.insert(
          db.nutrients,
          NutrientsCompanion.insert(
            id: id,
            groupId: 'macronutrients',
            displayName: name,
            canonicalUnit: unit,
            displayPrecision: 0,
            defaultCurveType: 'floor',
            isLimitNutrient: false,
            sortOrder: order++,
            isCore: true,
            minCoverageForScoring: 0.6,
          ),
        );
      }
    });
  });

  tearDown(() => db.close());

  Future<String> ingredient(
    String name,
    Map<String, double> per100g, {
    String? dietClass,
  }) async {
    final id = _uuid.v7();
    await db
        .into(db.foodItems)
        .insert(
          FoodItemsCompanion.insert(
            id: id,
            kind: 'ingredient',
            canonicalName: name,
            qualityTier: 'verified',
            provenanceSource: 'usda_fdc',
            dietClass: Value(dietClass),
          ),
        );
    await db.batch((batch) {
      for (final entry in per100g.entries) {
        batch.insert(
          db.foodNutrientValues,
          FoodNutrientValuesCompanion.insert(
            id: _uuid.v7(),
            foodId: id,
            nutrientId: entry.key,
            amountPer100g: entry.value,
            valueSource: 'analytical',
          ),
        );
      }
    });
    return id;
  }

  Future<Map<String, double>> storedNutrients(String foodId) async {
    final rows = await (db.select(
      db.foodNutrientValues,
    )..where((v) => v.foodId.equals(foodId))).get();
    return {for (final row in rows) row.nutrientId: row.amountPer100g};
  }

  test(
    'a recipe is an ordinary food, so nothing else needs a special case',
    () async {
      final dal = await ingredient('Toor dal', {'energy': 343, 'protein': 22});
      final id = await dao.saveRecipe(
        ownerId: ownerId,
        name: 'Everyday dal',
        ingredients: [
          RecipeIngredient(foodId: dal, name: 'Toor dal', grams: 100),
        ],
        servingGrams: 150,
        cookedGrams: 250,
      );

      final food = await (db.select(
        db.foodItems,
      )..where((f) => f.id.equals(id))).getSingle();
      expect(food.kind, 'recipe');
      expect(food.ownerId, ownerId);
      expect(food.qualityTier, 'user');
      expect(food.yieldFactor, closeTo(2.5, 1e-9));

      // Nutrients land as plain per-100g rows, which is what makes it
      // loggable through exactly the same path as a catalog food (§19.10).
      final nutrients = await storedNutrients(id);
      expect(nutrients['energy'], closeTo(343 / 2.5, 1e-9));
      expect(nutrients['protein'], closeTo(22 / 2.5, 1e-9));

      // And it has a default serving, so the portion screen has something to
      // offer.
      final servings = await (db.select(
        db.servingSizes,
      )..where((s) => s.foodId.equals(id))).get();
      expect(servings.single.grams, 150);
      expect(servings.single.isDefault, isTrue);
    },
  );

  test('a saved recipe is findable by name, including a prefix', () async {
    final rajma = await ingredient('Rajma', {'energy': 330});
    await dao.saveRecipe(
      ownerId: ownerId,
      name: 'Sunday rajma masala',
      ingredients: [RecipeIngredient(foodId: rajma, name: 'Rajma', grams: 200)],
      servingGrams: 200,
    );

    final results = await FoodSearchDao(db).search('sunday raj');
    expect(results.single.canonicalName, 'Sunday rajma masala');
  });

  test(
    'components are kept, so the recipe can be reopened and edited',
    () async {
      final dal = await ingredient('Toor dal', {'energy': 343});
      final onion = await ingredient('Onion', {'energy': 40});
      final id = await dao.saveRecipe(
        ownerId: ownerId,
        name: 'Everyday dal',
        ingredients: [
          RecipeIngredient(foodId: dal, name: 'Toor dal', grams: 100),
          RecipeIngredient(foodId: onion, name: 'Onion', grams: 50),
        ],
        servingGrams: 150,
        cookedGrams: 375,
      );

      final saved = (await dao.recipe(id))!;
      expect(saved.name, 'Everyday dal');
      expect(saved.ingredients.map((i) => i.name), ['Toor dal', 'Onion']);
      expect(saved.ingredients.map((i) => i.grams), [100, 50]);
      expect(saved.rawGrams, 150);
      expect(saved.cookedGrams, closeTo(375, 1e-9));
      expect(saved.servings, closeTo(2.5, 1e-9));
    },
  );

  group('editing (ADR-008)', () {
    test('an edit replaces the ingredients rather than merging them', () async {
      final dal = await ingredient('Toor dal', {'energy': 343});
      final onion = await ingredient('Onion', {'energy': 40});
      final id = await dao.saveRecipe(
        ownerId: ownerId,
        name: 'Everyday dal',
        ingredients: [
          RecipeIngredient(foodId: dal, name: 'Toor dal', grams: 100),
          RecipeIngredient(foodId: onion, name: 'Onion', grams: 50),
        ],
        servingGrams: 150,
      );

      await dao.saveRecipe(
        ownerId: ownerId,
        foodId: id,
        name: 'Everyday dal',
        ingredients: [
          RecipeIngredient(foodId: dal, name: 'Toor dal', grams: 120),
        ],
        servingGrams: 150,
      );

      final saved = (await dao.recipe(id))!;
      expect(saved.ingredients, hasLength(1));
      expect(saved.ingredients.single.grams, 120);
    });

    test(
      'an edit bumps the revision instead of rewriting what was logged',
      () async {
        final dal = await ingredient('Toor dal', {'energy': 343});
        final id = await dao.saveRecipe(
          ownerId: ownerId,
          name: 'Everyday dal',
          ingredients: [
            RecipeIngredient(foodId: dal, name: 'Toor dal', grams: 100),
          ],
          servingGrams: 100,
        );

        // Log a bowl of it as the recipe stands today.
        await db
            .into(db.foodLogEntries)
            .insert(
              FoodLogEntriesCompanion.insert(
                id: 'entry-1',
                ownerId: ownerId,
                logDate: DateTime(2026, 9, 1),
                mealSlotId: 'lunch',
                foodId: id,
                foodRevision: 1,
                quantity: 1,
                gramsConsumed: 100,
                loggedAt: DateTime(2026, 9, 1),
                source: 'manual',
              ),
            );
        await db
            .into(db.logEntryNutrients)
            .insert(
              LogEntryNutrientsCompanion.insert(
                entryId: 'entry-1',
                nutrientId: 'energy',
                amount: 343,
              ),
            );

        // Now double the dal.
        await dao.saveRecipe(
          ownerId: ownerId,
          foodId: id,
          name: 'Everyday dal',
          ingredients: [
            RecipeIngredient(foodId: dal, name: 'Toor dal', grams: 200),
          ],
          servingGrams: 100,
        );

        final snapshot = await (db.select(
          db.logEntryNutrients,
        )..where((n) => n.entryId.equals('entry-1'))).getSingle();
        expect(
          snapshot.amount,
          343,
          reason: 'the meal keeps the numbers it was measured with',
        );

        final food = await (db.select(
          db.foodItems,
        )..where((f) => f.id.equals(id))).getSingle();
        expect(food.revision, 2, reason: 'the change is visible, not silent');
      },
    );

    test('a removed nutrient stops being reported', () async {
      final withIron = await ingredient('Rajma', {'energy': 330, 'iron': 8});
      final withoutIron = await ingredient('Rice', {'energy': 130});
      final id = await dao.saveRecipe(
        ownerId: ownerId,
        name: 'Rajma chawal',
        ingredients: [
          RecipeIngredient(foodId: withIron, name: 'Rajma', grams: 100),
        ],
        servingGrams: 100,
      );
      expect(await storedNutrients(id), contains('iron'));

      await dao.saveRecipe(
        ownerId: ownerId,
        foodId: id,
        name: 'Plain chawal',
        ingredients: [
          RecipeIngredient(foodId: withoutIron, name: 'Rice', grams: 100),
        ],
        servingGrams: 100,
      );
      expect(await storedNutrients(id), isNot(contains('iron')));
    });
  });

  group('unknown nutrients (AP-4)', () {
    test('a nutrient most of the dish reports is kept', () async {
      final rajma = await ingredient('Rajma', {'energy': 330, 'iron': 8});
      final spices = await ingredient('Garam masala', {'energy': 300});
      final id = await dao.saveRecipe(
        ownerId: ownerId,
        name: 'Rajma masala',
        ingredients: [
          RecipeIngredient(foodId: rajma, name: 'Rajma', grams: 100),
          RecipeIngredient(foodId: spices, name: 'Garam masala', grams: 3),
        ],
        servingGrams: 100,
      );

      // Iron from 97% of the dish is worth having.
      expect(await storedNutrients(id), contains('iron'));
    });

    test('a nutrient from a small minority of the dish is dropped', () async {
      final rice = await ingredient('Rice', {'energy': 130});
      final garnish = await ingredient('Coriander', {'energy': 20, 'iron': 40});
      final id = await dao.saveRecipe(
        ownerId: ownerId,
        name: 'Rice with coriander',
        ingredients: [
          RecipeIngredient(foodId: rice, name: 'Rice', grams: 200),
          RecipeIngredient(foodId: garnish, name: 'Coriander', grams: 10),
        ],
        servingGrams: 200,
      );

      // 5% of the dish reports iron. That is not a low iron figure, it is
      // a wrong one, and stored it would look like any other number.
      expect(await storedNutrients(id), isNot(contains('iron')));
      expect(await storedNutrients(id), contains('energy'));
    });
  });

  group('diet class (FR-U-16)', () {
    test('the most restrictive ingredient decides', () async {
      final rice = await ingredient('Rice', {
        'energy': 130,
      }, dietClass: 'vegan');
      final ghee = await ingredient('Ghee', {
        'energy': 900,
      }, dietClass: 'vegetarian');
      final id = await dao.saveRecipe(
        ownerId: ownerId,
        name: 'Ghee rice',
        ingredients: [
          RecipeIngredient(foodId: rice, name: 'Rice', grams: 200),
          RecipeIngredient(foodId: ghee, name: 'Ghee', grams: 10),
        ],
        servingGrams: 200,
      );
      expect((await dao.recipe(id))!.dietClass, DietClass.vegetarian);
    });

    test(
      'chicken in it makes it non-vegetarian, whatever it is called',
      () async {
        final rice = await ingredient('Rice', {
          'energy': 130,
        }, dietClass: 'vegan');
        final chicken = await ingredient('Chicken', {
          'energy': 200,
        }, dietClass: 'non_vegetarian');
        final id = await dao.saveRecipe(
          ownerId: ownerId,
          name: 'Kori gassi',
          ingredients: [
            RecipeIngredient(foodId: rice, name: 'Rice', grams: 100),
            RecipeIngredient(foodId: chicken, name: 'Chicken', grams: 150),
          ],
          servingGrams: 200,
        );
        expect((await dao.recipe(id))!.dietClass, DietClass.nonVegetarian);
      },
    );

    test('one unknown ingredient makes the recipe unknown, not safe', () async {
      final rice = await ingredient('Rice', {
        'energy': 130,
      }, dietClass: 'vegan');
      final mystery = await ingredient('Mystery masala', {'energy': 300});
      final id = await dao.saveRecipe(
        ownerId: ownerId,
        name: 'Something rice',
        ingredients: [
          RecipeIngredient(foodId: rice, name: 'Rice', grams: 200),
          RecipeIngredient(foodId: mystery, name: 'Mystery masala', grams: 5),
        ],
        servingGrams: 200,
      );
      expect((await dao.recipe(id))!.dietClass, isNull);
    });
  });

  group('deleting', () {
    test(
      'a deleted recipe leaves search and the list, but not the table',
      () async {
        final dal = await ingredient('Toor dal', {'energy': 343});
        final id = await dao.saveRecipe(
          ownerId: ownerId,
          name: 'Everyday dal',
          ingredients: [
            RecipeIngredient(foodId: dal, name: 'Toor dal', grams: 100),
          ],
          servingGrams: 150,
        );

        await dao.deleteRecipe(id);

        expect(await dao.recipe(id), isNull);
        expect(await dao.recipesFor(ownerId), isEmpty);
        expect(await FoodSearchDao(db).search('everyday'), isEmpty);
        // A tombstone, not a delete: a meal logged from it still has to
        // resolve to a name (I-6, ADR-008).
        final row = await (db.select(
          db.foodItems,
        )..where((f) => f.id.equals(id))).getSingle();
        expect(row.deletedAt, isNotNull);
      },
    );
  });

  test(
    'a recipe with no ingredients is refused rather than saved empty',
    () async {
      expect(
        () => dao.saveRecipe(
          ownerId: ownerId,
          name: 'Air',
          ingredients: const [],
          servingGrams: 100,
        ),
        throwsArgumentError,
      );
    },
  );

  test('a serving has to weigh something', () async {
    final dal = await ingredient('Toor dal', {'energy': 343});
    expect(
      () => dao.saveRecipe(
        ownerId: ownerId,
        name: 'Everyday dal',
        ingredients: [
          RecipeIngredient(foodId: dal, name: 'Toor dal', grams: 100),
        ],
        servingGrams: 0,
      ),
      throwsArgumentError,
    );
  });

  test('the preview computes without writing anything', () async {
    final dal = await ingredient('Toor dal', {'energy': 343, 'protein': 22});
    final preview = await dao.computeFor(
      ingredients: [
        RecipeIngredient(foodId: dal, name: 'Toor dal', grams: 100),
      ],
      cookedGrams: 250,
    );

    expect(preview.per100g['energy'], closeTo(137.2, 0.01));
    expect(preview.yieldFactor, closeTo(2.5, 1e-9));
    expect(
      await (db.select(
        db.foodItems,
      )..where((f) => f.kind.equals('recipe'))).get(),
      isEmpty,
    );
  });
}
