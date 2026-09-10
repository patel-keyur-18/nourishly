import 'package:catalog_pipeline/catalog_pipeline.dart';
import 'package:test/test.dart';

void main() {
  final normalizer = FdcNormalizer();

  test('matches microgram nutrients reported with the µg symbol, not just ASCII "UG"', () {
    // Confirmed against a live /food/{id} response: the details endpoint
    // reports "µg" (micro sign), unlike the search endpoint's "UG" text.
    // This previously made folate/B12/vitamin A/vitamin D match on zero
    // of 123 real catalog foods.
    final food = FdcFood.fromJson({
      'fdcId': 1,
      'description': 'Milk, whole',
      'foodNutrients': [
        {
          'nutrient': {'name': 'Folate, total', 'unitName': 'µg'},
          'amount': 7.0,
        },
        {
          'nutrient': {'name': 'Vitamin B-12', 'unitName': 'µg'},
          'amount': 2.28,
        },
      ],
    });

    final resolved = normalizer.normalize(food);

    expect(
      resolved.matches.map((m) => m.nutrient.id),
      containsAll(['folate', 'vitamin_b12']),
    );
  });

  test('matches "Total Sugars" (the real SR Legacy name, confirmed live)', () {
    final food = FdcFood.fromJson({
      'fdcId': 1,
      'description': 'Milk, whole',
      'foodNutrients': [
        {'nutrientName': 'Total Sugars', 'unitName': 'G', 'value': 5.05},
      ],
    });

    final resolved = normalizer.normalize(food);

    expect(resolved.matches.single.nutrient.id, 'sugar');
  });

  test('matches registry nutrients by name and unit', () {
    final food = FdcFood.fromJson({
      'fdcId': 1,
      'description': 'Toor dal, raw',
      'foodNutrients': [
        {'nutrientName': 'Energy', 'unitName': 'KCAL', 'value': 343},
        {'nutrientName': 'Protein', 'unitName': 'G', 'value': 22.3},
        {'nutrientName': 'Iron, Fe', 'unitName': 'MG', 'value': 5.2},
      ],
    });

    final resolved = normalizer.normalize(food);

    expect(resolved.matches, hasLength(3));
    expect(
      resolved.matches.map((m) => m.nutrient.id),
      containsAll(['energy', 'protein', 'iron']),
    );
    expect(
      resolved.matches
          .firstWhere((m) => m.nutrient.id == 'protein')
          .amountPer100g,
      22.3,
    );
  });

  test('a registry nutrient with no matching reading is simply absent, not zero (AP-4)', () {
    final food = FdcFood.fromJson({
      'fdcId': 1,
      'description': 'Water',
      'foodNutrients': [
        {'nutrientName': 'Energy', 'unitName': 'KCAL', 'value': 0},
      ],
    });

    final resolved = normalizer.normalize(food);

    expect(resolved.matches, hasLength(1));
    expect(
      resolved.matches.map((m) => m.nutrient.id),
      isNot(contains('protein')),
    );
  });

  test(
    'a name match with the wrong unit does not match (Energy KCAL vs KJ)',
    () {
      final food = FdcFood.fromJson({
        'fdcId': 1,
        'description': 'Test food',
        'foodNutrients': [
          {'nutrientName': 'Energy', 'unitName': 'KJ', 'value': 544},
        ],
      });

      final resolved = normalizer.normalize(food);

      expect(resolved.matches, isEmpty);
    },
  );

  test(
    'an alias name resolves the same as the primary name (Sugars, total)',
    () {
      final food = FdcFood.fromJson({
        'fdcId': 1,
        'description': 'Test food',
        'foodNutrients': [
          {'nutrientName': 'Sugars, total', 'unitName': 'G', 'value': 4.2},
        ],
      });

      final resolved = normalizer.normalize(food);

      expect(resolved.matches.single.nutrient.id, 'sugar');
    },
  );

  test(
    'an unrecognized FDC nutrient name is reported, not silently dropped',
    () {
      final food = FdcFood.fromJson({
        'fdcId': 1,
        'description': 'Test food',
        'foodNutrients': [
          {
            'nutrientName': 'Some Future Nutrient',
            'unitName': 'MG',
            'value': 1,
          },
        ],
      });

      final resolved = normalizer.normalize(food);

      expect(resolved.matches, isEmpty);
      expect(resolved.unmatchedFdcNutrients, ['Some Future Nutrient']);
    },
  );
}
