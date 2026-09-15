import 'package:catalog_pipeline/catalog_pipeline.dart';
import 'package:test/test.dart';

import '../bin/fetch_catalog.dart';

/// Answers each query from a script, so a test can put a wrong food in
/// front of the right one and see which the resolver takes.
class _ScriptedFdc implements FdcSource {
  _ScriptedFdc(this.byQuery);

  final Map<String, List<FdcFood>> byQuery;
  final asked = <String>[];

  @override
  Future<List<FdcFood>> search(
    String query, {
    int pageSize = 5,
    String? dataType = FdcClient.preferredDataTypes,
  }) async {
    asked.add(query);
    return byQuery[query] ?? const [];
  }

  @override
  Future<FdcFood> getDetails(int fdcId) async =>
      byQuery.values.expand((f) => f).firstWhere((f) => f.fdcId == fdcId);

  @override
  void close() {}
}

FdcFood _food(int id, String description, Map<String, double> nutrients) =>
    FdcFood(
      fdcId: id,
      description: description,
      dataType: 'SR Legacy',
      nutrients: [
        for (final e in nutrients.entries)
          FdcNutrientReading(
            name: e.key,
            unit: e.key == 'Energy' ? 'KCAL' : 'G',
            amountPer100g: e.value,
          ),
      ],
    );

/// Returns the same food for any search, so the test is about which rows
/// the resolver reaches, not about FDC matching.
class _FakeFdc implements FdcSource {
  static const _lentils = FdcFood(
    fdcId: 1,
    description: 'Lentils, raw',
    dataType: 'SR Legacy',
    nutrients: [
      FdcNutrientReading(name: 'Energy', unit: 'KCAL', amountPer100g: 352),
    ],
  );

  @override
  Future<List<FdcFood>> search(
    String query, {
    int pageSize = 5,
    String? dataType = FdcClient.preferredDataTypes,
  }) async => const [_lentils];

  @override
  Future<FdcFood> getDetails(int fdcId) async => _lentils;

  @override
  void close() {}
}

CatalogRow _row({
  required String sourceFile,
  required String foodName,
  required String composition,
  double servingAmount = 100,
}) {
  final entry = CatalogSourceEntry(
    sourceFile: sourceFile,
    section: 'test',
    isTier1: false,
    foodName: foodName,
    alsoNames: const [],
    servingLabel: '100 g',
    servingAmount: servingAmount,
    weightColumnLabel: 'g',
    rawComposition: composition,
  );
  return CatalogRow(entry, CompositionParser().parse(composition));
}

void main() {
  test(
    'a dish resolves through an ingredient row that shares its name',
    () async {
      // The case that broke: `Masoor dal` the dish is cooked from
      // `Masoor dal` the raw pulse, and `ingredientTargets` sends that
      // ingredient name to the separate row `01:masoor-dal-raw`. A cycle
      // guard keyed on the *name* read that as self-reference and dropped
      // the dish; keyed on the row it targets, there is no cycle.
      final dish = _row(
        sourceFile: 'nourishly_indian_food_catalog.csv',
        foodName: 'Masoor dal',
        composition: 'Masoor dal 30 g raw, Water 150 ml',
      );
      final pulse = _row(
        sourceFile: '01-common.md',
        foodName: 'Masoor dal, raw',
        composition: 'USDA lentils raw',
      );
      expect(pulse.entry.key, '01:masoor-dal-raw');
      expect(ingredientTargets['masoor dal'], pulse.entry.key);

      // Both spellings of the dish's own identity: the row key the caller
      // seeds `visiting` with today, and the normalized name it used to
      // seed — the one that collided with the ingredient.
      for (final seed in [dish.entry.key, catalogKey(dish.entry.foodName)]) {
        final resolver = IngredientResolver(
          client: _FakeFdc(),
          normalizer: FdcNormalizer(),
          index: CatalogIndex([dish, pulse]),
        );

        final source = await resolver.resolve('Masoor dal', {seed});
        expect(source, isNotNull, reason: 'seeded with $seed');
        expect(source!.food?.description, 'Lentils, raw');
      }
    },
  );

  test('a row that lists itself still bails instead of looping', () async {
    // `masoor dal` targets `01:masoor-dal-raw`, so a row carrying that key
    // and listing the ingredient is a genuine cycle.
    final selfReferential = _row(
      sourceFile: '01-common.md',
      foodName: 'Masoor dal, raw',
      composition: 'Masoor dal 30 g, Water 150 ml',
    );

    final resolver = IngredientResolver(
      client: _FakeFdc(),
      normalizer: FdcNormalizer(),
      index: CatalogIndex([selfReferential]),
    );

    expect(await resolver.resolve('Masoor dal', <String>{}), isNull);
  });

  group('a wrong search result is refused, not summed', () {
    CatalogRow saltRow() => _row(
      sourceFile: '01-common.md',
      foodName: 'Salt',
      composition: 'USDA salt table',
    );

    test('the candidate that names a different food is skipped', () async {
      // What shipped: a search for salt returned `Butter, salted` first,
      // the pipeline took it, and 999 recipes gained butter's 717 kcal
      // and 81 g of fat. The hint query now finds the real record, and
      // the butter is refused on the way past.
      final client = _ScriptedFdc({
        'salt table': [
          _food(1, 'Butter, salted', {'Energy': 717, 'Total lipid (fat)': 81}),
          _food(2, 'Salt, table', {'Energy': 0, 'Protein': 0}),
        ],
      });
      final row = saltRow();
      final resolver = IngredientResolver(
        client: client,
        normalizer: FdcNormalizer(),
        index: CatalogIndex([row]),
      );

      final source = await resolver.resolve('Salt', <String>{});
      expect(source?.food?.description, 'Salt, table');
      expect(resolver.rejected, hasLength(1));
      expect(resolver.rejected.single.reason, contains('different food'));
    });

    test('a record with no proximates is skipped', () async {
      // `Oil, peanut` (Foundation): 90 nutrients, no macros. Taking it
      // gave the default cooking fat no calories in 787 recipes.
      final client = _ScriptedFdc({
        'oil peanut salad or cooking': [
          _food(1, 'Oil, peanut', {'Vitamin E': 15.2}),
          _food(2, 'Oil, peanut, salad or cooking', {
            'Energy': 884,
            'Total lipid (fat)': 100,
          }),
        ],
      });
      final row = _row(
        sourceFile: '01-common.md',
        foodName: 'Groundnut oil',
        composition: 'USDA oil peanut salad or cooking',
      );
      final resolver = IngredientResolver(
        client: client,
        normalizer: FdcNormalizer(),
        index: CatalogIndex([row]),
      );

      final source = await resolver.resolve('Groundnut oil', <String>{});
      expect(source?.food?.description, 'Oil, peanut, salad or cooking');
      expect(resolver.rejected.single.reason, contains('no energy'));
    });

    test(
      'a row where nothing survives resolves to null, not to a guess',
      () async {
        final client = _ScriptedFdc({
          'salt table': [
            _food(1, 'Butter, salted', {'Energy': 717}),
          ],
        });
        final row = saltRow();
        final resolver = IngredientResolver(
          client: client,
          normalizer: FdcNormalizer(),
          index: CatalogIndex([row]),
        );

        expect(await resolver.resolve('Salt', <String>{}), isNull);
        expect(resolver.rejected, isNotEmpty);
      },
    );
  });

  group('a pinned row', () {
    test('fetches its record and never searches', () async {
      // The guarantee the pin exists for: FDC's ranking put salt on
      // `Butter, salted` and spinach on spinach souffle, and the search
      // reran every fetch. A pinned row asks nothing.
      final client = _ScriptedFdc({
        'salt table': [
          _food(1, 'Butter, salted', {'Energy': 717}),
        ],
        '#pinned': [
          _food(173468, 'Salt, table', {'Energy': 0, 'Protein': 0}),
        ],
      });
      final row = _row(
        sourceFile: '01-common.md',
        foodName: 'Salt',
        composition: 'USDA #173468 salt table',
      );
      final resolver = IngredientResolver(
        client: client,
        normalizer: FdcNormalizer(),
        index: CatalogIndex([row]),
      );

      final source = await resolver.resolve('Salt', <String>{});
      expect(source?.food?.description, 'Salt, table');
      expect(client.asked, isEmpty, reason: 'a pin must not search');
      expect(resolver.rejected, isEmpty);
    });
  });
}
