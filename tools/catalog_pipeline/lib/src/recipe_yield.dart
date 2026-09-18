import 'package:meta/meta.dart';
import 'package:nutrition_core/nutrition_core.dart';

import 'catalog_source_entry.dart';
import 'composition.dart';

/// §19.10's recipe arithmetic — the cooking-yield constants, the
/// plausible band, and the sum-and-divide itself — lives in
/// `nutrition_core` so the pipeline and the in-app recipe builder cannot
/// drift apart (AP-5). This file keeps what is specific to the catalog:
/// parsing an ingredient's quantity into grams, and inferring how a dish
/// was cooked from what is in it.
export 'package:nutrition_core/nutrition_core.dart'
    show CookingMethod, YieldBasis, maxPlausibleYield, minPlausibleYield;

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

/// Serving labels that count whole items, for [pieceGramsFor].
///
/// An allow-list rather than a deny-list, because the failure it guards
/// against is silent: read "1 katori" as a count and an ingredient stated
/// as two pieces becomes 300 g of sambar. A label this does not recognize
/// yields no piece weight at all, and the caller says so out loud.
final _countedServing = RegExp(
  r'^(\d+(?:\.\d+)?)\s+(pieces?|pcs?|nos?|large|medium|small|slices?|balls?)\b',
  caseSensitive: false,
);

/// What one piece of [entry] weighs, read off its own serving columns, or
/// null when they do not count pieces.
///
/// Nothing is invented here: `Egg, boiled | 1 large | 50 g` already says
/// that a piece of egg is 50 g, and that is the only place an ingredient
/// stated as "Egg 2 pieces" can honestly get its weight from.
double? pieceGramsFor(CatalogSourceEntry entry) {
  final match = _countedServing.firstMatch(entry.servingLabel.trim());
  if (match == null) return null;
  final count = double.parse(match.group(1)!);
  if (count <= 0) return null;
  return entry.servingAmount / count;
}

/// Converts one [RecipeIngredient]'s quantity to grams. Volumes assume
/// water-like density (1 g/ml) unless [densityGPerMl] is given — good
/// enough for the aqueous ingredients (water, milk, curd) recipes
/// actually measure by volume; oils and other dense ingredients in this
/// catalog are already given in grams, not ml/tsp/tbsp.
///
/// [pieceGrams] is what one piece of *this* ingredient weighs, for the
/// few recipes that count rather than weigh ("Egg 2 pieces"). It has no
/// default: a piece is not a unit of mass, and guessing one would put an
/// invented number into a dish.
double gramsForIngredient(
  RecipeIngredient ingredient, {
  double densityGPerMl = 1,
  double? pieceGrams,
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
    case 'piece':
    case 'pieces':
      if (pieceGrams == null) {
        throw ArgumentError(
          '"${ingredient.name}" is stated as $amount piece(s), but the row it '
          'resolves to does not say what one piece weighs. Give that row a '
          'counted serving ("1 large", "2 pieces"), or state this ingredient '
          'in grams.',
        );
      }
      return amount * pieceGrams;
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
  const ResolvedIngredient(
    this.ingredient,
    this.nutrientsPer100g, {
    this.pieceGrams,
  });

  final RecipeIngredient ingredient;
  final Map<String, double> nutrientsPer100g;

  /// What one piece of the catalog row this resolved to weighs, from
  /// [pieceGramsFor]. Only consulted when the ingredient is stated as a
  /// count.
  final double? pieceGrams;
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
/// The arithmetic is [computeRecipeNutrition]; what this adds is the
/// catalog's own inputs — each ingredient's quantity converted to grams by
/// [gramsForIngredient], and the cooking method inferred from the
/// ingredient list when the caller does not state one.
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
RecipeYieldResult resolveRecipeYield(
  List<ResolvedIngredient> resolvedIngredients, {
  CookingMethod? method,
  double? servingGrams,
}) {
  final recipe = Recipe([
    for (final r in resolvedIngredients) r.ingredient,
  ], const []);
  final cookingMethod = method ?? inferCookingMethod(recipe);

  final nutrition = computeRecipeNutrition(
    components: [
      for (final resolved in resolvedIngredients)
        RecipeComponentInput(
          foodId: resolved.ingredient.name,
          grams: gramsForIngredient(
            resolved.ingredient,
            pieceGrams: resolved.pieceGrams,
          ),
          nutrientsPer100g: resolved.nutrientsPer100g,
        ),
    ],
    cookedGrams: servingGrams,
    method: cookingMethod,
  );

  return RecipeYieldResult(
    nutrientsPer100g: nutrition.per100g,
    method: cookingMethod,
    basis: nutrition.basis,
    yieldFactor: nutrition.yieldFactor,
    rawIngredientGrams: nutrition.rawGrams,
    cookedGrams: nutrition.cookedGrams,
  );
}
