import 'package:meta/meta.dart';

/// A quantified ingredient parsed out of a recipe composition string, e.g.
/// "Toor dal 28 g raw" → `RecipeIngredient('Toor dal', 28, 'g', note: 'raw')`.
@immutable
class RecipeIngredient {
  const RecipeIngredient(this.name, this.amount, this.unit, {this.note});

  final String name;
  final double amount;
  final String unit;

  /// Trailing text after the quantity, e.g. `raw` in "Toor dal 28 g raw".
  final String? note;

  @override
  bool operator ==(Object other) =>
      other is RecipeIngredient &&
      other.name == name &&
      other.amount == amount &&
      other.unit == unit &&
      other.note == note;

  @override
  int get hashCode => Object.hash(name, amount, unit, note);

  @override
  String toString() => '$name $amount$unit${note != null ? ' ($note)' : ''}';
}

/// How a [CatalogSourceEntry.rawComposition] string resolves, per catalog
/// spec §0.2: every dish is a recipe over ingredients or names its USDA
/// sourcing basis directly — there is no third path where a value is
/// invented.
sealed class Composition {
  const Composition();
}

/// `Composition` started with "USDA" — a direct ingredient lookup, not a
/// multi-ingredient recipe. [hint] is the rest of the text, a search hint
/// for [FdcClient] (e.g. "rice white long-grain cooked").
final class UsdaLookup extends Composition {
  const UsdaLookup(this.hint);

  final String hint;

  @override
  String toString() => 'UsdaLookup($hint)';
}

/// A recipe: quantified ingredients plus whatever couldn't be quantified
/// (spices, "no added fat", curry leaves — negligible-mass notes per
/// catalog spec §0.2's worked example).
final class Recipe extends Composition {
  const Recipe(this.ingredients, this.unquantifiedNotes);

  final List<RecipeIngredient> ingredients;
  final List<String> unquantifiedNotes;

  @override
  String toString() =>
      'Recipe(${ingredients.join(', ')}${unquantifiedNotes.isEmpty ? '' : ' + ${unquantifiedNotes.join(', ')}'})';
}

/// The composition text refers to another catalog row instead of stating
/// its own ingredients (e.g. "As above + spices, ajwain", "Bhakhri + spice
/// mix, extra ghee 2 g"). Resolving the reference means matching it
/// against another [CatalogSourceEntry] by name, which this parser
/// deliberately does not attempt — a wrong guess here silently produces
/// the wrong recipe. Left for a human curator, or a later pass with a
/// full entry list to match against.
final class NeedsManualReview extends Composition {
  const NeedsManualReview(this.reason, this.rawText);

  final String reason;
  final String rawText;

  @override
  String toString() => 'NeedsManualReview($reason: "$rawText")';
}

final _usdaPrefix = RegExp(r'^USDA\b', caseSensitive: false);
final _explicitSelfReference = RegExp(
  r'^(As above|Above)\b',
  caseSensitive: false,
);
final _quantity = RegExp(
  r'^(?<name>.*?)\s+(?<amount>\d+(?:\.\d+)?)\s*(?<unit>g|ml|kg|l|tsp|tbsp)\b(?<note>.*)$',
);

/// Classifies and, for recipes, parses a raw `Composition` cell.
class CompositionParser {
  Composition parse(String raw) {
    final text = raw.trim();

    if (_usdaPrefix.hasMatch(text)) {
      return UsdaLookup(text.replaceFirst(_usdaPrefix, '').trim());
    }

    if (_explicitSelfReference.hasMatch(text)) {
      return NeedsManualReview(
        'references another catalog row by name ("as above")',
        text,
      );
    }

    final segments = text
        .split(RegExp(r'[,;+]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (segments.isEmpty) {
      return NeedsManualReview('empty composition', text);
    }

    // Every genuine recipe in the source tables lists its quantified
    // ingredients before any unquantified note ("Toor dal 28 g raw,
    // jaggery 6 g, ..., curry leaves, spices" — never the reverse). A
    // composition whose first segment carries no quantity ("Bhakhri +
    // spice mix, extra ghee 2 g") is a reference to another dish, not an
    // ingredient list — flag it rather than silently dropping "Bhakhri"'s
    // own nutrient contribution into a negligible-mass note alongside
    // curry leaves.
    if (!_quantity.hasMatch(segments.first)) {
      return NeedsManualReview(
        'first segment has no quantity — likely references another dish by name',
        text,
      );
    }

    final ingredients = <RecipeIngredient>[];
    final notes = <String>[];

    for (final segment in segments) {
      final match = _quantity.firstMatch(segment);
      if (match == null) {
        // No quantity in this segment — a negligible-mass note (spices,
        // curry leaves, "no added fat"), per catalog spec §0.2.
        notes.add(segment);
        continue;
      }
      final name = match.namedGroup('name')!.trim();
      final amount = double.parse(match.namedGroup('amount')!);
      final unit = match.namedGroup('unit')!;
      final note = match.namedGroup('note')!.trim();
      ingredients.add(
        RecipeIngredient(name, amount, unit, note: note.isEmpty ? null : note),
      );
    }

    return Recipe(ingredients, notes);
  }
}
