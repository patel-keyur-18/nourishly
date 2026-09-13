import 'dart:convert';
import 'dart:io';

import 'package:catalog_pipeline/catalog_pipeline.dart';
import 'package:test/test.dart';

CatalogSourceEntry _entry({
  required String sourceFile,
  required String foodName,
  List<String> also = const [],
  double serving = 150,
}) => CatalogSourceEntry(
  sourceFile: sourceFile,
  section: 'test',
  isTier1: false,
  foodName: foodName,
  alsoNames: also,
  servingLabel: '1 katori',
  servingAmount: serving,
  weightColumnLabel: 'g',
  rawComposition: 'USDA test',
);

void main() {
  group('row keys', () {
    test('a key is the file number and a slug of the name', () {
      expect(
        catalogRowKey('01-common.md', 'Besan, gram flour'),
        '01:besan-gram-flour',
      );
      expect(
        catalogRowKey('03-tamil-nadu.md', 'Chana, whole (kabuli)'),
        '03:chana-whole-kabuli',
      );
    });

    test('the same dish in two files gets two keys', () {
      // The catalog carries "Coconut rice" three times on purpose (spec
      // §0.6). Names may repeat; keys may not.
      expect(
        catalogRowKey('03-tamil-nadu.md', 'Coconut rice'),
        isNot(catalogRowKey('04-karnataka.md', 'Coconut rice')),
      );
    });

    test('an unnumbered filename still produces a usable prefix', () {
      expect(catalogRowKey('pantry.md', 'Olive oil'), 'pantry:olive-oil');
    });

    test('punctuation and case never leak into a key', () {
      expect(slugify("Ghee / Tup, mother's"), 'ghee-tup-mothers');
    });
  });

  group('the lock', () {
    CatalogRow usda(String file, String name) => CatalogRow(
      _entry(sourceFile: file, foodName: name),
      UsdaLookup('test'),
    );

    CatalogRow recipe(String file, String name, String composition) {
      final entry = CatalogSourceEntry(
        sourceFile: file,
        section: 'test',
        isTier1: false,
        foodName: name,
        alsoNames: const [],
        servingLabel: '1 katori',
        servingAmount: 150,
        weightColumnLabel: 'g',
        rawComposition: composition,
      );
      return CatalogRow(entry, CompositionParser().parse(composition));
    }

    test('records what each recipe ingredient resolves to', () {
      final rows = [
        usda('01-common.md', 'Groundnut oil'),
        recipe('02-gujarat.md', 'Test dal', 'Toor dal 30 g, oil 5 g'),
      ];
      final lock = CatalogLock.fromRows(rows, CatalogIndex(rows));
      final locked = lock.rows['02:test-dal']!;
      expect(locked.kind, 'recipe');
      expect(locked.ingredients['oil'], '01:groundnut-oil');
      expect(locked.rawIngredientGrams, 35);
      // 150 g served from 35 g of ingredients.
      expect(locked.yieldFactor, closeTo(4.286, 0.001));
    });

    test('an unmapped ingredient is recorded, not thrown on', () {
      // --check has to report every gap in one pass; stopping at the first
      // would make adding ten rows a ten-round trip.
      final rows = [recipe('09-new.md', 'Mystery', 'Unobtanium 30 g, oil 5 g')];
      final lock = CatalogLock.fromRows(rows, CatalogIndex(rows));
      expect(lock.rows['09:mystery']!.ingredients['unobtanium'], 'UNMAPPED');
    });

    test('water is recorded as water, not as a gap', () {
      final rows = [
        recipe('09-new.md', 'Thin thing', 'Rice 30 g, water 100 g'),
      ];
      final lock = CatalogLock.fromRows(rows, CatalogIndex(rows));
      expect(lock.rows['09:thin-thing']!.ingredients['water'], 'water');
    });

    test('a new row is not a breaking change', () {
      final before = CatalogLock.fromRows([
        usda('01-common.md', 'Groundnut oil'),
      ], CatalogIndex([usda('01-common.md', 'Groundnut oil')]));
      final rows = [
        usda('01-common.md', 'Groundnut oil'),
        usda('05-new.md', 'Mushroom'),
      ];
      final after = CatalogLock.fromRows(rows, CatalogIndex(rows));
      final changes = after.diff(before);
      expect(changes.map((c) => c.severity), ['added']);
      expect(changes.any((c) => c.isBreaking), isFalse);
    });

    test('a retargeted ingredient is breaking, and names the dish', () {
      // The failure this file exists to catch: an existing dish quietly
      // recomputed from a different food.
      final rows = [
        usda('01-common.md', 'Groundnut oil'),
        recipe('02-gujarat.md', 'Test dal', 'Toor dal 30 g, oil 5 g'),
      ];
      final before = CatalogLock.fromRows(rows, CatalogIndex(rows));
      final toorTarget = before.rows['02:test-dal']!.ingredients['toor dal']!;
      final tampered = CatalogLock.fromJson({
        'rows': {
          ...before.toJson()['rows'] as Map<String, dynamic>,
          '02:test-dal': {
            ...(before.toJson()['rows'] as Map)['02:test-dal']
                as Map<String, dynamic>,
            // Only the fat moves; everything else stays put, so the
            // report has to name the one ingredient that changed.
            'ingredients': {'oil': '01:sesame-oil', 'toor dal': toorTarget},
          },
        },
      });
      final changes = before.diff(tampered);
      final retargets = changes
          .where((c) => c.severity == 'retargeted')
          .toList();
      expect(retargets, hasLength(1));
      expect(retargets.single.key, '02:test-dal');
      expect(retargets.single.isBreaking, isTrue);
      expect(retargets.single.message, contains('"oil"'));
      expect(retargets.single.message, contains('01:groundnut-oil'));
    });

    test('a removed row is breaking', () {
      final rows = [usda('01-common.md', 'Groundnut oil')];
      final before = CatalogLock.fromRows(rows, CatalogIndex(rows));
      final after = CatalogLock.fromRows(const [], CatalogIndex(const []));
      final changes = after.diff(before);
      expect(changes.single.severity, 'removed');
      expect(changes.single.isBreaking, isTrue);
    });

    test('a lock round-trips through JSON unchanged', () {
      final rows = [
        usda('01-common.md', 'Groundnut oil'),
        recipe('02-gujarat.md', 'Test dal', 'Toor dal 30 g, oil 5 g'),
      ];
      final lock = CatalogLock.fromRows(rows, CatalogIndex(rows));
      final reread = CatalogLock.fromJson(lock.toJson());
      expect(reread.diff(lock), isEmpty);
    });
  });

  group('the committed lock', () {
    test('matches what the catalog resolves to right now', () {
      // The regression guard itself, run against the real files: if this
      // fails, something changed what an existing dish is made of.
      final parser = CatalogSourceParser();
      final compositionParser = CompositionParser();
      final files =
          Directory('../../docs/catalog')
              .listSync()
              .whereType<File>()
              .where(
                (f) => f.path.endsWith('.md') && !f.path.endsWith('README.md'),
              )
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));
      final rows = [
        for (final file in files)
          for (final entry in parser.parseFile(file))
            CatalogRow(entry, compositionParser.parse(entry.rawComposition)),
      ];

      final current = CatalogLock.fromRows(rows, CatalogIndex(rows));
      final committed = CatalogLock.fromJson(
        (jsonDecodeFile('../../docs/catalog/catalog.lock.json')),
      );
      final breaking = current.diff(committed).where((c) => c.isBreaking);
      expect(
        breaking.map((c) => c.toString()),
        isEmpty,
        reason:
            'Run parse_catalog.dart --check, and --write-lock if the change '
            'is deliberate.',
      );
    });
  });
}

Map<String, dynamic> jsonDecodeFile(String path) => Map<String, dynamic>.from(
  (const JsonCodec().decode(File(path).readAsStringSync()))
      as Map<String, dynamic>,
);
