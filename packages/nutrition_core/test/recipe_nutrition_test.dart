import 'package:nutrition_core/nutrition_core.dart';
import 'package:test/test.dart';

RecipeComponentInput _c(String id, double grams, Map<String, double> per100g) =>
    RecipeComponentInput(foodId: id, grams: grams, nutrientsPer100g: per100g);

void main() {
  group('§19.10s formula', () {
    test('nutrients sum over ingredients before the yield is applied', () {
      // 100 g of dal at 350 kcal/100 g plus 100 g of rice at 130: 480 kcal
      // in 200 g of ingredients, which the pot turns into 500 g of khichdi.
      final result = computeRecipeNutrition(
        components: [
          _c('dal', 100, {'energy': 350, 'protein': 24}),
          _c('rice', 100, {'energy': 130, 'protein': 3}),
        ],
        cookedGrams: 500,
      );

      expect(result.totals['energy'], closeTo(480, 1e-9));
      expect(result.rawGrams, 200);
      expect(result.cookedGrams, 500);
      expect(result.yieldFactor, closeTo(2.5, 1e-9));
      expect(result.per100g['energy'], closeTo(96, 1e-9));
      expect(result.per100g['protein'], closeTo(5.4, 1e-9));
    });

    test('cooking yield is the difference between right and 2.5x wrong', () {
      final components = [
        _c('dal', 100, {'energy': 350}),
      ];
      final assembled = computeRecipeNutrition(components: components);
      final cooked = computeRecipeNutrition(
        components: components,
        method: CookingMethod.pressureCooker,
      );

      expect(assembled.per100g['energy'], closeTo(350, 1e-9));
      expect(
        cooked.per100g['energy'],
        closeTo(140, 1e-9),
        reason: 'the same dal, diluted into the water it absorbed',
      );
    });

    test('a dish that dries out concentrates rather than dilutes', () {
      // Khakhra: 100 g of dough down to 81 g roasted.
      final result = computeRecipeNutrition(
        components: [
          _c('dough', 100, {'energy': 300}),
        ],
        cookedGrams: 81,
      );
      expect(result.yieldFactor, closeTo(0.81, 1e-9));
      expect(result.per100g['energy'], closeTo(370.37, 0.01));
    });

    test('nutrient mass is unchanged by cooking; only the water is', () {
      final raw = computeRecipeNutrition(
        components: [
          _c('dal', 100, {'iron': 7}),
        ],
      );
      final cooked = computeRecipeNutrition(
        components: [
          _c('dal', 100, {'iron': 7}),
        ],
        cookedGrams: 300,
      );
      expect(raw.totals['iron'], cooked.totals['iron']);
    });
  });

  group('where the yield factor comes from', () {
    test('a weighed cooked weight beats the cooking-method constant', () {
      final result = computeRecipeNutrition(
        components: [
          _c('rice', 100, {'energy': 130}),
        ],
        cookedGrams: 240,
        method: CookingMethod.openPot,
      );
      expect(result.basis, YieldBasis.cookedWeight);
      expect(result.yieldFactor, closeTo(2.4, 1e-9));
    });

    test('no cooked weight falls back to the method, and says so', () {
      final result = computeRecipeNutrition(
        components: [
          _c('rice', 100, {'energy': 130}),
        ],
        method: CookingMethod.openPot,
      );
      expect(result.basis, YieldBasis.cookingMethod);
      expect(result.yieldFactor, CookingMethod.openPot.yieldFactor);
    });

    test('an implausible cooked weight is treated as a typo', () {
      // 100 g of ingredients cannot become 3 kg of food; a slipped decimal
      // is far likelier, and silently accepting it would divide every
      // number in the dish by thirty.
      final result = computeRecipeNutrition(
        components: [
          _c('rice', 100, {'energy': 130}),
        ],
        cookedGrams: 3000,
        method: CookingMethod.openPot,
      );
      expect(result.basis, YieldBasis.cookingMethod);
      expect(result.yieldFactor, CookingMethod.openPot.yieldFactor);
    });

    test('an assembly takes on nothing', () {
      final result = computeRecipeNutrition(
        components: [
          _c('puffed rice', 40, {'energy': 400}),
          _c('sev', 20, {'energy': 550}),
        ],
      );
      expect(result.yieldFactor, 1);
      expect(result.cookedGrams, 60);
    });
  });

  group('unknown stays unknown (AP-4)', () {
    test('a nutrient no ingredient reports is absent, not zero', () {
      final result = computeRecipeNutrition(
        components: [
          _c('rice', 100, {'energy': 130}),
        ],
      );
      expect(result.reports('iron'), isFalse);
      expect(result.per100g.containsKey('iron'), isFalse);
      expect(result.coverageOf('iron'), 0);
    });

    test('a partly-reported nutrient carries the share it came from', () {
      // Spices are 3 g of a 103 g dish and have no iron figure. The iron
      // that is there is real; what it is missing is 3% of the dish.
      final result = computeRecipeNutrition(
        components: [
          _c('rajma', 100, {'energy': 330, 'iron': 8}),
          _c('spices', 3, {'energy': 300}),
        ],
      );
      expect(result.coverageOf('energy'), 1);
      expect(result.coverageOf('iron'), closeTo(100 / 103, 1e-9));
      expect(result.totals['iron'], closeTo(8, 1e-9));
    });

    test('a nutrient from a small minority of the dish is visibly so', () {
      final result = computeRecipeNutrition(
        components: [
          _c('rice', 200, {'energy': 130}),
          _c('garnish', 10, {'energy': 50, 'vitamin_c': 40}),
        ],
      );
      expect(
        result.coverageOf('vitamin_c'),
        closeTo(10 / 210, 1e-9),
        reason: 'the caller can see this is a figure for 5% of the dish',
      );
    });
  });

  group('degenerate input', () {
    test('no ingredients produces nothing rather than a division by zero', () {
      final result = computeRecipeNutrition(components: const []);
      expect(result.rawGrams, 0);
      expect(result.per100g, isEmpty);
      expect(result.coverage, isEmpty);
    });

    test('a zero-gram ingredient is skipped, not counted as a divisor', () {
      final result = computeRecipeNutrition(
        components: [
          _c('rice', 100, {'energy': 130}),
          _c('a pinch of nothing', 0, {'energy': 900}),
        ],
      );
      expect(result.rawGrams, 100);
      expect(result.per100g['energy'], closeTo(130, 1e-9));
    });
  });
}
