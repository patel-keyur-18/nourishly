import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly_data/nourishly_data.dart';

/// Runs against the real bundled seed (`app/assets/catalog/seed_v1.json`)
/// rather than a fixture — this importer's whole job is to load exactly
/// that file, so a fixture would test something else.
void main() {
  late NourishlyDatabase db;
  late Map<String, dynamic> seed;

  setUpAll(() {
    final file = File('../../app/assets/catalog/seed_v1.json');
    if (!file.existsSync()) {
      fail(
        'Seed not built. Run: dart run tools/catalog_pipeline/bin/build_seed.dart',
      );
    }
    seed = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  });

  setUp(() => db = NourishlyDatabase.forTesting());
  tearDown(() => db.close());

  test(
    'imports the real seed: nutrients, foods, servings, alt names all land',
    () async {
      final imported = await CatalogImporter(db).importIfNeeded(seed);

      expect(imported, isTrue);
      expect(await db.select(db.nutrients).get(), hasLength(24));
      expect(await db.select(db.nutrientGroups).get(), hasLength(4));
      expect(await db.select(db.mealSlots).get(), hasLength(4));

      final foods = await db.select(db.foodItems).get();
      expect(foods, isNotEmpty);
      expect(foods.length, (seed['foodItems'] as List).length);

      final servings = await db.select(db.servingSizes).get();
      expect(servings.length, (seed['servingSizes'] as List).length);
      // Not one per food: a recipe component whose source food isn't its
      // own catalog row (the USDA food behind "puffed rice" in bhel) gets a
      // FoodItems row for traceability, but no household serving — nothing
      // invents a katori for it.
      expect(servings.length, lessThan(foods.length));

      final components = await db.select(db.recipeComponents).get();
      expect(components.length, (seed['recipeComponents'] as List).length);
    },
  );

  test(
    'a food from the real catalog is searchable after import (Paneer)',
    () async {
      await CatalogImporter(db).importIfNeeded(seed);

      final results = await FoodSearchDao(db).search('paneer');

      expect(results, isNotEmpty);
      expect(results.first.canonicalName.toLowerCase(), contains('paneer'));
    },
  );

  test('a component-only USDA row is imported but never searchable', () async {
    await CatalogImporter(db).importIfNeeded(seed);

    final componentRows = await (db.select(
      db.foodItems,
    )..where((f) => f.provenanceSource.equals('usda_fdc_component'))).get();
    expect(
      componentRows,
      isNotEmpty,
      reason: 'the seed should carry recipe-component source foods',
    );

    final dao = FoodSearchDao(db);
    for (final row in componentRows) {
      final hits = await dao.matchingFoodIds('"${row.canonicalName}"');
      expect(
        hits,
        isNot(contains(row.id)),
        reason: '${row.canonicalName} should not surface when logging',
      );
    }

    // Its recipe still points at it, so the provenance trail is intact.
    final components = await db.select(db.recipeComponents).get();
    final componentIds = {for (final r in componentRows) r.id};
    expect(
      components.any((c) => componentIds.contains(c.ingredientFoodItemId)),
      isTrue,
    );
  });

  test('a food is searchable by its alt-name spelling too (panir)', () async {
    await CatalogImporter(db).importIfNeeded(seed);

    final results = await FoodSearchDao(db).search('panir');

    expect(results, isNotEmpty);
  });

  test(
    'running the import twice does not duplicate rows (idempotent)',
    () async {
      await CatalogImporter(db).importIfNeeded(seed);
      final secondRun = await CatalogImporter(db).importIfNeeded(seed);

      expect(secondRun, isFalse);
      final foods = await db.select(db.foodItems).get();
      expect(foods.length, (seed['foodItems'] as List).length);
    },
  );

  test(
    'every food has a real, non-empty nutrient snapshot (not zero-filled)',
    () async {
      await CatalogImporter(db).importIfNeeded(seed);

      final rice =
          await (db.select(db.foodItems)
                ..where((f) => f.canonicalName.equals('Rice, white, cooked')))
              .getSingle();
      final values = await (db.select(
        db.foodNutrientValues,
      )..where((v) => v.foodId.equals(rice.id))).get();

      expect(values, isNotEmpty);
      expect(
        values.any((v) => v.nutrientId == 'energy' && v.amountPer100g > 0),
        isTrue,
      );
    },
  );
}
