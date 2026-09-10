import 'package:catalog_pipeline/catalog_pipeline.dart';
import 'package:test/test.dart';

void main() {
  final parser = CompositionParser();

  group('UsdaLookup', () {
    test('a composition starting with USDA is a direct lookup', () {
      final result = parser.parse('USDA rice white long-grain cooked');
      expect(result, isA<UsdaLookup>());
      expect((result as UsdaLookup).hint, 'rice white long-grain cooked');
    });

    test('is case-insensitive on the USDA prefix', () {
      expect(parser.parse('usda plain butter'), isA<UsdaLookup>());
    });
  });

  group('Recipe', () {
    test('parses a simple two-ingredient recipe (Buttermilk)', () {
      final result = parser.parse('Curd 50 g + water 150 ml, salt, cumin');
      expect(result, isA<Recipe>());
      final recipe = result as Recipe;
      expect(recipe.ingredients, [
        const RecipeIngredient('Curd', 50, 'g'),
        const RecipeIngredient('water', 150, 'ml'),
      ]);
      expect(recipe.unquantifiedNotes, ['salt', 'cumin']);
    });

    test('captures a trailing note after the unit (Gujarati dal)', () {
      final result = parser.parse(
        'Toor dal 28 g raw, jaggery 6 g, tamarind 4 g, tomato 15 g, groundnut oil 5 g, peanuts 5 g, curry leaves, spices',
      );
      final recipe = result as Recipe;
      expect(
        recipe.ingredients.first,
        const RecipeIngredient('Toor dal', 28, 'g', note: 'raw'),
      );
      expect(recipe.ingredients.length, 6);
      expect(recipe.unquantifiedNotes, ['curry leaves', 'spices']);
    });

    test('a fully quantified recipe has no unquantified notes', () {
      final result = parser.parse('Rice 45 g, moong dal 20 g, ghee 8 g');
      final recipe = result as Recipe;
      expect(recipe.ingredients.length, 3);
      expect(recipe.unquantifiedNotes, isEmpty);
    });
  });

  group('NeedsManualReview', () {
    test('an explicit "As above" reference is flagged, not guessed at', () {
      final result = parser.parse('As above + spices, ajwain');
      expect(result, isA<NeedsManualReview>());
    });

    test(
      'a composition naming another dish before any quantity is flagged',
      () {
        // Real example from docs/catalog/02-gujarat.md: "Bhakhri, masala"
        final result = parser.parse('Bhakhri + spice mix, extra ghee 2 g');
        expect(result, isA<NeedsManualReview>());
        final review = result as NeedsManualReview;
        expect(review.reason, contains('first segment has no quantity'));
      },
    );
  });
}
