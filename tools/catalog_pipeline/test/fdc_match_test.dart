import 'package:catalog_pipeline/catalog_pipeline.dart';
import 'package:test/test.dart';

void main() {
  group('describesSameFood rejects the matches that shipped wrong', () {
    // Every case here is a real pairing from the shipped catalog: an FDC
    // search result the pipeline accepted, and the row it was accepted
    // for. Each one put a different food's nutrients under a `verified`
    // badge.
    const wrong = <String, (String, List<String>)>{
      'Butter, salted': ('Salt', ['mithu', 'uppu']),
      'Potatoes, au gratin, home-prepared from recipe using butter': (
        'Rice, white, raw',
        [],
      ),
      'Asparagus, green, raw': ('Green chilli', ['marcha', 'pachai milagai']),
      'Buckwheat, whole grain': (
        'Chana, whole (kabuli)',
        ['chickpea', 'chole'],
      ),
      'Baobab powder': ('Red chilli powder', ['marcha powder', 'milagai podi']),
      'Litchis, dried': ('Coconut, dry', ['copra']),
    };

    wrong.forEach((description, row) {
      final (name, alsoNames) = row;
      test('"$name" is not "$description"', () {
        expect(describesSameFood(description, [name, ...alsoNames]), isFalse);
      });
    });
  });

  group('describesSameFood keeps the matches that are right', () {
    // Regional names share no word with USDA's, which is exactly what the
    // `Also` synonyms and the curator's `USDA` hint carry. Rejecting these
    // would break correct rows.
    const right = <String, (String, List<String>)>{
      'Pigeon peas (red gram), mature seeds, raw': (
        'Toor dal, raw',
        ['arhar', 'tuvar', 'pigeon peas'],
      ),
      'Eggplant, raw': ('Brinjal', ['ringan', 'eggplant raw']),
      'Butter oil, anhydrous': ('Ghee', ['tup', 'butter oil anhydrous']),
      'Taro, raw': ('Colocasia', ['arbi', 'taro']),
      'Lamb, New Zealand, imported, ground lamb, raw': (
        'Mutton, raw',
        ['bakri', 'lamb goat'],
      ),
      'Bulgur, dry': ('Broken wheat', ['dalia', 'bulgur dry']),
      'Beef, grass-fed, ground, raw': ('Beef, raw', ['beef ground raw']),
      'Egg, whole, cooked, hard-boiled': ('Egg, boiled', ['anda', 'muttai']),
    };

    right.forEach((description, row) {
      final (name, terms) = row;
      test('"$name" is "$description"', () {
        expect(describesSameFood(description, [name, ...terms]), isTrue);
      });
    });
  });

  group('what the sieve does not catch', () {
    // Stated as tests because the limit is real and worth knowing. A
    // wrong record that happens to contain the food's name passes: FDC
    // names a bread after the potato in it, and a sweet after the
    // tamarind in it. No bag-of-words rule separates those from the food
    // itself.
    test('a wrong record that contains the food name still passes', () {
      expect(describesSameFood('Bread, potato', ['Potato']), isTrue);
      expect(describesSameFood('Candies, Tamarind', ['Tamarind']), isTrue);
    });

    test('which is what the curator hint is for', () {
      // The sieve is a floor, not the mechanism. `USDA <descriptor>`
      // names the food as FDC names it, so the right record is what the
      // search returns in the first place — and the sieve then confirms
      // rather than rescues.
      expect(
        describesSameFood('Potatoes, flesh and skin, raw', [
          'Potato',
          'potatoes flesh and skin raw',
        ]),
        isTrue,
      );
      expect(
        describesSameFood('Tamarinds, raw', ['Tamarind', 'tamarinds raw']),
        isTrue,
      );
    });
  });

  group('word matching', () {
    test('a plural is the same word', () {
      expect(describesSameFood('Grapes, raw', ['Grape']), isTrue);
      expect(describesSameFood('Tamarinds, raw', ['Tamarind']), isTrue);
    });

    test('but a different word that merely starts the same is not', () {
      // The rule that let `Butter, salted` answer a search for salt.
      expect(describesSameFood('Butter, salted', ['Salt']), isFalse);
      expect(describesSameFood('Oatmeal cookies', ['Oat']), isFalse);
    });

    test('preparation words alone are not a match', () {
      expect(describesSameFood('Beans, snap, green, raw', ['Raw']), isFalse);
      expect(
        describesSameFood('Potatoes, au gratin, from recipe', [
          'for recipe use',
        ]),
        isFalse,
      );
    });

    test('a colour alone is not a match', () {
      // `Asparagus, green, raw` answered a search for green chilli.
      expect(
        describesSameFood('Asparagus, green, raw', ['Green chilli']),
        isFalse,
      );
    });
  });

  group('hasProximates', () {
    test('a food with macros is usable', () {
      expect(hasProximates(const {'energy': 350, 'protein': 23}), isTrue);
    });

    test('a specialised analysis with no proximates is not', () {
      // `Oil, peanut` (fdcId 1750348): 90 nutrients, a fatty-acid profile
      // and vitamin E, and nothing a recipe can be summed from. Taking it
      // made the default cooking fat contribute zero to 787 recipes.
      expect(
        hasProximates(const {'saturated_fat': 16.2, 'vitamin_e': 15.23}),
        isFalse,
      );
    });

    test('an empty panel is not', () {
      expect(hasProximates(const {}), isFalse);
    });
  });
}
