// Turns the reviewed build/catalog_seed_draft.json into the actual
// bundled catalog seed the app imports on first run.
//
// Run from the repository root, after fetch_catalog.dart:
//   dart run tools/catalog_pipeline/bin/build_seed.dart
//
// Writes app/assets/catalog/seed_v1.json (committed — public-domain USDA
// data + our own catalog structure, safe per scope doc §0.7).
//
// Recipe entries are NOT in the draft (fetch_catalog.dart only resolves
// direct-USDA-lookup entries) and so are not in this seed either — they
// need a real yield/water-adjustment factor from a kitchen-scale
// calibration pass (catalog spec §0.3), which doesn't exist yet. Deferred,
// not skipped.
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

  for (final food in resolvedFoods) {
    final foodId = _uuid.v7();
    final (qualityTier, valueSource) = _tierFor(food['fdcDataType'] as String);

    foodItems.add({
      'id': foodId,
      'kind': 'ingredient',
      'canonicalName': food['foodName'],
      'qualityTier': qualityTier,
      'provenanceSource': 'usda_fdc',
      'provenanceId': '${food['fdcId']}',
      'isVerified': qualityTier == 'verified',
    });

    final nutrientsPer100g = (food['nutrientsPer100g'] as Map)
        .cast<String, dynamic>();
    for (final entry in nutrientsPer100g.entries) {
      nutrientValues.add({
        'id': _uuid.v7(),
        'foodId': foodId,
        'nutrientId': entry.key,
        'amountPer100g': entry.value,
        'valueSource': valueSource,
      });
    }

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

  final seed = {
    'catalogVersion': {
      'version': 1,
      'foodCount': foodItems.length,
      'checksum': 'usda-fdc-v1',
      'notes': 'Tier-1/2/3 direct-USDA ingredients. Recipes not yet included (need yield-factor calibration).',
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
  };

  final outFile = File('app/assets/catalog/seed_v1.json');
  outFile.parent.createSync(recursive: true);
  outFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(seed));

  stdout.writeln('Wrote ${outFile.path}');
  stdout.writeln(
    '${foodItems.length} foods, ${nutrientValues.length} nutrient values, ${servingSizes.length} servings, ${altNames.length} alt names.',
  );
}
