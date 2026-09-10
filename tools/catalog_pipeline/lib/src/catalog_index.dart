import 'package:meta/meta.dart';

import 'catalog_source_entry.dart';
import 'composition.dart';
import 'ingredient_aliases.dart';

/// One catalog row paired with its parsed [Composition].
@immutable
class CatalogRow {
  const CatalogRow(this.entry, this.composition);

  final CatalogSourceEntry entry;
  final Composition composition;

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

/// Name -> catalog row, for resolving a recipe ingredient that is itself a
/// catalog entry rather than something FDC has ever heard of.
///
/// This exists because the catalog is compositional: "Bhel" lists `sev`,
/// "Mohanthal" lists `khoya`, "Kothu parotta" lists `Parotta` — all of
/// which are catalog rows, none of which FDC can match on the regional
/// name. Direct-USDA entries already get their `Also` synonyms tried as
/// search terms; this gives recipe ingredients the same reach, plus the
/// ability to resolve an ingredient recursively through its own recipe.
///
/// Three tiers of key, each fully exhausted before the next is consulted:
/// 1. the row's own name ("Patra", "Fafda", "Kesari bath")
/// 2. every `Also` synonym ("dudhi" -> Bottle gourd, "moth bean" -> Matki)
/// 3. the name's leading segment before a `,` or `/` ("Sev, thin" -> "sev",
///    "Khoya / Mawa" -> "khoya")
///
/// The tiers are ranked, not merged, because a row's own name is stronger
/// evidence than some other row's synonym: "Kesari bath" is a dish in
/// 04-karnataka.md *and* an `Also` for Tamil Nadu's "Rava kesari", and the
/// row actually named that is the one to take.
///
/// Within a tier, a key that several rows claim is **dropped**, not guessed
/// at — "dosa" and "palya" each head three-to-five rows, and picking one
/// silently would put the wrong dish's nutrients in the answer. Those fall
/// through to the plain FDC search, exactly as before this index existed.
/// The one exception is a tie where all but one candidate is
/// [NeedsManualReview]: "Muthiya, steamed" vs "Muthiya, fried" ("As above +
/// absorbed oil"), where only the steamed row can be resolved at all.
class CatalogIndex {
  CatalogIndex(Iterable<CatalogRow> rows) {
    final byName = <String, List<CatalogRow>>{};
    final byAlias = <String, List<CatalogRow>>{};
    final byPrefix = <String, List<CatalogRow>>{};

    for (final row in rows) {
      final nameKey = catalogKey(row.entry.foodName);
      if (nameKey.isNotEmpty) (byName[nameKey] ??= []).add(row);
      for (final also in row.entry.alsoNames) {
        final key = catalogKey(also);
        if (key.isNotEmpty) (byAlias[key] ??= []).add(row);
      }

      final head = catalogKey(row.entry.foodName.split(RegExp(r'[,/]')).first);
      if (head.isNotEmpty && head != nameKey) (byPrefix[head] ??= []).add(row);
    }

    _byName = _collapse(byName);
    _byAlias = _collapse(byAlias);
    _byPrefix = _collapse(byPrefix);
  }

  late final Map<String, CatalogRow> _byName;
  late final Map<String, CatalogRow> _byAlias;
  late final Map<String, CatalogRow> _byPrefix;

  /// Keeps only keys that resolve to exactly one usable row. A
  /// [NeedsManualReview] row is not usable, so it never wins a key and
  /// never blocks a sibling that is resolvable.
  static Map<String, CatalogRow> _collapse(Map<String, List<CatalogRow>> raw) {
    final out = <String, CatalogRow>{};
    for (final entry in raw.entries) {
      final usable = entry.value
          .where((r) => r.composition is! NeedsManualReview)
          .toList();
      if (usable.length == 1) out[entry.key] = usable.single;
    }
    return out;
  }

  /// The single catalog row [name] refers to, or null when nothing matches
  /// or several rows do.
  ///
  /// [ingredientAliases] is consulted first: it exists precisely to settle
  /// the names the tier rules drop for ambiguity (`oil`, `curd`, `rice`),
  /// and a curated decision outranks any inference from the name alone.
  CatalogRow? lookup(String name) {
    final key = catalogKey(name);
    if (ingredientAliases[key] case final target?) {
      final targetKey = catalogKey(target);
      final row =
          _byName[targetKey] ?? _byAlias[targetKey] ?? _byPrefix[targetKey];
      if (row != null) return row;
    }
    return _byName[key] ?? _byAlias[key] ?? _byPrefix[key];
  }
}
