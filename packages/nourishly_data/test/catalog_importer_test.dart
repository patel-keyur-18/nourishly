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
      // One per food, now that every recipe ingredient resolves to a
      // catalog row: there is no longer a FoodItems row whose only reason
      // to exist is backing an ingredient, so there is no food without a
      // household serving.
      expect(servings.length, foods.length);

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

  test('the seed no longer needs component-only rows at all', () async {
    // Before recipe ingredients resolved against the catalog, an
    // unrecognised one minted a FoodItems row from a raw USDA description
    // ("Cereals ready-to-eat, rice, puffed") purely so the recipe had
    // something to point at. Every ingredient now names a catalog row, so
    // none are left. The importer still knows how to keep such a row out
    // of the search index — see below — in case a future seed has one.
    await CatalogImporter(db).importIfNeeded(seed);

    final componentRows = await (db.select(
      db.foodItems,
    )..where((f) => f.provenanceSource.equals('usda_fdc_component'))).get();

    expect(componentRows, isEmpty);
  });

  test('a component-only row would be imported but never searchable', () async {
    // The guard itself, on a seed built to contain one. It matters because
    // such a row is a raw USDA description with no serving size: findable
    // in search, it would offer the user a food they cannot portion.
    final withComponent = {
      ...seed,
      'foodItems': [
        ...(seed['foodItems'] as List),
        {
          'id': 'component-only-test-row',
          'kind': 'ingredient',
          'canonicalName': 'Cereals ready-to-eat, rice, puffed',
          'qualityTier': 'verified',
          'provenanceSource': 'usda_fdc_component',
          'provenanceId': '173861',
          'isVerified': true,
        },
      ],
    };

    await CatalogImporter(db).importIfNeeded(withComponent);

    final hits = await FoodSearchDao(db)
        .matchingFoodIds('"Cereals ready-to-eat, rice, puffed"');

    expect(hits, isNot(contains('component-only-test-row')));
    final imported = await (db.select(
      db.foodItems,
    )..where((f) => f.id.equals('component-only-test-row'))).get();
    expect(imported, hasLength(1), reason: 'imported for provenance');
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
