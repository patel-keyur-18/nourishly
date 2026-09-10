// Parses docs/catalog/*.md and reports what the pipeline can and can't
// resolve yet. Run from the repository root:
//
//   dart run tools/catalog_pipeline/bin/parse_catalog.dart
//
// This step never touches the network — it only reads the curated source
// tables. Resolving UsdaLookup/Recipe ingredients against FoodData Central
// is a separate step (fdc_client.dart), gated on an API key.
import 'dart:io';

import 'package:catalog_pipeline/catalog_pipeline.dart';

void main() {
  final catalogDir = Directory('docs/catalog');
  if (!catalogDir.existsSync()) {
    stderr.writeln(
      'Could not find docs/catalog. Run this from the repository root.',
    );
    exit(1);
  }

  final files =
      catalogDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.md') && !f.path.endsWith('README.md'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  final parser = CatalogSourceParser();
  final compositionParser = CompositionParser();

  var total = 0;
  var tier1 = 0;
  var usdaLookups = 0;
  var recipes = 0;
  final needsReview = <(CatalogSourceEntry, NeedsManualReview)>[];

  for (final file in files) {
    final entries = parser.parseFile(file);
    stdout.writeln('${file.uri.pathSegments.last}: ${entries.length} rows');

    for (final entry in entries) {
      total++;
      if (entry.isTier1) tier1++;

      final composition = compositionParser.parse(entry.rawComposition);
      switch (composition) {
        case UsdaLookup():
          usdaLookups++;
        case Recipe():
          recipes++;
        case NeedsManualReview():
          needsReview.add((entry, composition));
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
