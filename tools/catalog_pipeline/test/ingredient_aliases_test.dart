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

  test('a name with no honest single row stays unresolved', () {
    // These are reported as curation gaps rather than guessed at: ghee is
    // ~62% saturated against groundnut oil's ~17%, a sugar syrup's ratio is
    // nowhere in the source tables, and soaked dal weighs ~2x its dry self.
    for (final name in [
      'oil/ghee',
      'sugar syrup',
      'moong dal soaked',
      'sambar podi',
      'khoya-coconut filling',
    ]) {
      expect(index.lookup(name), isNull, reason: name);
    }
  });

  test(
    'a distinct food gets its own row rather than a near-neighbour alias',
    () {
      // The alternative was aliasing each of these to something close enough
      // (pav to bread, hung curd to curd, colocasia leaves to the root), which
      // is the same wrong-food bug the alias map exists to stop.
      for (final name in [
        'Pav',
        'Broken wheat',
        'Puffed rice',
        'Hung curd',
        'Colocasia leaves',
        'Black pepper',
        'Flaxseed',
      ]) {
        expect(index.lookup(name)?.entry.foodName, name, reason: name);
      }
    },
  );

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
