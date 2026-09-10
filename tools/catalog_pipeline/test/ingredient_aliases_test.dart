import 'dart:io';

import 'package:catalog_pipeline/catalog_pipeline.dart';
import 'package:test/test.dart';

/// The alias map is only as good as its targets: an alias pointing at a row
/// that doesn't exist, or at a name the index still can't resolve, would
/// silently put the ingredient back on the unresolved pile.
void main() {
  late CatalogIndex index;
  late List<CatalogRow> rows;

  setUpAll(() {
    final sourceParser = CatalogSourceParser();
    final compositionParser = CompositionParser();
    rows = [
      for (final file in Directory(
        '../../docs/catalog',
      ).listSync().whereType<File>())
        if (file.path.endsWith('.md') && !file.path.endsWith('README.md'))
          for (final entry in sourceParser.parseFile(file))
            CatalogRow(entry, compositionParser.parse(entry.rawComposition)),
    ];
    index = CatalogIndex(rows);
  });

  test('every alias resolves to a real, usable catalog row', () {
    final unresolved = <String, String>{};
    for (final alias in ingredientAliases.entries) {
      if (index.lookup(alias.key) == null) {
        unresolved[alias.key] = alias.value;
      }
    }
    expect(
      unresolved,
      isEmpty,
      reason: 'these aliases point at rows the index cannot resolve',
    );
  });

  test('an alias beats the ambiguity that would otherwise drop the name', () {
    // "oil" heads six rows, so the tier rules drop it; the alias settles it.
    expect(index.lookup('oil')?.entry.foodName, 'Groundnut oil');
    expect(index.lookup('curd')?.entry.foodName, 'Curd, plain');
    expect(index.lookup('milk')?.entry.foodName, 'Milk, cow, whole');
  });

  test('bare rice is raw and "rice cooked" is cooked', () {
    // The catalog's own convention: `Khichdi, plain` lists `Rice 45 g` for a
    // 180 g katori, while rows meaning cooked say so and use 2-3x the
    // quantity. Getting this backwards mis-states energy by ~2.7x.
    expect(index.lookup('rice')?.entry.foodName, 'Rice, white, raw');
    expect(index.lookup('rice cooked')?.entry.foodName, 'Rice, white, cooked');
  });

  test('the batter behind idli, dosa and uttapam resolves to one row', () {
    for (final name in ['idli batter', 'dosa batter', 'rice batter']) {
      expect(
        index.lookup(name)?.entry.foodName,
        'Idli rice + urad batter',
        reason: name,
      );
    }
  });

  test('water is carried as a nutrient-free ingredient, not dropped', () {
    // It contributes mass, and the yield factor is mass-derived — skipping
    // it would concentrate everything else in the dish.
    expect(waterIngredients, contains('water'));
  });

  test('a slashed alternate takes the fat the curator named first', () {
    expect(index.lookup('oil/ghee')?.entry.foodName, 'Groundnut oil');
    expect(index.lookup('ghee/oil')?.entry.foodName, 'Ghee');
    expect(index.lookup('butter/oil')?.entry.foodName, 'Butter');
  });

  test('every recipe in the catalog resolves all of its ingredients', () {
    // The guard that matters. A dish nobody can resolve is a dish the app
    // cannot offer, so this failing means a new row needs an alias — not
    // that the dish should quietly fall back to an FDC text search.
    bool resolves(String name, Set<String> visiting, List<String> missing) {
      final key = catalogKey(name);
      if (waterIngredients.contains(key)) return true;
      if (visiting.contains(key) || visiting.length >= 5) return false;
      final row = index.lookup(name);
      if (row == null) {
        missing.add(name);
        return false;
      }
      final composition = row.composition;
      if (composition is UsdaLookup) return true;
      if (composition is Recipe) {
        var all = true;
        for (final ingredient in composition.ingredients) {
          if (!resolves(ingredient.name, {...visiting, key}, missing)) {
            all = false;
          }
        }
        return all;
      }
      missing.add(name);
      return false;
    }

    final blocked = <String, List<String>>{};
    for (final row in rows) {
      final composition = row.composition;
      if (composition is! Recipe) continue;
      final missing = <String>[];
      for (final ingredient in composition.ingredients) {
        resolves(ingredient.name, {catalogKey(row.entry.foodName)}, missing);
      }
      if (missing.isNotEmpty) blocked[row.entry.foodName] = missing;
    }
    expect(
      blocked,
      isEmpty,
      reason: 'dish -> the ingredients it cannot resolve',
    );
  });

  test('the staples that broke the seed now resolve from the catalog', () {
    // Each of these previously fell through to a blind FDC search and came
    // back as the wrong food entirely.
    const previouslyMisResolved = {
      'oil': 'Groundnut oil',
      'rava': 'Semolina, rava',
      'coconut': 'Coconut, fresh grated',
      'vegetables': 'Mixed vegetables',
      'refined flour': 'Refined flour, maida',
    };
    previouslyMisResolved.forEach((name, expected) {
      expect(index.lookup(name)?.entry.foodName, expected, reason: name);
    });
  });
}
