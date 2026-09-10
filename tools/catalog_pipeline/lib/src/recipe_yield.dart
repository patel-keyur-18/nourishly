import 'package:meta/meta.dart';

import 'composition.dart';

/// How a dish is cooked — carried through as provenance on the resolved
/// entry, and the source of a *fallback* yield factor for a caller that
/// has no serving weight to work from. See [resolveRecipeYield] for why a
/// serving weight beats it whenever one exists.
///
/// Decided 2026-09-10 from a household kitchen-scale check rather than a
/// per-dish measurement (§0.3 — these are starting estimates, not
/// measurements, same as every serving weight in the catalog):
/// - **Pressure cooker** — dal and other pulses. Sealed, so evaporation
///   is negligible; almost all the water that goes in stays in.
/// - **Open pot** — rice and everything else that's simmered or boiled,
///   uncovered, *including rice itself* — some water boils off.
/// - **None** — assemblies. Already-finished components put together,
///   taking on no water, so the served weight *is* the ingredient weight.
enum CookingMethod { pressureCooker, openPot, none }

/// Raw dry ingredient → cooked weight, by [CookingMethod]. Commonly-cited
/// household ratios (dal roughly 2.5x, rice roughly 3x when boiled —
/// reduced slightly here for typical open-pot evaporation), not a
/// measurement of any specific Nourishly dish.
///
/// These are the fallback, not the primary source: measured against the
/// committed catalog they are right for about an eighth of it. See
/// [resolveRecipeYield].
const Map<CookingMethod, double> cookingYieldFactor = {
  CookingMethod.pressureCooker: 2.5,
  CookingMethod.openPot: 2.75,
  CookingMethod.none: 1.0,
};

/// The band of yield factors a real dish can land in, used to sanity-check
/// a factor derived from a catalog row's own two weight columns.
///
/// The committed catalog spans 0.81x (khakhra and other dishes that dry
/// out) to 12.5x (pepper rasam — 12 g of solids in a 150 g katori, the
/// rest water the composition deliberately does not list because water has
/// no nutrients). The band is wider than that on both sides: it is here to
/// catch a typo in a weight column, not to second-guess curation.
const double minPlausibleYield = 0.5;
const double maxPlausibleYield = 15.0;

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
double gramsForIngredient(
  RecipeIngredient ingredient, {
  double densityGPerMl = 1,
}) {
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

/// Where a [RecipeYieldResult]'s yield factor came from.
enum YieldBasis {
  /// The catalog row's own serving weight divided by the weight of the
  /// ingredients that make one serving. Preferred: it is measured (or at
  /// least estimated) for this specific dish.
  servingWeight,

  /// [cookingYieldFactor] for the dish's [CookingMethod] — used when no
  /// serving weight was supplied, or the one supplied implied a factor
  /// outside [minPlausibleYield]..[maxPlausibleYield].
  cookingMethod,
}

@immutable
class RecipeYieldResult {
  const RecipeYieldResult({
    required this.nutrientsPer100g,
    required this.method,
    required this.basis,
    required this.yieldFactor,
    required this.rawIngredientGrams,
    required this.cookedGrams,
  });

  /// Per 100g of the finished, cooked dish — ready to store as
  /// `FoodNutrientValues.amountPer100g` (catalog_tables.dart).
  final Map<String, double> nutrientsPer100g;
  final CookingMethod method;
  final YieldBasis basis;
  final double yieldFactor;
  final double rawIngredientGrams;
  final double cookedGrams;
}

/// Sums resolved ingredient nutrients and turns "nutrients in the
/// ingredients" into "nutrients per 100g of the finished dish" (catalog
/// spec §0.2).
///
/// [servingGrams] is the dish's own served weight — the catalog's `g`
/// column. When it is given, the yield factor is simply
/// `servingGrams / ingredient grams`, because catalog spec §0.4 defines
/// the two columns that produce it as "estimated grams for that serving"
/// and "ingredient breakdown **per serving**". The ratio of those is what
/// the pot actually did, whether that is water absorbed (pepper rasam,
/// 12 g of solids in a 150 g katori), water driven off (khakhra, 0.81x),
/// or nothing at all (bhel, 1.00x — components tossed together cold).
///
/// This matters more than it sounds: measured against the committed
/// catalog, 143 of 249 recipes land between 0.8x and 1.2x, so the
/// [CookingMethod] constants — the only thing this used to consult — were
/// deflating most of the catalog's per-100g values by roughly 2.75x.
///
/// Without [servingGrams], or when it implies something outside
/// [minPlausibleYield]..[maxPlausibleYield] (a typo in a weight column),
/// it falls back to [cookingYieldFactor] and says so via
/// [RecipeYieldResult.basis]. Pass [method] to override the inferred
/// cooking method for that fallback.
RecipeYieldResult resolveRecipeYield(
  List<ResolvedIngredient> resolvedIngredients, {
  CookingMethod? method,
  double? servingGrams,
}) {
  final recipe = Recipe([
    for (final r in resolvedIngredients) r.ingredient,
  ], const []);
  final cookingMethod = method ?? inferCookingMethod(recipe);

  var rawGrams = 0.0;
  final totals = <String, double>{};
  for (final resolved in resolvedIngredients) {
    final grams = gramsForIngredient(resolved.ingredient);
    rawGrams += grams;
    resolved.nutrientsPer100g.forEach((nutrientId, per100g) {
      totals[nutrientId] = (totals[nutrientId] ?? 0) + per100g * grams / 100;
    });
  }

  final stated = servingGrams == null || rawGrams == 0
      ? null
      : servingGrams / rawGrams;
  final usesStated =
      stated != null &&
      stated >= minPlausibleYield &&
      stated <= maxPlausibleYield;

  final yieldFactor = usesStated ? stated : cookingYieldFactor[cookingMethod]!;
  final cookedGrams = rawGrams * yieldFactor;
  final per100g = <String, double>{
    for (final entry in totals.entries)
      entry.key: cookedGrams == 0 ? 0.0 : entry.value / cookedGrams * 100,
  };

  return RecipeYieldResult(
    nutrientsPer100g: per100g,
    method: cookingMethod,
    basis: usesStated ? YieldBasis.servingWeight : YieldBasis.cookingMethod,
    yieldFactor: yieldFactor,
    rawIngredientGrams: rawGrams,
    cookedGrams: cookedGrams,
  );
}
