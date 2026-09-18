import 'package:catalog_pipeline/catalog_pipeline.dart';
import 'package:test/test.dart';

void main() {
  final parser = CompositionParser();

  test('a spaced em-dash ends the ingredient list', () {
    // Idli podi: "Urad dal 4 g, chana dal 3 g, chilli, sesame — **usually
    // eaten with 5 g oil or ghee added**". Read as ingredients, the note
    // becomes a 5 g food called "sesame — usually eaten with".
    final composition = parser.parse(
      'Urad dal 4 g, chana dal 3 g, chilli, sesame — '
      '**usually eaten with 5 g oil or ghee added**',
    );
    expect((composition as Recipe).ingredients.map((i) => i.name), [
      'Urad dal',
      'chana dal',
    ]);
    expect(composition.unquantifiedNotes, ['chilli', 'sesame']);
  });

  test('a parenthetical restates a quantity instead of adding to it', () {
    // Idli: 90 g of batter, then the same 90 g broken down. Counted twice,
    // a 90 g serving is built from 151 g of ingredients.
    final composition = parser.parse(
      'Idli batter 90 g (rice 45 g + urad 16 g raw basis), steamed',
    ) as Recipe;
    expect(composition.ingredients, hasLength(1));
    expect(composition.ingredients.single.name, 'Idli batter');
    expect(composition.ingredients.single.amount, 90);
  });

  test('a quantity before the em-dash is still an ingredient', () {
    // Benne dose's butter is the point of the dish, and it sits inside the
    // emphasis that precedes the note.
    final composition = parser.parse(
      'Dosa batter 80 g, **butter 22 g** — the defining ingredient; a '
      'distinct food from plain dosa',
    ) as Recipe;
    expect(composition.ingredients.map((i) => i.name), [
      'Dosa batter',
      'butter',
    ]);
  });
}
