import 'package:nutrition_core/nutrition_core.dart';
import 'package:test/test.dart';

void main() {
  group('Unit', () {
    test(
      'symbols match the canonical units used across the architecture docs',
      () {
        expect(Unit.kcal.symbol, 'kcal');
        expect(Unit.gram.symbol, 'g');
        expect(Unit.milligram.symbol, 'mg');
        expect(Unit.microgram.symbol, 'ug');
        expect(Unit.milliliter.symbol, 'ml');
        expect(Unit.liter.symbol, 'L');
      },
    );
  });

  group('Quantity', () {
    test('equal amount and unit are equal', () {
      expect(const Quantity(95, Unit.gram), const Quantity(95, Unit.gram));
    });

    test('different units are not equal even with the same amount', () {
      expect(
        const Quantity(1, Unit.gram),
        isNot(const Quantity(1, Unit.milligram)),
      );
    });
  });
}
