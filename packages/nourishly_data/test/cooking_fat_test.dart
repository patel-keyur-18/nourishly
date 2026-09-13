import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly_data/nourishly_data.dart';

RecipeIngredient _i(String name, double grams) =>
    RecipeIngredient(foodId: 'id-$name', name: name, grams: grams);

void main() {
  test('finds the catalog\'s cooking fats', () {
    final found = fatSuggestions([
      _i('Groundnut oil', 8),
      _i('Ghee', 12),
      _i('Butter', 20),
      _i('Sesame oil', 6),
      _i('Mustard oil', 10),
      _i('Malai / fresh cream', 15),
    ]).map((s) => s.name);
    expect(found, hasLength(6));
  });

  test('leaves the food alone — only the medium it was cooked in', () {
    // Peanuts and coconut are fatty, but they are the dish, not the pan.
    // Halving the peanuts in a Gujarati dal changes what it is.
    final suggestions = fatSuggestions([
      _i('Toor dal, raw', 28),
      _i('Peanuts, raw', 6),
      _i('Coconut, fresh grated', 10),
      _i('Sunflower seeds', 10),
      _i('Groundnut oil', 5),
    ]);
    expect(suggestions.map((s) => s.name), ['Groundnut oil']);
  });

  test('matches on a word, not a substring', () {
    // "Oil seeds" would be a food, not a fat.
    expect(fatSuggestions([_i('Oilseed mix', 20)]), isEmpty);
    expect(fatSuggestions([_i('Oil, olive', 10)]), hasLength(1));
  });

  test('halves, rounded to the half gram nobody measures past', () {
    final suggestion = fatSuggestions([_i('Groundnut oil', 9)]).single;
    expect(suggestion.grams, 9);
    expect(suggestion.suggestedGrams, 4.5);
    expect(suggestion.gramsSaved, 4.5);
    expect(suggestion.index, 0);
  });

  test('a different factor is honoured', () {
    expect(
      fatSuggestions([_i('Ghee', 10)], factor: 0.8).single.suggestedGrams,
      8,
    );
  });

  test('a fat too small to reduce is not put in front of anyone', () {
    // A 0.5 g tempering halves to 0.5 g after rounding: no change to offer.
    expect(fatSuggestions([_i('Groundnut oil', 0.5)]), isEmpty);
  });

  test('the index points back into the original list', () {
    final suggestions = fatSuggestions([
      _i('Rice, white, raw', 60),
      _i('Groundnut oil', 12),
      _i('Onion', 25),
      _i('Ghee', 6),
    ]);
    expect(suggestions.map((s) => s.index), [1, 3]);
  });

  test('absorbed oil is indistinguishable, and is not filtered', () {
    // Stated as a test because it is a real limitation, not an oversight:
    // "absorbed oil 6 g" and "oil 6 g" both resolve to the Groundnut oil
    // row, so by the time a recipe is stored the two are the same
    // ingredient. Both are offered; the cook skips the fried one. If this
    // ever starts filtering, it will be because components learned to
    // carry their original wording.
    final suggestions = fatSuggestions([
      _i('Groundnut oil', 6),
      _i('Groundnut oil', 8),
    ]);
    expect(suggestions, hasLength(2));
  });
}
