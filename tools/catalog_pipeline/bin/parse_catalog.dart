// Parses docs/catalog/*.md and reports what the pipeline can and can't
// resolve. Run from the repository root:
//
//   dart run tools/catalog_pipeline/bin/parse_catalog.dart
//   dart run tools/catalog_pipeline/bin/parse_catalog.dart --check
//   dart run tools/catalog_pipeline/bin/parse_catalog.dart --suggest
//   dart run tools/catalog_pipeline/bin/parse_catalog.dart --write-lock
//
// None of these touch the network. They read the curated source tables,
// the target table and the committed lock, which is the point: a new row
// can be proved harmless before anyone spends an API key on it.
// Resolving nutrients against FoodData Central is a separate step
// (`fetch_catalog.dart`).
//
//   --check       the gate. Fails on a duplicate row key, an ingredient
//                 with no target, a target pointing at no row, an
//                 implausible yield, or any change to what an existing
//                 row's ingredients resolve to.
//   --suggest     runs the old tier inference over unmapped ingredients
//                 and prints ready-to-paste `ingredient_targets.dart`
//                 lines, marking the ambiguous ones for a human.
//   --write-lock  rewrites docs/catalog/catalog.lock.json. Run it when a
//                 reported change is one you meant.
import 'dart:convert';
import 'dart:io';

import 'package:catalog_pipeline/catalog_pipeline.dart';

const _lockPath = 'docs/catalog/catalog.lock.json';

/// Every `docs/catalog/*.md` table row, parsed and classified. Sorted by
/// filename so two runs on two machines agree.
({List<CatalogRow> rows, List<File> files}) _readCatalog(Directory dir) {
  final files =
      dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.md') && !f.path.endsWith('README.md'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  final parser = CatalogSourceParser();
  final compositionParser = CompositionParser();
  return (
    rows: [
      for (final file in files)
        for (final entry in parser.parseFile(file))
          CatalogRow(entry, compositionParser.parse(entry.rawComposition)),
    ],
    files: files,
  );
}

/// Everything `--check` can object to. Collected in full rather than
/// thrown at the first, so one run tells you everything to fix.
List<String> _problems(List<CatalogRow> rows, CatalogIndex index) {
  final problems = <String>[];

  // 1. Key collisions. Keys are unique while no file repeats a name, so
  //    this is where that rule is enforced.
  final byKey = <String, List<CatalogRow>>{};
  for (final row in rows) {
    (byKey[row.entry.key] ??= []).add(row);
  }
  for (final entry in byKey.entries) {
    if (entry.value.length > 1) {
      problems.add(
        'duplicate row key "${entry.key}": '
        '${entry.value.map((r) => '${r.entry.sourceFile} - ${r.entry.foodName}').join(' / ')}. '
        'Two rows in one file share a name; rename one.',
      );
    }
  }

  // 2. Ingredients with no target, and targets pointing at nothing.
  for (final row in rows) {
    final composition = row.composition;
    if (composition is! Recipe) continue;
    for (final ingredient in composition.ingredients) {
      final key = catalogKey(ingredient.name);
      if (waterIngredients.contains(key)) continue;
      final target = index.targetKeyFor(key);
      if (target == null) {
        problems.add(
          '"${row.entry.foodName}" (${row.entry.key}) uses ingredient '
          '"$key", which has no entry in ingredientTargets. Run --suggest.',
        );
      } else if (index.lookup(key) == null) {
        problems.add(
          'ingredient "$key" targets "$target", which is not a usable '
          'catalog row.',
        );
      }
    }
  }

  // 3. Implausible yields. A row whose two weight columns imply a factor
  //    outside the band is a curation typo, not something the pipeline
  //    should quietly paper over with a cooking-method constant.
  for (final row in rows) {
    final composition = row.composition;
    if (composition is! Recipe || composition.ingredients.isEmpty) continue;
    final result = resolveRecipeYield([
      for (final ingredient in composition.ingredients)
        ResolvedIngredient(ingredient, const {}),
    ], servingGrams: row.entry.servingAmount);
    if (result.basis == YieldBasis.cookingMethod) {
      problems.add(
        '"${row.entry.foodName}" (${row.entry.key}): serving weight '
        '${row.entry.servingAmount} g over ${result.rawIngredientGrams} g of '
        'ingredients is outside ${minPlausibleYield}x-${maxPlausibleYield}x. '
        'Check both weight columns.',
      );
    }
  }

  return problems;
}

int _runCheck(List<CatalogRow> rows, CatalogIndex index) {
  final problems = _problems(rows, index);
  final lockFile = File(_lockPath);
  final current = CatalogLock.fromRows(rows, index);

  var breaking = problems.length;

  if (!lockFile.existsSync()) {
    stdout.writeln(
      'No lock at $_lockPath yet — run --write-lock to record the current '
      'resolution as the baseline.',
    );
  } else {
    final previous = CatalogLock.fromJson(
      jsonDecode(lockFile.readAsStringSync()) as Map<String, dynamic>,
    );
    final changes = current.diff(previous);
    final added = changes.where((c) => c.severity == 'added').length;
    if (added > 0) stdout.writeln('$added new row(s) — fine, that is the job.');
    for (final change in changes.where((c) => c.severity != 'added')) {
      stdout.writeln('  $change');
      if (change.isBreaking) breaking++;
    }
  }

  if (problems.isNotEmpty) {
    stdout.writeln('\n--- Problems ---');
    for (final problem in problems) {
      stdout.writeln('  $problem');
    }
  }

  if (breaking > 0) {
    stderr.writeln(
      '\n--check failed: $breaking problem(s). Nothing here is a reason to '
      'guess — fix the row, add the target, or --write-lock if the change '
      'is one you meant.',
    );
    return 1;
  }
  stdout.writeln('\n--check passed.');
  return 0;
}

void _runSuggest(List<CatalogRow> rows, CatalogIndex index) {
  final unmapped = <String, Set<String>>{};
  for (final row in rows) {
    final composition = row.composition;
    if (composition is! Recipe) continue;
    for (final ingredient in composition.ingredients) {
      final key = catalogKey(ingredient.name);
      if (waterIngredients.contains(key)) continue;
      if (index.targetKeyFor(key) != null) continue;
      (unmapped[key] ??= {}).add(row.entry.foodName);
    }
  }

  if (unmapped.isEmpty) {
    stdout.writeln('Every ingredient already has a target. Nothing to do.');
    return;
  }

  stdout.writeln(
    'Paste into tools/catalog_pipeline/lib/src/ingredient_targets.dart.\n'
    'A TODO line means the old inference found several candidates — that '
    'is a decision for you, not for a tie-break rule.\n',
  );
  for (final key in unmapped.keys.toList()..sort()) {
    final suggestion = index.suggest(key);
    if (suggestion == null) {
      stdout.writeln(
        "  // TODO(you): '$key' matches no row. Add a catalog row for it, "
        'or map it to the closest sensible one.',
      );
    } else {
      stdout.writeln(suggestion.line);
    }
    stdout.writeln('       // used by: ${unmapped[key]!.join(', ')}');
  }
}

void main(List<String> args) {
  const known = ['--check', '--suggest', '--write-lock'];
  final unknown = args.where((a) => !known.contains(a));
  if (unknown.isNotEmpty) {
    stderr.writeln('Unknown argument(s): ${unknown.join(', ')}');
    stderr.writeln('Usage: parse_catalog.dart [${known.join('|')}]');
    exit(64);
  }

  final catalogDir = Directory('docs/catalog');
  if (!catalogDir.existsSync()) {
    stderr.writeln(
      'Could not find docs/catalog. Run this from the repository root.',
    );
    exit(1);
  }

  final catalog = _readCatalog(catalogDir);
  final index = CatalogIndex(catalog.rows);

  if (args.contains('--suggest')) {
    _runSuggest(catalog.rows, index);
    return;
  }

  if (args.contains('--write-lock')) {
    File(_lockPath)
        .writeAsStringSync(CatalogLock.fromRows(catalog.rows, index).encode());
    stdout.writeln('Wrote $_lockPath (${catalog.rows.length} rows).');
    return;
  }

  if (args.contains('--check')) {
    exit(_runCheck(catalog.rows, index));
  }

  // Default: the summary this tool has always printed.
  var total = 0;
  var tier1 = 0;
  var usdaLookups = 0;
  var recipes = 0;
  final needsReview = <(CatalogSourceEntry, NeedsManualReview)>[];

  for (final file in catalog.files) {
    final rows = catalog.rows.where(
      (r) => r.entry.sourceFile == file.uri.pathSegments.last,
    );
    stdout.writeln('${file.uri.pathSegments.last}: ${rows.length} rows');
    for (final row in rows) {
      total++;
      if (row.entry.isTier1) tier1++;
      switch (row.composition) {
        case UsdaLookup():
          usdaLookups++;
        case Recipe():
          recipes++;
        case NeedsManualReview(:final reason, :final rawText):
          needsReview.add((row.entry, NeedsManualReview(reason, rawText)));
      }
    }
  }

  stdout.writeln('\n--- Summary ---');
  stdout.writeln('Total rows:         $total');
  stdout.writeln('Tier 1 (①):         $tier1');
  stdout.writeln('Direct USDA lookup: $usdaLookups');
  stdout.writeln('Recipes:            $recipes');
  stdout.writeln('Needs manual review: ${needsReview.length}');

  if (needsReview.isNotEmpty) {
    stdout.writeln('\n--- Needs manual review ---');
    for (final (entry, review) in needsReview) {
      stdout.writeln(
        '  ${entry.sourceFile} · ${entry.foodName}: ${review.reason}',
      );
      stdout.writeln('    "${review.rawText}"');
    }
  }
}
