import 'package:meta/meta.dart';

import 'composition.dart';

/// How a dish is cooked, which decides how much of its added water is
/// still in the pot when it's served — the "apply yield factor for
/// cooking water" step in catalog spec §0.2's worked example, and the
/// value `FoodItems.yieldFactor` exists to hold (`catalog_tables.dart`).
///
/// Decided 2026-09-10 from a household kitchen-scale check rather than a
/// per-dish measurement (§0.3 — these are starting estimates, not
/// measurements, same as every serving weight in the catalog):
/// - **Pressure cooker** — dal and other pulses. Sealed, so evaporation
///   is negligible; almost all the water that goes in stays in.
/// - **Open pot** — rice and everything else that's simmered or boiled,
///   uncovered, *including rice itself* — some water boils off.
///
/// The same two methods cover the catalog broadly (rice-based and other
/// grain dishes, not just dal), per the household's own answer.
enum CookingMethod { pressureCooker, openPot }

/// Raw dry ingredient → cooked weight, by [CookingMethod]. Both are
/// commonly-cited household ratios (dal roughly 2.5x, rice roughly 3x
/// when boiled — reduced slightly here for typical open-pot evaporation),
/// not a measurement of any specific Nourishly dish. Correct a dish's own
/// factor once it's actually weighed (§0.3).
const Map<CookingMethod, double> cookingYieldFactor = {
  CookingMethod.pressureCooker: 2.5,
  CookingMethod.openPot: 2.75,
};

final _dalIngredientPattern = RegExp(
  r'\b(dal|daal|lentil|rajma|chana|matki|moong|masoor|urad|toor|chawli|lobia)\b',
  caseSensitive: false,
);

/// Infers cooking method from a recipe's own ingredients: pressure-cooker
/// if any ingredient is a dal/pulse (this household always pressure-cooks
/// dal), open pot otherwise — rice and everything else, simmered
/// uncovered.
CookingMethod inferCookingMethod(Recipe recipe) {
  final hasDalIngredient = recipe.ingredients.any(
    (i) => _dalIngredientPattern.hasMatch(i.name),
  );
  return hasDalIngredient
      ? CookingMethod.pressureCooker
      : CookingMethod.openPot;
}

/// Grams a household "tumbler" holds of a dry grain or dal — the S.
/// Indian raw-measure tumbler used in recipes like idli batter, distinct
/// from the 100 ml coffee-serving tumbler in catalog spec §0.3. Varies
/// ~160-180 g by grain; 170 g (the midpoint) is used as the single
/// starting estimate until a specific dish is weighed.
const double tumblerGrams = 170;

/// Converts one [RecipeIngredient]'s quantity to grams. Volumes assume
/// water-like density (1 g/ml) unless [densityGPerMl] is given — good
/// enough for the aqueous ingredients (water, milk, curd) recipes
/// actually measure by volume; oils and other dense ingredients in this
/// catalog are already given in grams, not ml/tsp/tbsp.
double gramsForIngredient(RecipeIngredient ingredient, {double densityGPerMl = 1}) {
  final amount = ingredient.amount;
  switch (ingredient.unit.toLowerCase()) {
    case 'g':
      return amount;
    case 'kg':
      return amount * 1000;
    case 'ml':
      return amount * densityGPerMl;
    case 'l':
      return amount * 1000 * densityGPerMl;
    case 'tsp':
      return amount * 5 * densityGPerMl;
    case 'tbsp':
      return amount * 15 * densityGPerMl;
    case 'tumbler':
      return amount * tumblerGrams;
    default:
      throw ArgumentError('Unknown recipe ingredient unit: ${ingredient.unit}');
  }
}

/// One recipe ingredient resolved against FDC: its quantity plus its
/// source food's nutrients per 100g (raw, before cooking — nutrient mass
/// doesn't change on cooking; only the water content, which the yield
/// factor accounts for, does).
@immutable
class ResolvedIngredient {
  const ResolvedIngredient(this.ingredient, this.nutrientsPer100g);

  final RecipeIngredient ingredient;
  final Map<String, double> nutrientsPer100g;
}

@immutable
class RecipeYieldResult {
  const RecipeYieldResult({
    required this.nutrientsPer100g,
    required this.method,
    required this.yieldFactor,
    required this.rawIngredientGrams,
    required this.cookedGrams,
  });

  /// Per 100g of the finished, cooked dish — ready to store as
  /// `FoodNutrientValues.amountPer100g` (catalog_tables.dart).
  final Map<String, double> nutrientsPer100g;
  final CookingMethod method;
  final double yieldFactor;
  final double rawIngredientGrams;
  final double cookedGrams;
}

/// Sums resolved ingredient nutrients and applies the cooking yield
/// factor to turn "nutrients in the raw ingredients" into "nutrients per
/// 100g of the cooked dish" (catalog spec §0.2). Pass [method] to
/// override the inferred cooking method (e.g. a dish that's dal-based but
/// finished in an open pan).
RecipeYieldResult resolveRecipeYield(
  List<ResolvedIngredient> resolvedIngredients, {
  CookingMethod? method,
}) {
  final recipe = Recipe(
    [for (final r in resolvedIngredients) r.ingredient],
    const [],
  );
  final cookingMethod = method ?? inferCookingMethod(recipe);
  final yieldFactor = cookingYieldFactor[cookingMethod]!;

  var rawGrams = 0.0;
  final totals = <String, double>{};
  for (final resolved in resolvedIngredients) {
    final grams = gramsForIngredient(resolved.ingredient);
    rawGrams += grams;
    resolved.nutrientsPer100g.forEach((nutrientId, per100g) {
      totals[nutrientId] = (totals[nutrientId] ?? 0) + per100g * grams / 100;
    });
  }

  final cookedGrams = rawGrams * yieldFactor;
  final per100g = <String, double>{
    for (final entry in totals.entries)
      entry.key: cookedGrams == 0 ? 0.0 : entry.value / cookedGrams * 100,
  };

  return RecipeYieldResult(
    nutrientsPer100g: per100g,
    method: cookingMethod,
    yieldFactor: yieldFactor,
    rawIngredientGrams: rawGrams,
    cookedGrams: cookedGrams,
  );
}
