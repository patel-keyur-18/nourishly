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

    test('reads a counted ingredient as a piece quantity', () {
      final result = parser.parse('Egg 2 pieces, onion 25 g, oil 6 g');
      expect(result, isA<Recipe>());
      expect(
        (result as Recipe).ingredients.first,
        const RecipeIngredient('Egg', 2, 'pieces'),
      );
    });

    test('a counted first segment is a recipe, not a reference to another '
        'dish', () {
      expect(parser.parse('Egg 2 pieces, salt 2 g'), isA<Recipe>());
    });

    test(
      'a segment that states both a count and a weight keeps the weight',
      () {
        final recipe =
            parser.parse('Moth beans 70 g, pav 1 piece 60 g') as Recipe;
        expect(
          recipe.ingredients.last,
          const RecipeIngredient('pav 1 piece', 60, 'g'),
        );
      },
    );

    test('recognizes tumbler as a household raw-measure unit', () {
      final result = parser.parse(
        'Rice 3 tumbler, urad dal 1 tumbler, fenugreek',
      );
      final recipe = result as Recipe;
      expect(recipe.ingredients, [
        const RecipeIngredient('Rice', 3, 'tumbler'),
        const RecipeIngredient('urad dal', 1, 'tumbler'),
      ]);
      expect(recipe.unquantifiedNotes, ['fenugreek']);
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

  group('a pinned FDC id', () {
    test('is read off the composition and leaves the descriptor behind', () {
      final result = parser.parse('USDA #170393 carrots raw');
      expect(result, isA<UsdaLookup>());
      final lookup = result as UsdaLookup;
      expect(lookup.fdcId, 170393);
      expect(lookup.hint, 'carrots raw');
    });

    test('a row without one is unpinned, not pinned to zero', () {
      expect((parser.parse('USDA carrots raw') as UsdaLookup).fdcId, isNull);
    });

    test('keeps working with a curator note after the descriptor', () {
      // The note is stripped by the em-dash rule; the pin must survive it.
      final lookup = parser.parse(
        'USDA #173468 salt table — **the sodium source**',
      ) as UsdaLookup;
      expect(lookup.fdcId, 173468);
      expect(lookup.hint, 'salt table');
    });

    test('a bare pin with no descriptor is still a pin', () {
      final lookup = parser.parse('USDA #170393') as UsdaLookup;
      expect(lookup.fdcId, 170393);
      expect(lookup.hint, isEmpty);
    });

    test('a hash that is not a leading id is left alone', () {
      expect((parser.parse('USDA grade #1 syrup') as UsdaLookup).fdcId, isNull);
    });
  });
}
