import 'package:meta/meta.dart';

import 'catalog_source_entry.dart';
import 'composition.dart';
import 'ingredient_targets.dart';

/// One catalog row paired with its parsed [Composition].
@immutable
class CatalogRow {
  const CatalogRow(this.entry, this.composition);

  final CatalogSourceEntry entry;
  final Composition composition;

  /// Whether this row can supply nutrients at all. A [NeedsManualReview]
  /// row cannot, and must never be the answer to a lookup.
  bool get isUsable => composition is! NeedsManualReview;

  @override
  String toString() => 'CatalogRow(${entry.foodName})';
}

/// Normalizes a food name to a lookup key: lowercased, `/` and `()`
/// flattened to spaces, whitespace collapsed. Deliberately the same
/// flattening `fetch_catalog.dart` applies before querying FDC, so an
/// ingredient string keys the same way whichever path resolves it.
String catalogKey(String raw) => raw
    .toLowerCase()
    .replaceAll(RegExp(r'[/()]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// One inference the old tier rules would have made, offered to a human
/// rather than acted on. Produced by [CatalogIndex.suggest].
@immutable
class TargetSuggestion {
  const TargetSuggestion({
    required this.name,
    required this.candidates,
    required this.tier,
  });

  /// The unmapped ingredient string, normalized.
  final String name;

  /// Every row the tier that matched would have considered. One candidate
  /// is a suggestion worth pasting; several is a decision only a person
  /// should make, and is exactly where the old inference guessed wrong.
  final List<CatalogRow> candidates;

  /// `name`, `alias` or `prefix` — which tier produced [candidates].
  final String tier;

  bool get isAmbiguous => candidates.length > 1;

  /// The line to paste into `ingredient_targets.dart`, or a `TODO` when
  /// the tier could not settle it.
  String get line => isAmbiguous
      ? "  // TODO(you): '$name' is claimed by "
            '${candidates.map((c) => "${c.entry.key} (${c.entry.foodName})").join(", ")}'
      : "  '$name': '${candidates.single.entry.key}', "
            '// ${candidates.single.entry.foodName}';
}

/// Resolves a recipe's ingredient strings to the catalog rows that supply
/// their nutrients.
///
/// **Resolution is table-driven, not inferred.** [lookup] consults
/// `ingredientTargets` and nothing else, so what an ingredient means
/// cannot change because some unrelated row was added. See
/// `ingredient_targets.dart` for why that matters — in short, inference
/// let four innocuous pantry rows silently retarget sixty-three
/// ingredient references with no error at all.
///
/// The old inference survives in [suggest], which is how new entries get
/// written: it proposes, a human disposes. It used three tiers, each fully
/// exhausted before the next was consulted:
///
/// 1. the row's own name ("Patra", "Fafda", "Kesari bath")
/// 2. every `Also` synonym ("dudhi" -> Bottle gourd, "moth bean" -> Matki)
/// 3. the name's leading segment before a `,` or `/` ("Sev, thin" -> "sev",
///    "Khoya / Mawa" -> "khoya")
///
/// The tiers are ranked, not merged, because a row's own name is stronger
/// evidence than some other row's synonym: "Kesari bath" is a dish in
/// 04-karnataka.md *and* an `Also` for Tamil Nadu's "Rava kesari", and the
/// row actually named that is the one to take. Within a tier, a key that
/// several rows claim is reported as ambiguous rather than picked.
class CatalogIndex {
  CatalogIndex(Iterable<CatalogRow> rows) {
    final byKey = <String, CatalogRow>{};
    final byName = <String, List<CatalogRow>>{};
    final byAlias = <String, List<CatalogRow>>{};
    final byPrefix = <String, List<CatalogRow>>{};

    for (final row in rows) {
      byKey[row.entry.key] = row;

      final nameKey = catalogKey(row.entry.foodName);
      if (nameKey.isNotEmpty) (byName[nameKey] ??= []).add(row);
      for (final also in row.entry.alsoNames) {
        final key = catalogKey(also);
        if (key.isNotEmpty) (byAlias[key] ??= []).add(row);
      }

      final head = catalogKey(row.entry.foodName.split(RegExp(r'[,/]')).first);
      if (head.isNotEmpty && head != nameKey) (byPrefix[head] ??= []).add(row);
    }

    _byKey = byKey;
    _byName = byName;
    _byAlias = byAlias;
    _byPrefix = byPrefix;
  }

  late final Map<String, CatalogRow> _byKey;
  late final Map<String, List<CatalogRow>> _byName;
  late final Map<String, List<CatalogRow>> _byAlias;
  late final Map<String, List<CatalogRow>> _byPrefix;

  /// Every row, by [CatalogSourceEntry.key].
  Map<String, CatalogRow> get rowsByKey => Map.unmodifiable(_byKey);

  /// The row [key] names, or null if no such row exists.
  CatalogRow? row(String key) => _byKey[key];

  /// The catalog row [name] refers to, via `ingredientTargets` only.
  ///
  /// Null means one of two things, and both are curation gaps to report
  /// rather than guess past: the name has no entry in the target map, or
  /// its entry points at a key no row carries.
  CatalogRow? lookup(String name) {
    final target = ingredientTargets[catalogKey(name)];
    if (target == null) return null;
    final row = _byKey[target];
    return row != null && row.isUsable ? row : null;
  }

  /// The target key [name] is mapped to, whether or not a row carries it.
  /// Used by `--check` to tell "no mapping" apart from "mapping points at
  /// a row that no longer exists".
  String? targetKeyFor(String name) => ingredientTargets[catalogKey(name)];

  /// What the old tier inference would have proposed for an unmapped
  /// [name], for `parse_catalog.dart --suggest` to print. Never consulted
  /// during a build.
  TargetSuggestion? suggest(String name) {
    final key = catalogKey(name);
    for (final (tier, table) in [
      ('name', _byName),
      ('alias', _byAlias),
      ('prefix', _byPrefix),
    ]) {
      final candidates = (table[key] ?? const <CatalogRow>[])
          .where((r) => r.isUsable)
          .toList();
      if (candidates.isNotEmpty) {
        return TargetSuggestion(name: key, candidates: candidates, tier: tier);
      }
    }
    return null;
  }
}
