// Resolves every direct-USDA-lookup entry in docs/catalog/*.md against
// FoodData Central and writes a draft catalog seed as JSON.
//
// Run locally (this needs live network access FDC's servers, which the
// sandboxed session that built this pipeline does not have):
//
//   FDC_API_KEY=your-key-here dart run tools/catalog_pipeline/bin/fetch_catalog.dart
//
// Never put the key on the command line where it lands in shell history
// on a shared machine — prefix the command with a space (most shells
// then skip it) or export it in a shell only you can read first.
//
// Recipe entries (composition = ingredients + grams) are resolved too:
// each ingredient is looked up the same way a direct-USDA entry is, then
// `resolveRecipeYield` sums them and applies the cooking yield factor
// (`recipe_yield.dart` — pressure cooker for dal, open pot for rice and
// everything else, per the 2026-09-10 household decision) to get the
// dish's own per-100g values. Entries that reference another catalog dish
// by name instead of listing ingredients (`NeedsManualReview`, e.g.
// "Bhakhri + spice mix") are still left for a human curator — a wrong
// guess there would silently produce the wrong recipe.
//
// Output: build/catalog_seed_draft.json (gitignored — review it, then a
// follow-up promotes reviewed entries into the actual bundled seed).
import 'dart:convert';
import 'dart:io';

import 'package:catalog_pipeline/catalog_pipeline.dart';

/// Strips characters FDC's search endpoint 400s on ("/", "(", ")" — seen
/// on "paneer/queso fresco", "Chana, whole (kabuli)") and collapses
/// whitespace.
String _sanitizeQuery(String s) =>
    s.replaceAll(RegExp(r'[/()]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

/// Ordered, deduplicated search terms to try for one entry: the parsed
/// hint (skipped if it's empty or an editorial note like "USDA — **the
/// sodium source...**", not an actual food description), then the
/// catalog's own name, then every `Also` synonym — which is exactly where
/// the English/US term for a regional name (Rajma -> kidney beans,
/// Jaggery has no FDC entry at all, Matki -> moth bean) lives. Every
/// candidate is sanitized the same way; no per-entry special-casing.
List<String> _queryCandidates(CatalogSourceEntry entry, UsdaLookup lookup) {
  final hint = lookup.hint.trim();
  final raw = [
    if (hint.isNotEmpty && !hint.startsWith('—') && !hint.startsWith('-')) hint,
    entry.foodName,
    ...entry.alsoNames,
  ];
  final seen = <String>{};
  final result = <String>[];
  for (final candidate in raw) {
    final clean = _sanitizeQuery(candidate);
    if (clean.isNotEmpty && seen.add(clean)) result.add(clean);
  }
  return result;
}

/// Searches FDC for the first of [queries] that returns a hit, trying
/// [FdcClient.preferredDataTypes] (measured Foundation/SR Legacy data,
/// §19.11's preferred quality tier) before falling back to any data type
/// — catches items like jaggery that simply aren't in the restricted set.
Future<FdcFood?> _resolve(FdcClient client, List<String> queries) async {
  for (final dataType in [FdcClient.preferredDataTypes, null]) {
    for (final query in queries) {
      final candidates = await client.search(
        query,
        pageSize: 3,
        dataType: dataType,
      );
      if (candidates.isNotEmpty) {
        // Full detail fetch: search results sometimes carry an
        // abbreviated nutrient panel compared to the food's own record.
        return client.getDetails(candidates.first.fdcId);
      }
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
  }
  return null;
}

Future<void> main() async {
  final apiKey = Platform.environment['FDC_API_KEY'];
  if (apiKey == null || apiKey.isEmpty) {
    stderr.writeln(
      'Set FDC_API_KEY in your environment first. See this file\'s header comment.',
    );
    exit(1);
  }

  final catalogDir = Directory('docs/catalog');
  if (!catalogDir.existsSync()) {
    stderr.writeln(
      'Could not find docs/catalog. Run this from the repository root.',
    );
    exit(1);
  }

  final sourceParser = CatalogSourceParser();
  final compositionParser = CompositionParser();
  final client = FdcClient(apiKey: apiKey);
  final normalizer = FdcNormalizer();

  final lookups = <(CatalogSourceEntry, UsdaLookup)>[];
  final recipes = <(CatalogSourceEntry, Recipe)>[];
  for (final file in catalogDir.listSync().whereType<File>()) {
    if (!file.path.endsWith('.md') || file.path.endsWith('README.md')) continue;
    for (final entry in sourceParser.parseFile(file)) {
      final composition = compositionParser.parse(entry.rawComposition);
      switch (composition) {
        case UsdaLookup():
          lookups.add((entry, composition));
        case Recipe():
          recipes.add((entry, composition));
        case NeedsManualReview():
          break;
      }
    }
  }

  stdout.writeln(
    'Resolving ${lookups.length} direct-USDA entries and ${recipes.length} '
    'recipes against FoodData Central...',
  );

  final resolved = <Map<String, dynamic>>[];
  final failures = <String>[];
  // Ingredient name (lowercased) -> resolved FDC food, shared across every
  // recipe so a common ingredient (rice, toor dal, groundnut oil) is only
  // looked up once no matter how many dishes use it.
  final ingredientCache = <String, FdcFood?>{};
  var done = 0;

  for (final (entry, lookup) in lookups) {
    done++;
    final queries = _queryCandidates(entry, lookup);
    stdout.writeln(
      '[$done/${lookups.length + recipes.length}] ${entry.foodName} '
      '(trying: ${queries.join(' / ')})',
    );

    try {
      final detail = await _resolve(client, queries);
      if (detail == null) {
        failures.add('${entry.foodName}: no FDC match for any of $queries');
        continue;
      }

      final result = normalizer.normalize(detail);

      resolved.add({
        'kind': 'ingredient',
        'sourceFile': entry.sourceFile,
        'foodName': entry.foodName,
        'isTier1': entry.isTier1,
        'alsoNames': entry.alsoNames,
        'servingLabel': entry.servingLabel,
        'servingAmount': entry.servingAmount,
        'fdcId': detail.fdcId,
        'fdcDescription': detail.description,
        'fdcDataType': detail.dataType,
        'nutrientsPer100g': {
          for (final m in result.matches) m.nutrient.id: m.amountPer100g,
        },
        'unmatchedFdcNutrients': result.unmatchedFdcNutrients,
      });
    } on FdcApiException catch (e) {
      failures.add(
        '${entry.foodName}: FDC request failed (HTTP ${e.statusCode})',
      );
    }

    // A light pause between requests — polite to a free government API,
    // and keeps well inside even the DEMO_KEY's 30/hour limit if that's
    // what's set.
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }

  for (final (entry, recipe) in recipes) {
    done++;
    stdout.writeln(
      '[$done/${lookups.length + recipes.length}] ${entry.foodName} '
      '(recipe, ${recipe.ingredients.length} ingredients)',
    );

    final resolvedIngredients = <ResolvedIngredient>[];
    final ingredientDetails = <Map<String, dynamic>>[];
    var missingIngredient = false;

    for (final ingredient in recipe.ingredients) {
      final key = _sanitizeQuery(ingredient.name).toLowerCase();
      FdcFood? detail;
      try {
        detail = ingredientCache.containsKey(key)
            ? ingredientCache[key]
            : await _resolve(client, [_sanitizeQuery(ingredient.name)]);
      } on FdcApiException catch (e) {
        failures.add(
          '${entry.foodName}: FDC request failed for ingredient '
          '"${ingredient.name}" (HTTP ${e.statusCode})',
        );
        missingIngredient = true;
        break;
      }
      ingredientCache[key] = detail;

      if (detail == null) {
        failures.add(
          '${entry.foodName}: no FDC match for ingredient "${ingredient.name}"',
        );
        missingIngredient = true;
        break;
      }

      final result = normalizer.normalize(detail);
      resolvedIngredients.add(
        ResolvedIngredient(ingredient, {
          for (final m in result.matches) m.nutrient.id: m.amountPer100g,
        }),
      );
      ingredientDetails.add({
        'name': ingredient.name,
        'amount': ingredient.amount,
        'unit': ingredient.unit,
        'quantityGrams': gramsForIngredient(ingredient),
        'fdcId': detail.fdcId,
        'fdcDescription': detail.description,
        'fdcDataType': detail.dataType,
        'nutrientsPer100g': {
          for (final m in result.matches) m.nutrient.id: m.amountPer100g,
        },
      });

      await Future<void>.delayed(const Duration(milliseconds: 150));
    }

    if (missingIngredient) continue;

    final yieldResult = resolveRecipeYield(resolvedIngredients);

    resolved.add({
      'kind': 'recipe',
      'sourceFile': entry.sourceFile,
      'foodName': entry.foodName,
      'isTier1': entry.isTier1,
      'alsoNames': entry.alsoNames,
      'servingLabel': entry.servingLabel,
      'servingAmount': entry.servingAmount,
      'cookingMethod': yieldResult.method.name,
      'yieldFactor': yieldResult.yieldFactor,
      'nutrientsPer100g': yieldResult.nutrientsPer100g,
      'ingredients': ingredientDetails,
    });
  }

  client.close();

  final outDir = Directory('build');
  outDir.createSync(recursive: true);
  final outFile = File('build/catalog_seed_draft.json');
  outFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ')
        .convert({'resolved': resolved, 'failures': failures}),
  );

  stdout.writeln('\n--- Summary ---');
  stdout.writeln('Resolved: ${resolved.length}');
  stdout.writeln('Failed:   ${failures.length}');
  stdout.writeln('Wrote ${outFile.path}');
  if (failures.isNotEmpty) {
    stdout.writeln('\nFailures:');
    for (final f in failures) {
      stdout.writeln('  - $f');
    }
  }
}
