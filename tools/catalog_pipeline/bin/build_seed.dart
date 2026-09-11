// Turns the reviewed build/catalog_seed_draft.json into the actual
// bundled catalog seed the app imports on first run.
//
// Run from the repository root, after fetch_catalog.dart:
//   dart run tools/catalog_pipeline/bin/build_seed.dart
//
// Writes app/assets/catalog/seed_v1.json (committed — public-domain USDA
// data + our own catalog structure, safe per scope doc §0.7).
//
// Recipe entries are in the draft too (fetch_catalog.dart resolves each
// ingredient and applies `resolveRecipeYield`'s cooking yield factor —
// pressure cooker for dal, open pot for rice and everything else, per the
// 2026-09-10 household decision) and get their own FoodItems row
// (`kind: 'recipe'`, `yieldFactor` set) plus RecipeComponents rows tracing
// back to their ingredients, same as any other catalog food.
import 'dart:convert';
import 'dart:io';

import 'package:catalog_pipeline/catalog_pipeline.dart';
import 'package:uuid/uuid.dart';

final _uuid = const Uuid();

/// `Foundation`/`SR Legacy` are USDA's measured, lab-analysed data;
/// anything else (here: `Branded`, for jaggery) is manufacturer-reported
/// (§19.11's quality tiers).
(String qualityTier, String valueSource) _tierFor(String fdcDataType) {
  return fdcDataType == 'Foundation' || fdcDataType == 'SR Legacy'
      ? ('verified', 'measured')
      : ('derived', 'label');
}

void main() {
  final draftFile = File('build/catalog_seed_draft.json');
  if (!draftFile.existsSync()) {
    stderr.writeln(
      'Run fetch_catalog.dart first — build/catalog_seed_draft.json not found.',
    );
    exit(1);
  }
  final draft =
      jsonDecode(draftFile.readAsStringSync()) as Map<String, dynamic>;
  final resolvedFoods = (draft['resolved'] as List)
      .cast<Map<String, dynamic>>();
  if ((draft['failures'] as List).isNotEmpty) {
    stderr.writeln(
      'Warning: draft has unresolved failures; they are excluded from the seed: ${draft['failures']}',
    );
  }

  final foodItems = <Map<String, dynamic>>[];
  final nutrientValues = <Map<String, dynamic>>[];
  final servingSizes = <Map<String, dynamic>>[];
  final altNames = <Map<String, dynamic>>[];
  final recipeComponents = <Map<String, dynamic>>[];

  // An ingredient FDC id -> its FoodItems id, shared across every recipe
  // (and the direct-lookup foods below) so an ingredient used by both a
  // Tier-1 entry and a recipe (e.g. toor dal) gets one row, not two.
  final ingredientFoodIdByFdcId = <int, String>{};

  // One FoodItems id per draft entry, minted up front because a recipe can
  // list another catalog dish as an ingredient ("Bhel" lists `sev`, resolved
  // to the "Sev, thin" row) and the two rows are not in dependency order in
  // the draft. Those components point at the dish's own FoodItems row rather
  // than minting a duplicate. Keyed by entry identity, not by name — a name
  // can repeat across state files (Idli, Puri, Coconut rice), and those are
  // separate rows with separate ids.
  final foodIdByEntry = {for (final food in resolvedFoods) food: _uuid.v7()};

  // Name -> id for resolving an ingredient's `catalogRow`. A name several
  // rows share is left out rather than pointing at an arbitrary one; no
  // ingredient currently resolves to such a name, and the component loop
  // throws with the name if that ever changes.
  final foodIdByName = <String, String>{};
  final ambiguousNames = <String>{};
  for (final food in resolvedFoods) {
    final name = food['foodName'] as String;
    if (!foodIdByName.containsKey(name)) {
      foodIdByName[name] = foodIdByEntry[food]!;
    } else {
      ambiguousNames.add(name);
    }
  }
  foodIdByName.removeWhere((name, _) => ambiguousNames.contains(name));

  void addNutrientValues(
    String foodId,
    Map<String, dynamic> nutrientsPer100g,
    String valueSource,
  ) {
    for (final entry in nutrientsPer100g.entries) {
      nutrientValues.add({
        'id': _uuid.v7(),
        'foodId': foodId,
        'nutrientId': entry.key,
        'amountPer100g': entry.value,
        'valueSource': valueSource,
      });
    }
  }

  for (final food in resolvedFoods) {
    if (food['kind'] != 'ingredient') continue;

    final foodId = foodIdByEntry[food]!;
    final (qualityTier, valueSource) = _tierFor(food['fdcDataType'] as String);
    ingredientFoodIdByFdcId[food['fdcId'] as int] = foodId;

    foodItems.add({
      'id': foodId,
      'kind': 'ingredient',
      'canonicalName': food['foodName'],
      'qualityTier': qualityTier,
      'provenanceSource': 'usda_fdc',
      'provenanceId': '${food['fdcId']}',
      'isVerified': qualityTier == 'verified',
    });

    addNutrientValues(
      foodId,
      (food['nutrientsPer100g'] as Map).cast<String, dynamic>(),
      valueSource,
    );

    servingSizes.add({
      'id': _uuid.v7(),
      'foodId': foodId,
      'label': food['servingLabel'],
      'grams': food['servingAmount'],
      'isHouseholdMeasure': true,
      'isDefault': true,
      'sortOrder': 0,
    });

    for (final alsoName in (food['alsoNames'] as List).cast<String>()) {
      altNames.add({
        'id': _uuid.v7(),
        'foodId': foodId,
        'name': alsoName,
        'nameNormalized': alsoName.toLowerCase(),
        'language': 'en',
        'isTransliteration': true,
      });
    }
  }

  for (final food in resolvedFoods) {
    if (food['kind'] != 'recipe') continue;

    final foodId = foodIdByEntry[food]!;
    final ingredients = (food['ingredients'] as List)
        .cast<Map<String, dynamic>>();

    foodItems.add({
      'id': foodId,
      'kind': 'recipe',
      'canonicalName': food['foodName'],
      // Derived from summed ingredient nutrients, not a single measured
      // source — always the 'derived' tier (§19.11).
      'qualityTier': 'derived',
      'provenanceSource': 'catalog_pipeline_recipe',
      'provenanceId': null,
      'isVerified': false,
      'yieldFactor': food['yieldFactor'],
    });

    addNutrientValues(
      foodId,
      (food['nutrientsPer100g'] as Map).cast<String, dynamic>(),
      'derived',
    );

    servingSizes.add({
      'id': _uuid.v7(),
      'foodId': foodId,
      'label': food['servingLabel'],
      'grams': food['servingAmount'],
      'isHouseholdMeasure': true,
      'isDefault': true,
      'sortOrder': 0,
    });

    for (final alsoName in (food['alsoNames'] as List).cast<String>()) {
      altNames.add({
        'id': _uuid.v7(),
        'foodId': foodId,
        'name': alsoName,
        'nameNormalized': alsoName.toLowerCase(),
        'language': 'en',
        'isTransliteration': true,
      });
    }

    for (var i = 0; i < ingredients.length; i++) {
      final ingredient = ingredients[i];
      final catalogRow = ingredient['catalogRow'] as String?;
      final fdcId = ingredient['fdcId'] as int?;

      final String ingredientFoodId;
      if (catalogRow != null) {
        // The ingredient is another catalog dish, already getting its own
        // recipe row in this same loop — point at it instead of minting a
        // duplicate, which is what makes the component chain traceable
        // (Bhel -> Sev, thin -> besan + oil).
        ingredientFoodId =
            foodIdByName[catalogRow] ??
            (throw StateError(
              '${food['foodName']} lists "${ingredient['name']}", resolved to '
              'catalog row "$catalogRow", which is not in the draft under a '
              'unique name. Rename the duplicate rows, or rerun '
              'fetch_catalog.dart.',
            ));
      } else if (fdcId != null) {
        // Reuse the ingredient's FoodItems row if this exact FDC food is
        // already in the catalog (as a direct-lookup entry or an earlier
        // recipe's ingredient); otherwise mint one so the ingredient is
        // traceable even if it isn't its own Tier-1/2/3 catalog entry.
        ingredientFoodId = ingredientFoodIdByFdcId.putIfAbsent(fdcId, () {
          final newId = _uuid.v7();
          final (qualityTier, valueSource) = _tierFor(
            ingredient['fdcDataType'] as String,
          );
          foodItems.add({
            'id': newId,
            'kind': 'ingredient',
            'canonicalName': ingredient['fdcDescription'],
            'qualityTier': qualityTier,
            // Not `usda_fdc`: this row exists only so the recipe's
            // components trace back to a source. Its name is a raw USDA
            // description ("Cereals ready-to-eat, rice, puffed, fortified")
            // and it has no serving size, so it is kept out of the search
            // index rather than shown to someone logging a meal.
            'provenanceSource': 'usda_fdc_component',
            'provenanceId': '$fdcId',
            'isVerified': qualityTier == 'verified',
          });
          addNutrientValues(
            newId,
            (ingredient['nutrientsPer100g'] as Map).cast<String, dynamic>(),
            valueSource,
          );
          return newId;
        });
      } else if (waterIngredients.contains(
        catalogKey(ingredient['name'] as String),
      )) {
        // Water: mass without nutrients (fetch_catalog.dart resolves it to
        // an empty nutrient map, so it has no fdcId to trace to). It still
        // counts toward the recipe's yield factor, but there is no
        // FoodItems row for it to point a component at, so it gets none.
        continue;
      } else {
        throw StateError(
          '${food['foodName']} ingredient "${ingredient['name']}" has neither '
          'an fdcId nor a catalogRow. Rerun fetch_catalog.dart.',
        );
      }

      recipeComponents.add({
        'id': _uuid.v7(),
        'recipeFoodItemId': foodId,
        'ingredientFoodItemId': ingredientFoodId,
        'quantityGrams': ingredient['quantityGrams'],
        'sortOrder': i,
      });
    }
  }

  final seed = {
    'catalogVersion': {
      'version': 1,
      'foodCount': foodItems.length,
      'checksum': 'usda-fdc-v1',
      'notes': 'Tier-1/2/3 direct-USDA ingredients plus recipes (cooking yield factor applied per recipe_yield.dart).',
    },
    'nutrientGroups': [
      for (final g in nutrientGroups)
        {'id': g.$1, 'name': g.$2, 'sortOrder': nutrientGroups.indexOf(g)},
    ],
    'nutrients': [
      for (final n in nutrientRegistry)
        {
          'id': n.id,
          'groupId': n.groupId,
          'displayName': n.displayName,
          'canonicalUnit': n.canonicalUnit,
          'displayPrecision': n.canonicalUnit == 'kcal' ? 0 : 1,
          'defaultCurveType': 'floor',
          'isLimitNutrient':
              n.id == 'sodium' || n.id == 'saturated_fat' || n.id == 'sugar',
          'sortOrder': nutrientRegistry.indexOf(n),
          'isCore': const [
            'energy',
            'protein',
            'carbs',
            'fat',
            'fibre',
          ].contains(n.id),
          'minCoverageForScoring': 0.5,
        },
    ],
    'mealSlots': [
      {
        'id': _uuid.v7(),
        'key': 'breakfast',
        'displayName': 'Breakfast',
        'sortOrder': 0,
      },
      {
        'id': _uuid.v7(),
        'key': 'lunch',
        'displayName': 'Lunch',
        'sortOrder': 1,
      },
      {
        'id': _uuid.v7(),
        'key': 'dinner',
        'displayName': 'Dinner',
        'sortOrder': 2,
      },
      {
        'id': _uuid.v7(),
        'key': 'snack',
        'displayName': 'Snack',
        'sortOrder': 3,
      },
    ],
    'foodItems': foodItems,
    'foodNutrientValues': nutrientValues,
    'servingSizes': servingSizes,
    'foodAltNames': altNames,
    'recipeComponents': recipeComponents,
  };

  final outFile = File('app/assets/catalog/seed_v1.json');
  outFile.parent.createSync(recursive: true);
  outFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(seed));

  stdout.writeln('Wrote ${outFile.path}');
  stdout.writeln(
    '${foodItems.length} foods, ${nutrientValues.length} nutrient values, ${servingSizes.length} servings, ${altNames.length} alt names.',
  );
}
