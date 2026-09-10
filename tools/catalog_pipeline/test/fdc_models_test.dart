import 'package:catalog_pipeline/catalog_pipeline.dart';
import 'package:test/test.dart';

/// Synthetic fixtures shaped like FDC API responses — hand-built from the
/// documented response shape, not captured from a live call (this
/// environment has no network access to FDC to capture one from). They
/// exist to pin down this pipeline's JSON parsing, not to assert any real
/// nutrition fact. **Run `bin/fetch_catalog.dart` against a live response
/// once network access exists, to confirm these shapes still match.**
void main() {
  group('FdcNutrientReading.fromJson', () {
    test(
      'parses the search-endpoint shape (flat nutrientName/unitName/value)',
      () {
        final reading = FdcNutrientReading.fromJson({
          'nutrientName': 'Protein',
          'unitName': 'G',
          'value': 7.1,
        });

        expect(reading, isNotNull);
        expect(reading!.name, 'Protein');
        expect(reading.unit, 'G');
        expect(reading.amountPer100g, 7.1);
      },
    );

    test(
      'parses the food-details-endpoint shape (nested nutrient + amount)',
      () {
        final reading = FdcNutrientReading.fromJson({
          'nutrient': {'name': 'Protein', 'unitName': 'G'},
          'amount': 7.1,
        });

        expect(reading, isNotNull);
        expect(reading!.name, 'Protein');
        expect(reading.amountPer100g, 7.1);
      },
    );

    test(
      'returns null rather than throwing when a required field is missing',
      () {
        expect(
          FdcNutrientReading.fromJson({'unitName': 'G', 'value': 7.1}),
          isNull,
        );
      },
    );
  });

  group('FdcFood.fromJson', () {
    test('parses a food with multiple nutrient readings', () {
      final food = FdcFood.fromJson({
        'fdcId': 169414,
        'description': 'Rice, white, long-grain, regular, cooked',
        'dataType': 'SR Legacy',
        'foodNutrients': [
          {'nutrientName': 'Energy', 'unitName': 'KCAL', 'value': 130},
          {'nutrientName': 'Protein', 'unitName': 'G', 'value': 2.69},
        ],
      });

      expect(food.fdcId, 169414);
      expect(food.description, 'Rice, white, long-grain, regular, cooked');
      expect(food.nutrients, hasLength(2));
    });

    test('a food with no foodNutrients array parses to an empty list, not an error', () {
      final food = FdcFood.fromJson({'fdcId': 1, 'description': 'Test food'});
      expect(food.nutrients, isEmpty);
    });
  });
}
