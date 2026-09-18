import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly_data/nourishly_data.dart';

/// FR-U-16's classification, which is the part that has to be right: the
/// preference itself is one column, but a dish is only correctly ranked if
/// its class was derived from what it is actually made of.
void main() {
  late NourishlyDatabase db;

  setUp(() => db = NourishlyDatabase.forTesting());
  tearDown(() => db.close());

  Future<void> food(String id, String name) {
    return db
        .into(db.foodItems)
        .insert(
          FoodItemsCompanion.insert(
            id: id,
            kind: 'ingredient',
            canonicalName: name,
            qualityTier: 'verified',
            provenanceSource: 'usda_fdc',
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  Future<void> component(String recipe, String ingredient) {
    return db
        .into(db.recipeComponents)
        .insert(
          RecipeComponentsCompanion.insert(
            id: '$recipe-$ingredient',
            recipeFoodItemId: recipe,
            ingredientFoodItemId: ingredient,
            quantityGrams: 50,
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  Future<String?> classOf(String id) async {
    final row = await (db.select(
      db.foodItems,
    )..where((f) => f.id.equals(id))).getSingle();
    return row.dietClass;
  }

  test('a plant leaf is vegan; the named animal roots are not', () async {
    await food('rice', 'Rice, white, raw');
    await food('milk', 'Milk, cow, whole');
    await food('egg', 'Egg, boiled');
    await food('fish', 'Fish, seer / kingfish');

    await DietClassifier(db).classifyAll();

    expect(await classOf('rice'), 'vegan');
    expect(await classOf('milk'), 'vegetarian');
    expect(await classOf('egg'), 'eggetarian');
    expect(await classOf('fish'), 'non_vegetarian');
  });

  test(
    'a dish takes the most restrictive class among its ingredients',
    () async {
      await food('rice', 'Rice, white, raw');
      await food('curd', 'Curd, plain');
      await food('curd-rice', 'Curd rice');
      await component('curd-rice', 'rice');
      await component('curd-rice', 'curd');

      await DietClassifier(db).classifyAll();

      expect(await classOf('curd-rice'), 'vegetarian');
    },
  );

  test(
    'a name that says nothing is still classified by its components',
    () async {
      // The reason this walks components instead of matching words: neither
      // "Kori gassi" nor "Meen kuzhambu" contains a word meaning chicken or
      // fish, and "Buttermilk" contains one that would mislead a substring
      // rule.
      await food('chicken', 'Chicken, curry cut, raw');
      await food('coconut', 'Coconut, fresh grated');
      await food('kori-gassi', 'Kori gassi');
      await component('kori-gassi', 'chicken');
      await component('kori-gassi', 'coconut');

      await food('curd', 'Curd, plain');
      await food('buttermilk', 'Buttermilk');
      await component('buttermilk', 'curd');

      await DietClassifier(db).classifyAll();

      expect(await classOf('kori-gassi'), 'non_vegetarian');
      expect(await classOf('buttermilk'), 'vegetarian');
    },
  );

  test('nesting carries the class up through every level', () async {
    await food('egg', 'Egg, boiled');
    await food('filling', 'Egg filling');
    await food('roll', 'Egg roll');
    await food('plate', 'Egg roll plate');
    await component('filling', 'egg');
    await component('roll', 'filling');
    await component('plate', 'roll');

    await DietClassifier(db).classifyAll();

    expect(await classOf('plate'), 'eggetarian');
  });

  test('a cycle leaves the dish unknown rather than looping', () async {
    await food('a', 'A');
    await food('b', 'B');
    await component('a', 'b');
    await component('b', 'a');

    await DietClassifier(db).classifyAll();

    expect(await classOf('a'), isNull);
  });

  group('ranking (FR-U-16)', () {
    test('a preference accepts anything at or below its own class', () {
      expect(
        suitsPreference(DietaryPreference.vegetarian, DietClass.vegan),
        isTrue,
      );
      expect(
        suitsPreference(DietaryPreference.vegetarian, DietClass.vegetarian),
        isTrue,
      );
      expect(
        suitsPreference(DietaryPreference.vegetarian, DietClass.eggetarian),
        isFalse,
      );
      expect(
        suitsPreference(DietaryPreference.vegan, DietClass.vegetarian),
        isFalse,
      );
      expect(
        suitsPreference(DietaryPreference.none, DietClass.nonVegetarian),
        isTrue,
      );
    });

    test('unknown is never treated as safe', () {
      // Telling a vegetarian that an unclassified dish is fine is the one
      // mistake this feature must not make.
      for (final preference in DietaryPreference.values) {
        expect(
          suitsPreference(preference, null),
          isFalse,
          reason: '$preference',
        );
      }
    });

    test('search reorders and never drops a result', () async {
      final search = FoodSearchDao(db);
      await food('paneer', 'Paneer tikka');
      await food('chicken', 'Chicken, curry cut, raw');
      await food('tikka', 'Chicken tikka');
      await component('tikka', 'chicken');
      await DietClassifier(db).classifyAll();

      for (final id in ['paneer', 'chicken', 'tikka']) {
        final row = await (db.select(
          db.foodItems,
        )..where((f) => f.id.equals(id))).getSingle();
        await search.indexFood(
          foodId: id,
          canonicalName: row.canonicalName,
          altNames: const [],
        );
      }

      final unranked = await search.search('tikka');
      final ranked = await search.search(
        'tikka',
        preference: DietaryPreference.vegetarian,
      );

      expect(
        ranked.map((f) => f.id).toSet(),
        unranked.map((f) => f.id).toSet(),
        reason: 'nothing is hidden — §27.4 forbids a dead end',
      );
      expect(ranked.first.id, 'paneer');
    });

    test('no stated preference leaves relevance order alone', () async {
      final search = FoodSearchDao(db);
      await food('chicken-tikka', 'Chicken tikka');
      await food('paneer-tikka', 'Paneer tikka');
      await DietClassifier(db).classifyAll();
      for (final id in ['chicken-tikka', 'paneer-tikka']) {
        final row = await (db.select(
          db.foodItems,
        )..where((f) => f.id.equals(id))).getSingle();
        await search.indexFood(
          foodId: id,
          canonicalName: row.canonicalName,
          altNames: const [],
        );
      }

      expect(
        (await search.search(
          'tikka',
          preference: DietaryPreference.none,
        )).map((f) => f.id),
        (await search.search('tikka')).map((f) => f.id),
      );
    });
  });
}
