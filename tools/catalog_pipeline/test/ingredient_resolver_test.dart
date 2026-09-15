import 'package:catalog_pipeline/catalog_pipeline.dart';
import 'package:test/test.dart';

import '../bin/fetch_catalog.dart';

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
}
