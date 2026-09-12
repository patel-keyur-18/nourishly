// Resolves every direct-USDA-lookup entry in docs/catalog/*.md against
// FoodData Central and writes a draft catalog seed as JSON.
//
// Run locally (fetching needs live network access to FDC's servers, which
// the sandboxed session that built this pipeline does not have):
//
//   FDC_API_KEY=your-key-here dart run tools/catalog_pipeline/bin/fetch_catalog.dart
//
// Three cache modes (fdc_cache.dart), because every response is cached in
// the committed `tools/catalog_pipeline/fdc_cache/`:
//
//   --refresh-missing  (default) fetch only what the cache has not got
//   --cache-only       never touch the network; a miss is a reported
//                      failure, not a guess. Needs no API key, so this is
//                      how CI and an offline editor validate the catalog
//   --refresh-all      re-fetch everything and overwrite the cache; a
//                      deliberate USDA data refresh, reviewed as a diff
//
// Never put the key on the command line where it lands in shell history
// on a shared machine — prefix the command with a space (most shells
// then skip it) or export it in a shell only you can read first.
//
// Recipe entries (composition = ingredients + grams) are resolved too.
// Each ingredient is resolved through `_IngredientResolver`, which tries
// the catalog itself before FDC — the catalog is compositional, so an
// ingredient is often another catalog row ("Bhel" lists `sev`, "Kothu
// parotta" lists `Parotta`, "Mohanthal" lists `khoya`) that FDC has never
// heard of under that name. Once every ingredient has per-100g values,
// `resolveRecipeYield` sums them and applies the cooking yield factor
// (`recipe_yield.dart` — pressure cooker for dal, open pot for rice and
// everything else, none for cold assemblies, per the 2026-09-10 household
// decision) to get the dish's own per-100g values. Entries that reference
// another catalog dish by name instead of listing ingredients
// (`NeedsManualReview`, e.g. "Bhakhri + spice mix") are still left for a
// human curator — a wrong guess there would silently produce the wrong
// recipe.
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
Future<FdcFood?> _searchFdc(FdcSource client, List<String> queries) async {
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

/// Per-100g nutrients for one recipe ingredient, plus where they came
/// from — an FDC food, or another catalog row resolved through its own
/// recipe (in which case [catalogRow] names it and the values are already
/// on a cooked basis).
class _IngredientSource {
  const _IngredientSource(
    this.nutrientsPer100g, {
    this.food,
    this.catalogRow,
    this.catalogRowName,
  });

  final Map<String, double> nutrientsPer100g;
  final FdcFood? food;

  /// The stable row key (`catalog_row_key.dart`) of the catalog dish this
  /// ingredient resolved to — a key rather than a name, because two files
  /// legitimately carry the same dish name and `build_seed` has to point
  /// at exactly one of them.
  final String? catalogRow;

  /// That row's display name, carried only so the draft reads.
  final String? catalogRowName;
}

/// Resolves a recipe ingredient name to per-100g nutrients.
///
/// Order matters. The catalog is tried first because a regional ingredient
/// name is far more likely to be another catalog row than an FDC food:
///
/// 1. **Catalog row with a `USDA` composition** — run that row's full
///    candidate ladder (hint, name, every `Also` synonym), which is where
///    the searchable English term lives: `dudhi` -> Bottle gourd ->
///    "calabash", `Matki` -> "moth bean", `khoya` -> "Khoya / Mawa" ->
///    "condensed milk solids".
/// 2. **Catalog row that is itself a recipe** — resolve it recursively and
///    use its cooked per-100g values: `sev`, `patra`, `Muthiya`, `Fafda`,
///    `Parotta`.
/// 3. **Anything else** — the plain FDC search on the ingredient string,
///    which is all this pipeline used to do.
///
/// Recursion is memoized on the normalized name and guarded two ways: a
/// `visiting` set (so a dish that transitively lists itself falls through
/// to step 3 instead of looping) and a depth cap. A cycle bail is
/// deliberately not cached — it is a fact about one call stack, not about
/// the ingredient.
class _IngredientResolver {
  _IngredientResolver({
    required this.client,
    required this.normalizer,
    required this.index,
  });

  final FdcSource client;
  final FdcNormalizer normalizer;
  final CatalogIndex index;

  /// Normalized ingredient name -> result, shared across every recipe so a
  /// common ingredient (rice, toor dal, groundnut oil) is only looked up
  /// once no matter how many dishes use it.
  final _cache = <String, _IngredientSource?>{};

  static const _maxDepth = 5;

  Future<_IngredientSource?> resolve(String name, Set<String> visiting) async {
    final key = catalogKey(name);
    if (_cache.containsKey(key)) return _cache[key];
    if (visiting.contains(key) || visiting.length >= _maxDepth) return null;

    final source = await _resolveUncached(name, key, visiting);
    _cache[key] = source;
    return source;
  }

  Future<_IngredientSource?> _resolveUncached(
    String name,
    String key,
    Set<String> visiting,
  ) async {
    // Water is mass without nutrients. It has to resolve rather than be
    // skipped: the yield factor comes from total ingredient mass against
    // the serving weight, so dropping the water would concentrate
    // everything else in the dish.
    if (waterIngredients.contains(key)) {
      return const _IngredientSource({});
    }

    final row = index.lookup(name);
    final composition = row?.composition;

    if (row != null && composition is UsdaLookup) {
      final food = await _searchFdc(
        client,
        _queryCandidates(row.entry, composition),
      );
      if (food != null) return _IngredientSource(_nutrients(food), food: food);
    } else if (row != null && composition is Recipe) {
      final nested = await _resolveRecipe(row, composition, {...visiting, key});
      if (nested != null) return nested;
    }

    // No blind FDC search on the raw ingredient string. A regional
    // ingredient name means something in *this* catalog, not in FoodData
    // Central, and searching it there returns whatever shares a word:
    // "batter" found battered fish, "curd" found tofu, "milk" found milk
    // crackers, "rice" found rice noodles. Those matched, so the pipeline
    // reported no failure while shipping the wrong food's nutrients under
    // a `verified` badge.
    //
    // An ingredient that neither the catalog nor `ingredientAliases`
    // resolves is a curation gap. Say so (§0.2: nothing is invented).
    return null;
  }

  Future<_IngredientSource?> _resolveRecipe(
    CatalogRow row,
    Recipe recipe,
    Set<String> visiting,
  ) async {
    if (recipe.ingredients.isEmpty) return null;

    final parts = <ResolvedIngredient>[];
    for (final ingredient in recipe.ingredients) {
      final source = await resolve(ingredient.name, visiting);
      if (source == null) return null;
      parts.add(ResolvedIngredient(ingredient, source.nutrientsPer100g));
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }

    final yieldResult = resolveRecipeYield(
      parts,
      servingGrams: row.entry.servingAmount,
    );
    return _IngredientSource(
      yieldResult.nutrientsPer100g,
      catalogRow: row.entry.key,
      catalogRowName: row.entry.foodName,
    );
  }

  Map<String, double> _nutrients(FdcFood food) => {
    for (final m in normalizer.normalize(food).matches)
      m.nutrient.id: m.amountPer100g,
  };
}

Future<void> main(List<String> args) async {
  final unknown = args.where(
    (a) => !const [
      '--cache-only',
      '--refresh-missing',
      '--refresh-all',
    ].contains(a),
  );
  if (unknown.isNotEmpty) {
    stderr.writeln('Unknown argument(s): ${unknown.join(', ')}');
    stderr.writeln(
      'Usage: fetch_catalog.dart [--cache-only|--refresh-missing|--refresh-all]',
    );
    exit(64);
  }

  final mode = args.contains('--cache-only')
      ? FdcCacheMode.cacheOnly
      : args.contains('--refresh-all')
      ? FdcCacheMode.refreshAll
      : FdcCacheMode.refreshMissing;

  // Only a mode that may fetch needs a key. --cache-only deliberately
  // runs without one, which is what makes offline validation possible.
  final apiKey = Platform.environment['FDC_API_KEY'];
  if (mode != FdcCacheMode.cacheOnly && (apiKey == null || apiKey.isEmpty)) {
    stderr.writeln(
      'Set FDC_API_KEY in your environment first, or pass --cache-only to '
      "run from the committed cache. See this file's header comment.",
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
  final client = CachingFdcSource(
    cache: FdcCache.defaultLocation(),
    mode: mode,
    live: mode == FdcCacheMode.cacheOnly ? null : FdcClient(apiKey: apiKey!),
  );
  final normalizer = FdcNormalizer();

  // Every parsed row, including the NeedsManualReview ones — they still
  // occupy a name in the index, where they lose ties to a resolvable
  // sibling ("Muthiya, fried" vs "Muthiya, steamed") rather than shadowing
  // it.
  final rows = <CatalogRow>[];
  // Sorted, because `listSync` order is filesystem-defined: leaving it
  // unsorted makes the draft's row order — and so the seed's — differ
  // between machines for no reason.
  final catalogFiles =
      catalogDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.md') && !f.path.endsWith('README.md'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  for (final file in catalogFiles) {
    for (final entry in sourceParser.parseFile(file)) {
      rows.add(
        CatalogRow(entry, compositionParser.parse(entry.rawComposition)),
      );
    }
  }

  final lookups = [
    for (final row in rows)
      if (row.composition case final UsdaLookup c) (row.entry, c),
  ];
  final recipes = [
    for (final row in rows)
      if (row.composition case final Recipe c) (row.entry, c),
  ];

  final resolver = _IngredientResolver(
    client: client,
    normalizer: normalizer,
    index: CatalogIndex(rows),
  );

  stdout.writeln(
    'Resolving ${lookups.length} direct-USDA entries and ${recipes.length} '
    'recipes against FoodData Central...',
  );

  final resolved = <Map<String, dynamic>>[];
  final failures = <String>[];
  var done = 0;

  for (final (entry, lookup) in lookups) {
    done++;
    final queries = _queryCandidates(entry, lookup);
    stdout.writeln(
      '[$done/${lookups.length + recipes.length}] ${entry.foodName} '
      '(trying: ${queries.join(' / ')})',
    );

    try {
      final detail = await _searchFdc(client, queries);
      if (detail == null) {
        failures.add('${entry.foodName}: no FDC match for any of $queries');
        continue;
      }

      final result = normalizer.normalize(detail);

      resolved.add({
        'kind': 'ingredient',
        'key': entry.key,
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
    } on FdcCacheMiss catch (e) {
      failures.add('${entry.foodName}: ${e.what} is not in the FDC cache');
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
      _IngredientSource? source;
      try {
        source = await resolver.resolve(ingredient.name, {
          catalogKey(entry.foodName),
        });
      } on FdcApiException catch (e) {
        failures.add(
          '${entry.foodName}: FDC request failed for ingredient '
          '"${ingredient.name}" (HTTP ${e.statusCode})',
        );
        missingIngredient = true;
        break;
      } on FdcCacheMiss catch (e) {
        failures.add(
          '${entry.foodName}: ingredient "${ingredient.name}" needs '
          '${e.what}, which is not in the FDC cache',
        );
        missingIngredient = true;
        break;
      }

      if (source == null) {
        failures.add(
          '${entry.foodName}: ingredient "${ingredient.name}" resolves to no '
          'catalog row. Add a row for it, or map it in ingredientAliases.',
        );
        missingIngredient = true;
        break;
      }

      resolvedIngredients.add(
        ResolvedIngredient(ingredient, source.nutrientsPer100g),
      );
      ingredientDetails.add({
        'name': ingredient.name,
        'amount': ingredient.amount,
        'unit': ingredient.unit,
        'quantityGrams': gramsForIngredient(ingredient),
        'source': source.catalogRow != null ? 'catalog' : 'fdc',
        'catalogRow': source.catalogRow,
        'catalogRowName': source.catalogRowName,
        'fdcId': source.food?.fdcId,
        'fdcDescription': source.food?.description,
        'fdcDataType': source.food?.dataType,
        'nutrientsPer100g': source.nutrientsPer100g,
      });

      await Future<void>.delayed(const Duration(milliseconds: 150));
    }

    if (missingIngredient) continue;

    final yieldResult = resolveRecipeYield(
      resolvedIngredients,
      servingGrams: entry.servingAmount,
    );

    resolved.add({
      'kind': 'recipe',
      'key': entry.key,
      'sourceFile': entry.sourceFile,
      'foodName': entry.foodName,
      'isTier1': entry.isTier1,
      'alsoNames': entry.alsoNames,
      'servingLabel': entry.servingLabel,
      'servingAmount': entry.servingAmount,
      'cookingMethod': yieldResult.method.name,
      'yieldBasis': yieldResult.basis.name,
      'yieldFactor': yieldResult.yieldFactor,
      'rawIngredientGrams': yieldResult.rawIngredientGrams,
      'nutrientsPer100g': yieldResult.nutrientsPer100g,
      'ingredients': ingredientDetails,
      // A row whose two weight columns imply an impossible factor fell back
      // to the cooking-method constant. That is a curation bug, not a
      // pipeline one — surface it rather than burying it.
      if (yieldResult.basis == YieldBasis.cookingMethod)
        'yieldWarning':
            'Serving weight ${entry.servingAmount} g over '
            '${yieldResult.rawIngredientGrams} g of ingredients is outside '
            '${minPlausibleYield}x-${maxPlausibleYield}x, so this fell back '
            'to the ${yieldResult.method.name} factor '
            '${yieldResult.yieldFactor}. Check both weight columns.',
    });
  }

  // A --cache-only run adds nothing to the cache, so rewriting the index
  // from it can only lose entries whose rows happened to fail this time.
  // Only a run that may fetch gets to rewrite it.
  if (mode != FdcCacheMode.cacheOnly) client.writeIndex();
  client.close();

  stdout.writeln(
    '\nFDC cache: ${client.hits} served from disk, ${client.fetches} fetched '
    '(${mode.name}).',
  );

  final outDir = Directory('build');
  outDir.createSync(recursive: true);
  final outFile = File('build/catalog_seed_draft.json');
  outFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ')
        .convert({'resolved': resolved, 'failures': failures}),
  );

  final warned = resolved.where((r) => r.containsKey('yieldWarning')).length;

  stdout.writeln('\n--- Summary ---');
  stdout.writeln('Resolved: ${resolved.length}');
  stdout.writeln('Failed:   ${failures.length}');
  stdout.writeln('Yield warnings: $warned (see yieldWarning in the JSON)');
  stdout.writeln('Wrote ${outFile.path}');
  if (failures.isNotEmpty) {
    stdout.writeln('\nFailures:');
    for (final f in failures) {
      stdout.writeln('  - $f');
    }
  }
}
