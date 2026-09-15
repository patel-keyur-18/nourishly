// Deciding whether an FDC search result is actually the food that was
// asked for.
//
// Catalog spec §0.3b deleted the blind FDC search for recipe
// *ingredients*, because "batter" matched battered fish and "milk"
// matched milk crackers. The same blind trust survived one level up, on
// a row's own `USDA` lookup: the pipeline took `candidates.first` and
// asked no questions. Measured against the shipped catalog that put 33
// ingredient rows on the wrong food — salt on `Butter, salted`, potato on
// `Bread, potato`, rice on `Potatoes, au gratin`, garam masala on a
// branded soup — and because every one of them *matched something*, no
// failure was ever reported. They shipped wearing a `verified` badge.
//
// Nothing here guesses a better answer. It only refuses a bad one, so the
// search moves on to the next query or the next data type, and a row that
// finds nothing acceptable is reported as a curation gap rather than
// quietly sourced from a pastry.
library;

import 'fdc_models.dart';

/// Words that carry no identifying force in either a catalog row name or
/// an FDC description: preparation states, packaging, and filler.
const _noise = {
  'raw', 'cooked', 'boiled', 'fresh', 'dry', 'dried', 'powder', 'powdered',
  'ground', 'whole', 'plain', 'total', 'and', 'or', 'the', 'with', 'without',
  'in', 'of', 'a', 'an', 'nfs', 'usda', 'for', 'use', 'recipe', 'commercially',
  'prepared', 'canned', 'frozen', 'regular', 'unenriched', 'enriched',
  'added', 'mature', 'seeds', 'salad', 'cooking', 'type', 'home', 'style',
  'all', 'not', 'from', 'made',
  // Colours identify almost nothing on their own — `Asparagus, green` is
  // not a green chilli — and every one of them appears across dozens of
  // unrelated FDC records.
  'green', 'red', 'white', 'black', 'yellow', 'brown', 'light',
};

/// Meaningful lowercase words in [text], preparation noise removed.
Set<String> matchTokens(String text) => {
  for (final word in text.toLowerCase().split(RegExp(r'[^a-z]+')))
    if (word.length > 2 && !_noise.contains(word)) word,
};

/// Whether two words name the same thing, allowing only for a plural.
///
/// Plural-only on purpose. A looser suffix rule — anything within a
/// couple of letters — matches `salt` to `salted`, and `Butter, salted`
/// is precisely the record that made salt carry 717 kcal and 81 g of fat
/// into 999 recipes.
bool _sameWord(String a, String b) {
  if (a == b) return true;
  final shorter = a.length <= b.length ? a : b;
  final longer = a.length <= b.length ? b : a;
  if (!longer.startsWith(shorter)) return false;
  final suffix = longer.substring(shorter.length);
  return suffix == 's' || suffix == 'es';
}

/// Whether [description] plausibly names the same food as [terms] — the
/// row's name, its `Also` synonyms, and the curator's `USDA` hint.
///
/// The rule is deliberately weak: **one identifying word in common**,
/// plurals allowed, preparation noise ignored. It is a sieve for results
/// that are simply a different food, not a judgement about which of two
/// plausible records is better — `Brinjal` -> `Eggplant` and `Toor dal`
/// -> `Pigeon peas` are correct and share no word at all, which is what
/// the `Also` synonyms and the hint are for.
///
/// It does not catch everything, and is not meant to. `Oil, oat` shares
/// "oat" with rolled oats; `Cheese, mozzarella, whole milk` shares
/// "milk" with whole milk. Both are wrong and both pass. What the sieve
/// guarantees is the other direction: nothing it rejects is ever used,
/// and every rejection is reported rather than swallowed, so a row it
/// wrongly rejects surfaces as a curation gap instead of shipping the
/// wrong food.
bool describesSameFood(String description, Iterable<String> terms) {
  final theirs = matchTokens(description);
  final ours = {for (final t in terms) ...matchTokens(t)};
  return ours.any((o) => theirs.any((t) => _sameWord(o, t)));
}

/// The four proximates every food the catalog sums must carry.
const _proximates = {'energy', 'protein', 'fat', 'carbs'};

/// Whether [food] carries enough to be summed into a recipe.
///
/// Some FDC Foundation records are specialised analyses — a fatty-acid
/// profile, a mineral panel — with 65 to 90 nutrients and no proximates
/// at all. `Oil, peanut` is one, and taking it made the household's
/// default cooking fat contribute zero calories and zero fat to 787
/// recipes without a single reported failure.
bool hasProximates(Map<String, double> nutrientsPer100g) =>
    nutrientsPer100g.keys.toSet().intersection(_proximates).isNotEmpty;

/// Why a candidate was rejected, for the run's report.
class RejectedMatch {
  const RejectedMatch({
    required this.query,
    required this.food,
    required this.reason,
  });

  final String query;
  final FdcFood food;
  final String reason;

  @override
  String toString() =>
      '"$query" -> ${food.description} (${food.fdcId}): $reason';
}
