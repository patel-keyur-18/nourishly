import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

/// `build_seed.dart` is a script, so it is tested the way it is used: run
/// it over a draft in a throwaway working directory and read the seed back.
///
/// The property under test is the one the whole stable-id change exists
/// for — **the same draft must produce the same seed, byte for byte.**
/// Until it did, regenerating the seed rewrote all 2.3 MB with fresh
/// random ids, so a diff could not show what a new row had done, and a
/// second seed shipped to a device that already had one would have
/// imported a duplicate of the whole catalog instead of an update.
void main() {
  late Directory work;
  late String repoRoot;

  setUpAll(() => repoRoot = Directory.current.absolute.path);

  setUp(() {
    work = Directory.systemTemp.createTempSync('build_seed_test');
    Directory('${work.path}/build').createSync(recursive: true);
    Directory('${work.path}/app/assets/catalog').createSync(recursive: true);
  });

  tearDown(() => work.deleteSync(recursive: true));

  /// One direct-USDA ingredient and one recipe that uses it — the two
  /// shapes `build_seed` handles, and the component link between them.
  Map<String, dynamic> draft() => {
    'resolved': [
      {
        'kind': 'ingredient',
        'key': '01:toor-dal-raw',
        'sourceFile': '01-common.md',
        'foodName': 'Toor dal, raw',
        'isTier1': true,
        'alsoNames': ['arhar', 'tuvar'],
        'servingLabel': '100 g',
        'servingAmount': 100,
        'fdcId': 172421,
        'fdcDescription': 'Pigeon peas, mature seeds, raw',
        'fdcDataType': 'SR Legacy',
        'nutrientsPer100g': {'energy': 343.0, 'protein': 21.7},
        'unmatchedFdcNutrients': <String>[],
      },
      {
        'kind': 'recipe',
        'key': '02:gujarati-dal',
        'sourceFile': '02-gujarat.md',
        'foodName': 'Gujarati dal',
        'isTier1': true,
        'alsoNames': ['tuvar dal'],
        'servingLabel': '1 katori',
        'servingAmount': 150,
        'cookingMethod': 'pressureCooker',
        'yieldBasis': 'cookedWeight',
        'yieldFactor': 2.381,
        'rawIngredientGrams': 63.0,
        'nutrientsPer100g': {'energy': 92.4, 'protein': 4.1},
        'ingredients': [
          {
            'name': 'toor dal',
            'amount': 28,
            'unit': 'g',
            'quantityGrams': 28.0,
            'source': 'fdc',
            'catalogRow': null,
            'catalogRowName': null,
            'fdcId': 172421,
            'fdcDescription': 'Pigeon peas, mature seeds, raw',
            'fdcDataType': 'SR Legacy',
            'nutrientsPer100g': {'energy': 343.0, 'protein': 21.7},
          },
        ],
      },
    ],
    'failures': <String>[],
  };

  Future<Map<String, dynamic>> runBuildSeed() async {
    File('${work.path}/build/catalog_seed_draft.json')
        .writeAsStringSync(jsonEncode(draft()));
    final result = await Process.run(Platform.resolvedExecutable, [
      'run',
      '$repoRoot/bin/build_seed.dart',
    ], workingDirectory: work.path);
    expect(
      result.exitCode,
      0,
      reason: 'build_seed failed:\n${result.stdout}\n${result.stderr}',
    );
    return jsonDecode(
      File('${work.path}/app/assets/catalog/seed_v1.json').readAsStringSync(),
    ) as Map<String, dynamic>;
  }

  test('the same draft produces the same seed, byte for byte', () async {
    final first = await runBuildSeed();
    final second = await runBuildSeed();
    expect(jsonEncode(second), jsonEncode(first));
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('ids are derived from the row key, so they survive a rebuild', () async {
    final seed = await runBuildSeed();
    final foods = (seed['foodItems'] as List).cast<Map<String, dynamic>>();

    final dal = foods.firstWhere((f) => f['canonicalName'] == 'Gujarati dal');
    final toor = foods.firstWhere((f) => f['canonicalName'] == 'Toor dal, raw');

    // Every id is a v5 (version nibble 5), not a v7.
    for (final food in foods) {
      expect(
        (food['id'] as String).split('-')[2][0],
        '5',
        reason: '${food['canonicalName']} should carry a derived id',
      );
    }
    expect(dal['id'], isNot(toor['id']));

    // Child rows hang off their parent, so a re-import updates them in
    // place rather than adding a second serving size or alt name.
    final servings = (seed['servingSizes'] as List)
        .cast<Map<String, dynamic>>();
    expect(servings.where((s) => s['foodId'] == dal['id']), hasLength(1));

    final altNames = (seed['foodAltNames'] as List)
        .cast<Map<String, dynamic>>();
    expect(
      altNames.where((a) => a['foodId'] == toor['id']).map((a) => a['name']),
      unorderedEquals(['arhar', 'tuvar']),
    );
  }, timeout: const Timeout(Duration(minutes: 2)));

  test(
    'a recipe component points at the ingredient it shares an FDC id with',
    () async {
      final seed = await runBuildSeed();
      final foods = (seed['foodItems'] as List).cast<Map<String, dynamic>>();
      final dal = foods.firstWhere((f) => f['canonicalName'] == 'Gujarati dal');
      final toor = foods.firstWhere(
        (f) => f['canonicalName'] == 'Toor dal, raw',
      );

      final components = (seed['recipeComponents'] as List)
          .cast<Map<String, dynamic>>();
      final component = components.singleWhere(
        (c) => c['recipeFoodItemId'] == dal['id'],
      );
      // The catalog entry and the recipe's ingredient are the same FDC food,
      // so they must be one row, not two.
      expect(component['ingredientFoodItemId'], toor['id']);
      expect(component['quantityGrams'], 28.0);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'a draft from an older fetch is refused, not silently rebuilt',
    () async {
      final stale = draft();
      for (final food
          in (stale['resolved'] as List).cast<Map<String, dynamic>>()) {
        food.remove('key');
      }
      File('${work.path}/build/catalog_seed_draft.json')
          .writeAsStringSync(jsonEncode(stale));
      final result = await Process.run(Platform.resolvedExecutable, [
        'run',
        '$repoRoot/bin/build_seed.dart',
      ], workingDirectory: work.path);
      expect(result.exitCode, isNot(0));
      expect(result.stderr.toString(), contains('rerun it'));
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
