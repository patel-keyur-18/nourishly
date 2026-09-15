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

    test('a name that is only a category and a colour still matches', () {
      // `Bread, white` is a form word and a colour and nothing else. It
      // has to be matched on them, which works because a row's own words
      // are authoritative about what it means.
      expect(describesSameFood('Bread, white wheat', ['Bread, white']), isTrue);
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

  group('differentForm flags a record that is another form of the food', () {
    // Every pairing here shipped. None is caught by describesSameFood,
    // because each really does name the food — as an oil, as leaves, as
    // a salted or cooked version.
    test('an oil pressed from the food', () {
      expect(differentForm('Fish oil, sardine', ['Fish, sardine']), {'oil'});
    });

    test('the leaves of its plant', () {
      expect(differentForm('Drumstick leaves, raw', ['Drumstick']), {'leaves'});
      expect(differentForm('Sweet potato leaves, raw', ['Sweet potato']), {
        'leaves',
      });
    });

    test('a salted, breaded or cooked version', () {
      expect(
        differentForm('Fish, mackerel, salted', ['Fish, seer / kingfish']),
        {'salted'},
      );
      expect(
        differentForm('Fish, fish sticks, frozen, prepared', ['Fish, pomfret']),
        {'sticks', 'frozen'},
      );
      expect(
        differentForm('Chicken, broiler, rotisserie, BBQ', [
          'Chicken, curry cut, raw',
        ]),
        {'rotisserie'},
      );
    });

    test('a processed convenience form', () {
      // `Sweet Potato puffs, frozen, unprepared` answered a search for
      // raw sweet potato — they share the word "unprepared".
      expect(
        differentForm('Sweet Potato puffs, frozen, unprepared', [
          'Sweet potato',
          'sweet potato raw unprepared',
        ]),
        {'puffs', 'frozen'},
      );
    });

    test('a row that names the form itself is not flagged', () {
      expect(differentForm('Oil, coconut', ['Coconut oil']), isEmpty);
      expect(
        differentForm('Drumstick leaves, raw', ['Drumstick leaves']),
        isEmpty,
      );
    });

    test('a hint that names the form acknowledges it', () {
      // Ghee really is anhydrous butter oil and breadcrumbs really are
      // dry grated bread. A row that says so in its hint has answered the
      // question, and repeating it every run would bury the one warning
      // that is real.
      expect(
        differentForm('Butter oil, anhydrous', [
          'Ghee',
          'butter oil anhydrous',
        ]),
        isEmpty,
      );
      expect(
        differentForm('Bread, crumbs, dry, grated, plain', [
          'Breadcrumbs',
          'bread crumbs dry grated plain',
        ]),
        isEmpty,
      );
      // But an unacknowledged form still speaks up.
      expect(differentForm('Fish oil, sardine', ['Fish, sardine', '']), {
        'oil',
      });
    });

    test('matches whole words, so unsweetened is not sweetened', () {
      // `parboiled` contains "oil" and `unsweetened` contains "sweetened";
      // substring matching flagged a dozen correct rows.
      expect(
        differentForm('Rice, white, long-grain, parboiled, cooked', [
          'Rice, white, cooked',
        ]),
        isEmpty,
      );
      expect(
        differentForm('Cocoa, dry powder, unsweetened', ['Cocoa powder']),
        isEmpty,
      );
    });
  });
}
