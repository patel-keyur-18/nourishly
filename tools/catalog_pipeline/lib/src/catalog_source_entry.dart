import 'package:meta/meta.dart';

import 'catalog_row_key.dart';

/// One row parsed from a `docs/catalog/*.md` table — the curated,
/// human-authored source the pipeline works from. Nothing here is a
/// nutrient value; that only ever comes from resolving [rawComposition]
/// against USDA FoodData Central (catalog spec §0.2).
@immutable
class CatalogSourceEntry {
  const CatalogSourceEntry({
    required this.sourceFile,
    required this.section,
    required this.isTier1,
    required this.foodName,
    required this.alsoNames,
    required this.servingLabel,
    required this.servingAmount,
    required this.weightColumnLabel,
    required this.rawComposition,
  });

  /// e.g. `01-common.md`.
  final String sourceFile;

  /// This row's stable identity, `<file number>:<slug>` — see
  /// [catalogRowKey]. Derived rather than stored, so no table needed a new
  /// column; unique as long as no file repeats a name, which `--check`
  /// enforces.
  String get key => catalogRowKey(sourceFile, foodName);

  /// The `## N. Title` heading this row appeared under, e.g. `Dals and pulses`.
  final String section;

  /// Whether the row carries the **①** marker — curate these first (catalog
  /// spec §0.5). Rows without it are tier 2/3, undifferentiated in the
  /// source tables; §0.5 says to let search failures drive that queue.
  final bool isTier1;

  final String foodName;

  /// Alternate names and transliterations, feeding `FoodAltName` (§22.5) —
  /// split from the `Also` column, empty when the column is `—`.
  final List<String> alsoNames;

  final String servingLabel;
  final double servingAmount;

  /// The source table's weight-column header — `g`, `ml`, or `g/ml`. The
  /// pipeline doesn't guess a unit from this beyond what §0.3's standard
  /// measures already establish; it's carried through for the human
  /// curator to confirm at import time.
  final String weightColumnLabel;

  /// The `Composition` column, unparsed. See [CompositionParser] for what
  /// this resolves to.
  final String rawComposition;

  @override
  String toString() => '$foodName ($sourceFile § $section)';
}
