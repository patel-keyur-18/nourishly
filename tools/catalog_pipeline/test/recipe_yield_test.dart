import 'package:catalog_pipeline/catalog_pipeline.dart';
import 'package:test/test.dart';

void main() {
  group('gramsForIngredient', () {
    test('grams and kilograms pass through', () {
      expect(
        gramsForIngredient(const RecipeIngredient('Toor dal', 30, 'g')),
        30,
      );
      expect(gramsForIngredient(const RecipeIngredient('Rice', 1, 'kg')), 1000);
    });

    test('volumes assume water-like density by default', () {
      expect(
        gramsForIngredient(const RecipeIngredient('Water', 150, 'ml')),
        150,
      );
      expect(gramsForIngredient(const RecipeIngredient('Oil', 1, 'tsp')), 5);
      expect(gramsForIngredient(const RecipeIngredient('Ghee', 1, 'tbsp')), 15);
    });

    test('a tumbler is the 170 g household starting estimate', () {
      expect(
        gramsForIngredient(const RecipeIngredient('Rice', 2, 'tumbler')),
        340,
      );
    });

    test('rejects a unit it does not know', () {
      expect(
        () => gramsForIngredient(const RecipeIngredient('Rice', 1, 'cup')),
        throwsArgumentError,
      );
    });
  });

  group('inferCookingMethod', () {
    test('a dal ingredient means pressure cooker', () {
      const recipe = Recipe([
        RecipeIngredient('Toor dal', 30, 'g'),
        RecipeIngredient('Turmeric', 1, 'g'),
      ], []);
      expect(inferCookingMethod(recipe), CookingMethod.pressureCooker);
    });

    test('rice with no dal ingredient means open pot', () {
      const recipe = Recipe([
        RecipeIngredient('Rice', 45, 'g'),
        RecipeIngredient('Ghee', 5, 'g'),
      ], []);
      expect(inferCookingMethod(recipe), CookingMethod.openPot);
    });
  });

  group('resolveRecipeYield', () {
    test('sums nutrients and divides by cooked (yield-adjusted) weight', () {
      // 100 g toor dal, raw: 22 kcal/g scaled down to keep the numbers
      // simple — 2200 kcal per 100 g raw isn't realistic, but the
      // arithmetic under test doesn't care.
      final result = resolveRecipeYield([
        const ResolvedIngredient(
          RecipeIngredient('Toor dal', 30, 'g', note: 'raw'),
          {'energy': 300},
        ),
      ]);

      expect(result.method, CookingMethod.pressureCooker);
      expect(result.yieldFactor, 2.5);
      expect(result.rawIngredientGrams, 30);
      expect(result.cookedGrams, 75);
      // 30 g raw contributes 30/100 * 300 = 90 kcal total; spread over
      // 75 g cooked and re-based to per-100g: 90 / 75 * 100 = 120.
      expect(result.nutrientsPer100g['energy'], closeTo(120, 0.001));
    });

    test('an explicit method overrides the inferred one', () {
      final result = resolveRecipeYield([
        const ResolvedIngredient(RecipeIngredient('Rice', 45, 'g'), {
          'energy': 360,
        }),
      ], method: CookingMethod.pressureCooker);

      expect(result.method, CookingMethod.pressureCooker);
      expect(result.yieldFactor, 2.5);
    });

    test('multiple ingredients sum before the yield factor is applied', () {
      final result = resolveRecipeYield([
        const ResolvedIngredient(RecipeIngredient('Rice', 45, 'g'), {
          'energy': 360,
          'protein': 8,
        }),
        const ResolvedIngredient(RecipeIngredient('Moong dal', 20, 'g'), {
          'energy': 340,
          'protein': 24,
        }),
      ]);

      expect(result.method, CookingMethod.pressureCooker);
      expect(result.rawIngredientGrams, 65);
      expect(result.cookedGrams, closeTo(162.5, 0.001));
    });
  });
}
