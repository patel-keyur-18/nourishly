import 'dart:io';

import 'package:catalog_pipeline/catalog_pipeline.dart';
import 'package:test/test.dart';

CatalogRow _row(
  String name,
  String composition, {
  List<String> also = const [],
}) => CatalogRow(
  CatalogSourceEntry(
    sourceFile: 'test.md',
    section: 'Test',
    isTier1: false,
    foodName: name,
    alsoNames: also,
    servingLabel: '1 katori',
    servingAmount: 100,
    weightColumnLabel: 'g',
    rawComposition: composition,
  ),
  CompositionParser().parse(composition),
);

void main() {
  group('CatalogIndex', () {
    test('matches a row by its own name', () {
      final index = CatalogIndex([_row('Patra', 'Besan 25 g, oil 10 g')]);

      expect(index.lookup('patra')?.entry.foodName, 'Patra');
      expect(index.lookup('  PATRA ')?.entry.foodName, 'Patra');
    });

    test('matches a row by an Also synonym', () {
      final index = CatalogIndex([
        _row('Bottle gourd', 'USDA calabash', also: ['dudhi', 'lauki']),
      ]);

      expect(index.lookup('dudhi')?.entry.foodName, 'Bottle gourd');
    });

    test('matches a row by the segment before a comma or slash', () {
      final index = CatalogIndex([
        _row('Sev, thin', 'Besan 13 g, absorbed oil 6 g'),
        _row('Khoya / Mawa', 'USDA condensed milk solids basis'),
      ]);

      expect(index.lookup('sev')?.entry.foodName, 'Sev, thin');
      expect(index.lookup('khoya')?.entry.foodName, 'Khoya / Mawa');
    });

    test("a row's own name beats another row's synonym", () {
      final index = CatalogIndex([
        _row('Rava kesari', 'Rava 35 g, ghee 18 g', also: ['kesari bath']),
        _row('Kesari bath', 'Rava 35 g, ghee 18 g, sugar 30 g'),
      ]);

      expect(index.lookup('kesari bath')?.entry.foodName, 'Kesari bath');
    });

    test("a synonym beats another row's leading segment", () {
      final index = CatalogIndex([
        _row('Vermicelli, raw', 'USDA', also: ['semiya']),
        _row('Vermicelli bath', 'Vermicelli 45 g, oil 8 g'),
      ]);

      expect(index.lookup('semiya')?.entry.foodName, 'Vermicelli, raw');
      expect(index.lookup('vermicelli')?.entry.foodName, 'Vermicelli, raw');
    });

    test('drops a leading segment several rows claim rather than guessing', () {
      final index = CatalogIndex([
        _row('Palya, beans', 'French beans 95 g, oil 6 g'),
        _row('Palya, cabbage', 'Cabbage 95 g, oil 6 g'),
        _row('Palya, potato', 'Potato 100 g, oil 8 g'),
      ]);

      expect(index.lookup('palya'), isNull);
      expect(index.lookup('palya, potato')?.entry.foodName, 'Palya, potato');
    });

    test('a tie is broken against the row that needs manual review', () {
      final index = CatalogIndex([
        _row('Muthiya, steamed', 'Wheat flour 25 g, besan 10 g, oil 8 g'),
        _row('Muthiya, fried', 'As above + absorbed oil 6 g'),
      ]);

      expect(index.lookup('muthiya')?.entry.foodName, 'Muthiya, steamed');
    });

    test('a row that only needs manual review never claims a name', () {
      final index = CatalogIndex([_row('Sev tameta', 'See §1')]);

      expect(index.lookup('sev tameta'), isNull);
    });
  });

  group('the committed catalog', () {
    const catalogDir = '../../docs/catalog';
    final parser = CatalogSourceParser();
    final compositionParser = CompositionParser();

    final rows = [
      for (final name in [
        '01-common.md',
        '02-gujarat.md',
        '03-tamil-nadu.md',
        '04-karnataka.md',
      ])
        for (final entry in parser.parseFile(File('$catalogDir/$name')))
          CatalogRow(entry, compositionParser.parse(entry.rawComposition)),
    ];
    final index = CatalogIndex(rows);

    // Every ingredient the 2026-09-10 pipeline run failed on. Each is a
    // catalog row under some name, and none of them is anything FDC has
    // heard of — if one stops resolving here, that run's 18 failures are
    // back.
    const previouslyFailing = {
      'sev': 'Sev, thin',
      'dudhi': 'Bottle gourd',
      'patra': 'Patra',
      'Surti papdi': 'Field beans',
      'Muthiya': 'Muthiya, steamed',
      'Ganthiya': 'Gathiya',
      'Matki': 'Matki',
      'khoya': 'Khoya / Mawa',
      'Fafda': 'Fafda',
      'Parotta': 'Parotta',
      'potato palya': 'Palya, potato',
      'kori gassi': 'Kori gassi',
      'decoction': 'Coffee decoction',
    };

    previouslyFailing.forEach((ingredient, expected) {
      test('resolves the ingredient "$ingredient" to "$expected"', () {
        expect(index.lookup(ingredient)?.entry.foodName, expected);
      });
    });
  });
}
