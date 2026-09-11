import 'package:drift/drift.dart';

import 'dao/food_search_dao.dart';
import 'database.dart';
import 'diet_classifier.dart';

/// Imports the bundled catalog seed (`app/assets/catalog/seed_v1.json`,
/// built by `tools/catalog_pipeline/bin/build_seed.dart`) on first run
/// (§16.4). Idempotent: skipped entirely once [CatalogVersions] already
/// has the seed's version, so re-running on every app start costs one
/// cheap query.
class CatalogImporter {
  CatalogImporter(this._db);

  final NourishlyDatabase _db;

  /// Returns true if an import ran, false if the seed's version was
  /// already present.
  Future<bool> importIfNeeded(Map<String, dynamic> seed) async {
    final versionJson = seed['catalogVersion'] as Map<String, dynamic>;
    final targetVersion = versionJson['version'] as int;

    final existing = await (_db.select(
      _db.catalogVersions,
    )..where((c) => c.version.equals(targetVersion))).getSingleOrNull();
    if (existing != null) {
      // Already imported, but a device upgrading from schema v1 has no
      // diet classes yet (FR-U-16) — and a no-op once they are filled in.
      await DietClassifier(_db).classifyMissing();
      return false;
    }

    final foodItems = (seed['foodItems'] as List).cast<Map<String, dynamic>>();
    final altNames = (seed['foodAltNames'] as List)
        .cast<Map<String, dynamic>>();

    await _db.batch((batch) {
      batch.insertAll(_db.nutrientGroups, [
        for (final g
            in (seed['nutrientGroups'] as List).cast<Map<String, dynamic>>())
          NutrientGroupsCompanion.insert(
            id: g['id'] as String,
            name: g['name'] as String,
            sortOrder: g['sortOrder'] as int,
          ),
      ]);

      batch.insertAll(_db.nutrients, [
        for (final n
            in (seed['nutrients'] as List).cast<Map<String, dynamic>>())
          NutrientsCompanion.insert(
            id: n['id'] as String,
            groupId: n['groupId'] as String,
            displayName: n['displayName'] as String,
            canonicalUnit: n['canonicalUnit'] as String,
            displayPrecision: n['displayPrecision'] as int,
            defaultCurveType: n['defaultCurveType'] as String,
            isLimitNutrient: n['isLimitNutrient'] as bool,
            sortOrder: n['sortOrder'] as int,
            isCore: n['isCore'] as bool,
            minCoverageForScoring: (n['minCoverageForScoring'] as num)
                .toDouble(),
          ),
      ]);

      batch.insertAll(_db.mealSlots, [
        for (final m
            in (seed['mealSlots'] as List).cast<Map<String, dynamic>>())
          MealSlotsCompanion.insert(
            id: m['id'] as String,
            key: m['key'] as String,
            displayName: m['displayName'] as String,
            sortOrder: m['sortOrder'] as int,
          ),
      ]);

      batch.insertAll(_db.foodItems, [
        for (final f in foodItems)
          FoodItemsCompanion.insert(
            id: f['id'] as String,
            kind: f['kind'] as String,
            canonicalName: f['canonicalName'] as String,
            qualityTier: f['qualityTier'] as String,
            provenanceSource: f['provenanceSource'] as String,
            provenanceId: Value(f['provenanceId'] as String?),
            isVerified: Value(f['isVerified'] as bool),
            // Recipe rows only; null on a direct-USDA ingredient.
            yieldFactor: Value((f['yieldFactor'] as num?)?.toDouble()),
          ),
      ]);

      batch.insertAll(_db.foodNutrientValues, [
        for (final v
            in (seed['foodNutrientValues'] as List)
                .cast<Map<String, dynamic>>())
          FoodNutrientValuesCompanion.insert(
            id: v['id'] as String,
            foodId: v['foodId'] as String,
            nutrientId: v['nutrientId'] as String,
            amountPer100g: (v['amountPer100g'] as num).toDouble(),
            valueSource: v['valueSource'] as String,
          ),
      ]);

      batch.insertAll(_db.servingSizes, [
        for (final s
            in (seed['servingSizes'] as List).cast<Map<String, dynamic>>())
          ServingSizesCompanion.insert(
            id: s['id'] as String,
            foodId: s['foodId'] as String,
            label: s['label'] as String,
            grams: (s['grams'] as num).toDouble(),
            isHouseholdMeasure: Value(s['isHouseholdMeasure'] as bool),
            isDefault: Value(s['isDefault'] as bool),
            sortOrder: Value(s['sortOrder'] as int),
          ),
      ]);

      batch.insertAll(_db.foodAltNames, [
        for (final a in altNames)
          FoodAltNamesCompanion.insert(
            id: a['id'] as String,
            foodId: a['foodId'] as String,
            name: a['name'] as String,
            nameNormalized: a['nameNormalized'] as String,
            language: a['language'] as String,
            isTransliteration: Value(a['isTransliteration'] as bool),
          ),
      ]);

      // A recipe's ingredient list. Its nutrients are already stored as
      // ordinary FoodNutrientValues rows, so nothing reads these to log a
      // meal — they are the provenance trail from a dish back to the USDA
      // foods it was derived from (§19.10), and an ingredient here may be
      // another recipe (bhel -> sev -> besan).
      batch.insertAll(_db.recipeComponents, [
        for (final c
            in (seed['recipeComponents'] as List? ?? const [])
                .cast<Map<String, dynamic>>())
          RecipeComponentsCompanion.insert(
            id: c['id'] as String,
            recipeFoodItemId: c['recipeFoodItemId'] as String,
            ingredientFoodItemId: c['ingredientFoodItemId'] as String,
            quantityGrams: (c['quantityGrams'] as num).toDouble(),
            sortOrder: Value(c['sortOrder'] as int),
          ),
      ]);

      batch.insert(
        _db.catalogVersions,
        CatalogVersionsCompanion.insert(
          version: Value(targetVersion),
          publishedAt: DateTime.now(),
          foodCount: versionJson['foodCount'] as int,
          checksum: versionJson['checksum'] as String,
          notes: Value(versionJson['notes'] as String?),
        ),
      );
    });

    final searchDao = FoodSearchDao(_db);
    final altNamesByFood = <String, List<String>>{};
    for (final a in altNames) {
      (altNamesByFood[a['foodId'] as String] ??= []).add(a['name'] as String);
    }
    for (final f in foodItems) {
      // A component-only row backs a recipe ingredient without being a
      // catalog entry — raw USDA description, no serving size, nothing
      // anyone would search for or could log. Imported for provenance,
      // left out of the index.
      if (f['provenanceSource'] == 'usda_fdc_component') continue;

      final foodId = f['id'] as String;
      await searchDao.indexFood(
        foodId: foodId,
        canonicalName: f['canonicalName'] as String,
        altNames: altNamesByFood[foodId] ?? const [],
      );
    }

    // Computed from the rows that were just imported (FR-U-16). Cheap,
    // and it keeps the pipeline free of a concern that is really about how
    // this household eats rather than about the food data itself.
    await DietClassifier(_db).classifyAll();

    return true;
  }
}
