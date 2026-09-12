// A committed record of what every catalog row resolves to, so that
// adding rows cannot quietly change the ones already there.
//
// This is a golden-file test for food data — the same instinct as the
// golden nutrient vectors in `nutrition_core`, applied one level up. The
// question it answers is the one nobody could answer before: *did my new
// row change an existing dish?* Without it, the two ways that happens are
// invisible until someone eats the difference — an ingredient that stops
// resolving takes its whole dish out of the seed behind a stderr line,
// and an ingredient that resolves to a *different* row takes nothing out
// at all and just reports the wrong numbers.
//
// Everything in the lock is computed **offline**, from the markdown and
// the target table alone. No network, no API key, so it is what CI checks
// and what an editor runs before handing the catalog over for a fetch.
import 'dart:convert';

import 'catalog_index.dart';
import 'composition.dart';
import 'ingredient_targets.dart';
import 'recipe_yield.dart';

/// One row's resolution, as the lock records it.
class LockedRow {
  const LockedRow({
    required this.key,
    required this.name,
    required this.sourceFile,
    required this.kind,
    required this.servingGrams,
    required this.ingredients,
    required this.rawIngredientGrams,
    required this.yieldFactor,
    required this.yieldBasis,
  });

  factory LockedRow.fromJson(String key, Map<String, dynamic> json) =>
      LockedRow(
        key: key,
        name: json['name'] as String,
        sourceFile: json['sourceFile'] as String,
        kind: json['kind'] as String,
        servingGrams: (json['servingGrams'] as num).toDouble(),
        ingredients: {
          for (final e in (json['ingredients'] as Map? ?? const {}).entries)
            e.key as String: e.value as String,
        },
        rawIngredientGrams: (json['rawIngredientGrams'] as num?)?.toDouble(),
        yieldFactor: (json['yieldFactor'] as num?)?.toDouble(),
        yieldBasis: json['yieldBasis'] as String?,
      );

  final String key;
  final String name;
  final String sourceFile;

  /// `usda` | `recipe` | `review`.
  final String kind;
  final double servingGrams;

  /// Ingredient string -> the row key it resolves to. Empty for a
  /// non-recipe row. **This is the field the whole file exists for.**
  final Map<String, String> ingredients;

  final double? rawIngredientGrams;
  final double? yieldFactor;
  final String? yieldBasis;

  Map<String, dynamic> toJson() => {
    'name': name,
    'sourceFile': sourceFile,
    'kind': kind,
    'servingGrams': servingGrams,
    if (ingredients.isNotEmpty)
      'ingredients': {
        for (final name in ingredients.keys.toList()..sort())
          name: ingredients[name]!,
      },
    if (rawIngredientGrams != null)
      'rawIngredientGrams': _round(rawIngredientGrams!),
    if (yieldFactor != null) 'yieldFactor': _round(yieldFactor!),
    if (yieldBasis != null) 'yieldBasis': yieldBasis,
  };

  /// Three decimals: enough that a real change shows, coarse enough that
  /// floating-point noise does not make the lock churn.
  static double _round(double v) => (v * 1000).round() / 1000;
}

/// What changed between two locks. [isBreaking] is what CI fails on.
class LockChange {
  const LockChange(this.severity, this.key, this.message);

  /// `added` | `removed` | `retargeted` | `moved`.
  final String severity;
  final String key;
  final String message;

  /// A retarget silently changes an existing dish's numbers, and a
  /// removal takes a dish out of the app. Both need a human to have meant
  /// them. An addition never breaks anything.
  bool get isBreaking => severity == 'retargeted' || severity == 'removed';

  @override
  String toString() => '[$severity] $key: $message';
}

/// The resolution of every row in the catalog, keyed by
/// [CatalogSourceEntry.key].
class CatalogLock {
  const CatalogLock(this.rows);

  /// Builds the lock from parsed rows.
  ///
  /// The yield figures come from [resolveRecipeYield] itself, called with
  /// empty nutrient maps — the factor, the basis and the raw weight are
  /// pure arithmetic over quantities, so this mirrors production exactly
  /// instead of reimplementing it and drifting.
  factory CatalogLock.fromRows(
    Iterable<CatalogRow> catalogRows,
    CatalogIndex index,
  ) {
    final rows = <String, LockedRow>{};
    for (final row in catalogRows) {
      final composition = row.composition;
      final kind = switch (composition) {
        UsdaLookup() => 'usda',
        Recipe() => 'recipe',
        NeedsManualReview() => 'review',
      };

      var ingredients = const <String, String>{};
      double? rawGrams;
      double? yieldFactor;
      String? basis;

      if (composition is Recipe && composition.ingredients.isNotEmpty) {
        ingredients = {
          for (final ingredient in composition.ingredients)
            catalogKey(ingredient.name): _targetFor(ingredient.name),
        };
        final result = resolveRecipeYield([
          for (final ingredient in composition.ingredients)
            ResolvedIngredient(ingredient, const {}),
        ], servingGrams: row.entry.servingAmount);
        rawGrams = result.rawIngredientGrams;
        yieldFactor = result.yieldFactor;
        basis = result.basis.name;
      }

      rows[row.entry.key] = LockedRow(
        key: row.entry.key,
        name: row.entry.foodName,
        sourceFile: row.entry.sourceFile,
        kind: kind,
        servingGrams: row.entry.servingAmount,
        ingredients: ingredients,
        rawIngredientGrams: rawGrams,
        yieldFactor: yieldFactor,
        yieldBasis: basis,
      );
    }
    return CatalogLock(rows);
  }

  factory CatalogLock.fromJson(Map<String, dynamic> json) {
    final rows = (json['rows'] as Map).cast<String, dynamic>();
    return CatalogLock({
      for (final entry in rows.entries)
        entry.key: LockedRow.fromJson(
          entry.key,
          entry.value as Map<String, dynamic>,
        ),
    });
  }

  final Map<String, LockedRow> rows;

  /// `water` for an ingredient carried as nutrient-free mass, the mapped
  /// key when there is one, and `UNMAPPED` when there is not — recorded
  /// rather than thrown on, so `--check` can report every gap in one pass
  /// instead of stopping at the first.
  static String _targetFor(String name) {
    final key = catalogKey(name);
    if (waterIngredients.contains(key)) return 'water';
    return ingredientTargets[key] ?? 'UNMAPPED';
  }

  /// Every difference from [previous], newest state as `this`.
  List<LockChange> diff(CatalogLock previous) {
    final changes = <LockChange>[];

    for (final key in previous.rows.keys) {
      if (!rows.containsKey(key)) {
        changes.add(
          LockChange(
            'removed',
            key,
            '"${previous.rows[key]!.name}" is gone. If you renamed or moved '
                'the row, its key changed and history for it is lost — say '
                'so deliberately.',
          ),
        );
      }
    }

    for (final entry in rows.entries) {
      final now = entry.value;
      final before = previous.rows[entry.key];
      if (before == null) {
        changes.add(LockChange('added', entry.key, '"${now.name}" is new.'));
        continue;
      }

      for (final ingredient in now.ingredients.entries) {
        final was = before.ingredients[ingredient.key];
        if (was == null) continue; // a new ingredient on an existing row
        if (was != ingredient.value) {
          changes.add(
            LockChange(
              'retargeted',
              entry.key,
              'ingredient "${ingredient.key}" resolved to $was, now resolves '
                  'to ${ingredient.value}. Adding a row must never change '
                  'what an existing ingredient means.',
            ),
          );
        }
      }

      if (before.yieldFactor != null &&
          now.yieldFactor != null &&
          (before.yieldFactor! - now.yieldFactor!).abs() > 0.005) {
        changes.add(
          LockChange(
            'moved',
            entry.key,
            'yield factor ${before.yieldFactor} -> ${now.yieldFactor}.',
          ),
        );
      }
    }

    return changes;
  }

  Map<String, dynamic> toJson() => {
    'note':
        'Generated by parse_catalog.dart --write-lock. One entry per '
        'catalog row recording what its ingredients resolve to, so that '
        'adding a row cannot silently change a dish already here. '
        'Computed offline: no network, no API key.',
    'rowCount': rows.length,
    'rows': {
      for (final key in rows.keys.toList()..sort()) key: rows[key]!.toJson(),
    },
  };

  String encode() =>
      '${const JsonEncoder.withIndent('  ').convert(toJson())}\n';
}
