/// Finding the cooking fat in a recipe, so a household that cooks the same
/// dish in less of it can say so.
///
/// This household cooks most dishes with about half the oil the standard
/// recipe uses. The catalog cannot know that — its rows are a reasonable
/// starting estimate of how a dish is generally made — but a recipe forked
/// into your own can, and the only edit that usually needs making is the
/// fat. This finds the lines worth editing and proposes a number for each.
///
/// **It proposes; it never applies.** Nothing here writes a recipe. The
/// cook sees each suggestion against the original and accepts the ones
/// that match her pan, which is the difference between recording how she
/// cooks and asserting it on her behalf.
library;

import 'dao/recipe_dao.dart';

/// A cooking fat found in a recipe, with what a lighter version might use.
class FatSuggestion {
  const FatSuggestion({
    required this.index,
    required this.name,
    required this.grams,
    required this.suggestedGrams,
  });

  /// Position in the recipe's ingredient list.
  final int index;
  final String name;

  /// What the recipe says now.
  final double grams;

  /// What half as much would be, rounded to the nearest half gram —
  /// nobody measures a cooking fat to two decimals.
  final double suggestedGrams;

  double get gramsSaved => grams - suggestedGrams;
}

/// Names that are a cooking fat: the catalog's five oils, ghee, butter and
/// cream.
///
/// Matched on the leading word rather than a substring of the whole name,
/// so `Groundnut oil` and `Oil, olive` both match while `Oil seeds` would
/// not. Nuts and seeds are deliberately absent — they are fatty, but they
/// are an ingredient of the dish rather than the medium it was cooked in,
/// and halving the peanuts in a Gujarati dal changes what the dish is.
final _fatPattern = RegExp(
  r'\b(oil|ghee|butter|cream|malai|vanaspati|dalda)\b',
  caseSensitive: false,
);

/// The cooking fats in [ingredients], with a halved amount proposed for
/// each.
///
/// ## The absorbed-oil limitation, stated plainly
///
/// Catalog spec §0.6 separates **pan oil** — a choice the cook makes —
/// from **absorbed oil**, what a deep-fried food takes up. A puri fried in
/// half the oil absorbs about the same, so halving absorbed oil would
/// claim a reduction that did not happen.
///
/// That distinction lives in the catalog's `Composition` text, and it does
/// **not** survive into `recipe_components`: `absorbed oil 6 g` and
/// `oil 6 g` both resolve to the Groundnut oil row, and by the time a
/// recipe is stored they are indistinguishable. So this cannot filter
/// absorbed oil out, and it does not pretend to.
///
/// What it does instead is never apply anything by itself. Every
/// suggestion is shown next to the original for the cook to accept or
/// skip, and a fried dish's absorbed oil is a line she leaves alone.
/// Teaching the pipeline to carry the original wording onto each component
/// would let this filter properly; until then, asking is the honest
/// substitute for knowing.
List<FatSuggestion> fatSuggestions(
  List<RecipeIngredient> ingredients, {
  double factor = 0.5,
}) {
  final suggestions = <FatSuggestion>[];
  for (var i = 0; i < ingredients.length; i++) {
    final ingredient = ingredients[i];
    if (!_fatPattern.hasMatch(ingredient.name)) continue;
    final suggested = _roundToHalfGram(ingredient.grams * factor);
    // A fat already so small that halving it rounds to no change is not
    // worth putting in front of anyone.
    if (suggested >= ingredient.grams) continue;
    suggestions.add(
      FatSuggestion(
        index: i,
        name: ingredient.name,
        grams: ingredient.grams,
        suggestedGrams: suggested,
      ),
    );
  }
  return suggestions;
}

double _roundToHalfGram(double grams) => (grams * 2).round() / 2;
