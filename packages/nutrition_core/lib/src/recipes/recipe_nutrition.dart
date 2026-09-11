import 'package:meta/meta.dart';

/// How a dish is cooked, and the fallback yield factor that goes with it.
///
/// Decided 2026-09-10 from a household kitchen-scale check rather than a
/// per-dish measurement (catalog spec §0.3a — starting estimates, not
/// measurements):
/// - **Pressure cooker** — dal and other pulses. Sealed, so evaporation is
///   negligible; almost all the water that goes in stays in.
/// - **Open pot** — rice and everything else simmered or boiled uncovered,
///   including rice itself: some water boils off.
/// - **None** — assemblies. Already-finished components put together,
///   taking on no water, so the served weight *is* the ingredient weight.
enum CookingMethod {
  pressureCooker('pressure_cooker', 'Pressure cooker', 2.5),
  openPot('open_pot', 'Open pot', 2.75),
  none('none', 'No cooking', 1.0);

  const CookingMethod(this.id, this.label, this.yieldFactor);

  final String id;
  final String label;

  /// Raw ingredient weight → cooked weight. Commonly-cited household
  /// ratios (dal roughly 2.5x, rice roughly 3x boiled, reduced a little
  /// for open-pot evaporation), not a measurement of any specific dish.
  ///
  /// A fallback, not the primary source: measured against the committed
  /// catalog these are right for about an eighth of it, which is why
  /// [computeRecipeNutrition] prefers a weighed cooked weight whenever it
  /// has one.
  final double yieldFactor;

  static CookingMethod fromId(String id) =>
      values.firstWhere((m) => m.id == id, orElse: () => none);
}

/// The band a real dish's yield factor can land in, used to sanity-check
/// one derived from a stated cooked weight.
///
/// The committed catalog spans 0.81x (khakhra and other dishes that dry
/// out) to 12.5x (pepper rasam — 12 g of solids in a 150 g katori, the
/// rest water the composition deliberately does not list because water has
/// no nutrients). The band is wider than that on both sides: it is here to
/// catch a mistyped weight, not to second-guess a real dish.
const double minPlausibleYield = 0.5;
const double maxPlausibleYield = 15.0;

/// Where a [RecipeNutrition]'s yield factor came from.
enum YieldBasis {
  /// The dish's own cooked weight divided by the weight of its
  /// ingredients. Preferred: it is measured for this specific dish.
  cookedWeight,

  /// [CookingMethod.yieldFactor] — used when no cooked weight was given,
  /// or the one given implied a factor outside the plausible band.
  cookingMethod,
}

/// One ingredient going into a recipe.
@immutable
class RecipeComponentInput {
  const RecipeComponentInput({
    required this.foodId,
    required this.grams,
    required this.nutrientsPer100g,
  });

  final String foodId;

  /// Raw weight, before cooking.
  final double grams;

  /// Keyed by nutrient id. A nutrient absent from this map is *unknown*
  /// for this ingredient, never zero (AP-4) — which is why
  /// [RecipeNutrition.coverage] exists.
  final Map<String, double> nutrientsPer100g;
}

/// A recipe's nutrition, per 100 g of the finished dish.
@immutable
class RecipeNutrition {
  const RecipeNutrition({
    required this.per100g,
    required this.totals,
    required this.coverage,
    required this.rawGrams,
    required this.cookedGrams,
    required this.yieldFactor,
    required this.basis,
  });

  /// Ready to store as `FoodNutrientValues.amountPer100g`, which is what
  /// makes a recipe an ordinary food everywhere else in the app (§19.10).
  final Map<String, double> per100g;

  /// The whole dish, before dividing by its cooked weight.
  final Map<String, double> totals;

  /// Per nutrient: the share of the recipe's raw weight that came from
  /// ingredients reporting it, 0..1.
  ///
  /// This is the honest part. If the spices in a rajma masala have no iron
  /// figure, the dish's iron is the iron of 97% of it — worth having, and
  /// worth saying so (§19.11, §20.8). A caller decides what to do with a
  /// low one; this only reports it.
  final Map<String, double> coverage;

  final double rawGrams;
  final double cookedGrams;

  /// Cooked weight ÷ raw weight. Above 1 the dish took water on, below 1
  /// it dried out.
  final double yieldFactor;

  final YieldBasis basis;

  double coverageOf(String nutrientId) => coverage[nutrientId] ?? 0;

  /// Nutrients no ingredient reported are simply absent — never zero.
  bool reports(String nutrientId) => per100g.containsKey(nutrientId);
}

/// §19.10's formula:
///
/// ```
/// Recipe = Σ(ingredient_i × grams_i) → total nutrients
///        ÷ cooked_weight (= raw_weight × yield_factor)
///        → per-100g values → portions
/// ```
///
/// Cooking yield is the detail most implementations get wrong, and it is
/// the one that moves the numbers most: a dal that takes on two and a half
/// times its weight in water has per-100g values two and a half times
/// lower than its ingredients suggest. Nutrient *mass* does not change on
/// cooking — only the water it is diluted into — so the sum is over raw
/// ingredient nutrients and the yield factor does the rest. Nutrient
/// retention factors (vitamin C lost on boiling, say) are explicitly not
/// attempted (§19.10, §9.2).
///
/// [cookedGrams] is the weighed finished dish and wins whenever it is
/// given and plausible; otherwise [method]'s fallback factor applies and
/// [RecipeNutrition.basis] says which was used.
RecipeNutrition computeRecipeNutrition({
  required List<RecipeComponentInput> components,
  double? cookedGrams,
  CookingMethod method = CookingMethod.none,
}) {
  var rawGrams = 0.0;
  final totals = <String, double>{};
  final gramsReporting = <String, double>{};

  for (final component in components) {
    if (component.grams <= 0) continue;
    rawGrams += component.grams;
    component.nutrientsPer100g.forEach((nutrientId, per100g) {
      totals[nutrientId] =
          (totals[nutrientId] ?? 0) + per100g * component.grams / 100;
      gramsReporting[nutrientId] =
          (gramsReporting[nutrientId] ?? 0) + component.grams;
    });
  }

  final stated = cookedGrams == null || rawGrams == 0
      ? null
      : cookedGrams / rawGrams;
  final usesStated =
      stated != null &&
      stated >= minPlausibleYield &&
      stated <= maxPlausibleYield;

  final yieldFactor = usesStated ? stated : method.yieldFactor;
  final finishedGrams = rawGrams * yieldFactor;

  return RecipeNutrition(
    per100g: {
      for (final entry in totals.entries)
        entry.key: finishedGrams == 0 ? 0.0 : entry.value / finishedGrams * 100,
    },
    totals: totals,
    coverage: {
      for (final entry in gramsReporting.entries)
        entry.key: rawGrams == 0 ? 0.0 : entry.value / rawGrams,
    },
    rawGrams: rawGrams,
    cookedGrams: finishedGrams,
    yieldFactor: yieldFactor,
    basis: usesStated ? YieldBasis.cookedWeight : YieldBasis.cookingMethod,
  );
}
