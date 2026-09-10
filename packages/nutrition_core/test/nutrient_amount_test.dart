import 'package:nutrition_core/nutrition_core.dart';
import 'package:test/test.dart';

void main() {
  group('NutrientAmount', () {
    test('KnownAmount is never equal to UnknownAmount, even at zero', () {
      // AP-4: unknown is not zero. A food that does not report a nutrient
      // must not collapse to the same representation as a measured zero.
      const known = KnownAmount(Quantity(0, Unit.gram));
      const unknown = UnknownAmount();
      expect(known, isNot(unknown));
    });

    test('KnownAmount equality is by quantity', () {
      expect(
        const KnownAmount(Quantity(12, Unit.gram)),
        const KnownAmount(Quantity(12, Unit.gram)),
      );
    });

    test('switching on the sealed type covers both variants', () {
      String describe(NutrientAmount amount) => switch (amount) {
        KnownAmount(:final quantity) => 'known: $quantity',
        UnknownAmount() => 'unknown',
      };

      expect(
        describe(const KnownAmount(Quantity(5, Unit.milligram))),
        'known: 5.0mg',
      );
      expect(describe(const UnknownAmount()), 'unknown');
    });
  });
}
