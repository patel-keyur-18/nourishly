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
// Recipe entries (composition = ingredients + grams) are not resolved by
// this script — they need every ingredient they reference to be resolved
// first, and some reference other catalog dishes rather than raw
// ingredients (the entries `parse_catalog.dart` already flags as
// NeedsManualReview). That's the next step once this one is reviewed.
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
  for (final file in catalogDir.listSync().whereType<File>()) {
    if (!file.path.endsWith('.md') || file.path.endsWith('README.md')) continue;
    for (final entry in sourceParser.parseFile(file)) {
      final composition = compositionParser.parse(entry.rawComposition);
      if (composition is UsdaLookup) {
        lookups.add((entry, composition));
      }
    }
  }

  stdout.writeln(
    'Resolving ${lookups.length} direct-USDA entries against FoodData Central...',
  );

  final resolved = <Map<String, dynamic>>[];
  final failures = <String>[];
  var done = 0;

  for (final (entry, lookup) in lookups) {
    done++;
    final queries = _queryCandidates(entry, lookup);
    stdout.writeln(
      '[$done/${lookups.length}] ${entry.foodName} (trying: ${queries.join(' / ')})',
    );

    try {
      FdcFood? detail;
      // Pass 1: Foundation/SR Legacy only (measured data, §19.11's
      // preferred quality tier). Pass 2: any FDC data type — catches
      // items like jaggery that simply aren't in the restricted set.
      // `fdcDataType` in the output records which tier a match actually
      // came from, so the promotion step can reflect it honestly.
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
            detail = await client.getDetails(candidates.first.fdcId);
            break;
          }
          await Future<void>.delayed(const Duration(milliseconds: 150));
        }
        if (detail != null) break;
      }

      if (detail == null) {
        failures.add('${entry.foodName}: no FDC match for any of $queries');
        continue;
      }

      final result = normalizer.normalize(detail);

      resolved.add({
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
