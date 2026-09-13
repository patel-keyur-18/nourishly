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
  group('CatalogIndex.lookup — table-driven, not inferred', () {
    // `lookup` consults `ingredientTargets` and nothing else. That is the
    // whole point: what an ingredient means must not depend on which other
    // rows happen to exist, because that dependence is how four innocuous
    // pantry rows silently retargeted sixty-three references.
    test(
      'a name with no target does not resolve, however obvious it looks',
      () {
        final index = CatalogIndex([_row('Patra', 'Besan 25 g, oil 10 g')]);
        // `patra` *is* in the real target table, but it points at the real
        // catalog row, not at this test's row — so nothing resolves here.
        expect(index.lookup('patra'), isNull);
      },
    );

    test('a target pointing at a row that does not exist resolves to null', () {
      // A dangling target is a curation gap to report, never something to
      // fall back from.
      expect(CatalogIndex(const []).lookup('oil'), isNull);
    });

    test('a row that only needs manual review never answers a lookup', () {
      final index = CatalogIndex([_row('Sev tameta', 'See §1')]);
      expect(index.lookup('sev tameta'), isNull);
    });

    test('rows are addressable by key', () {
      final index = CatalogIndex([_row('Patra', 'Besan 25 g, oil 10 g')]);
      expect(index.row('test:patra')?.entry.foodName, 'Patra');
      expect(index.row('test:nope'), isNull);
      expect(index.rowsByKey.keys, ['test:patra']);
    });
  });

  group('CatalogIndex.suggest — inference, demoted to advice', () {
    test('proposes a row matched by its own name', () {
      final index = CatalogIndex([_row('Patra', 'Besan 25 g, oil 10 g')]);
      final suggestion = index.suggest('  PATRA ')!;
      expect(suggestion.tier, 'name');
      expect(suggestion.isAmbiguous, isFalse);
      expect(suggestion.candidates.single.entry.foodName, 'Patra');
      expect(suggestion.line, contains("'patra': 'test:patra'"));
    });

    test('proposes a row matched by an Also synonym', () {
      final index = CatalogIndex([
        _row('Bottle gourd', 'USDA calabash', also: ['dudhi', 'lauki']),
      ]);
      expect(
        index.suggest('dudhi')!.candidates.single.entry.foodName,
        'Bottle gourd',
      );
      expect(index.suggest('dudhi')!.tier, 'alias');
    });

    test('proposes a row matched by the segment before a comma or slash', () {
      final index = CatalogIndex([
        _row('Sev, thin', 'Besan 13 g, absorbed oil 6 g'),
        _row('Khoya / Mawa', 'USDA condensed milk solids basis'),
      ]);
      expect(
        index.suggest('sev')!.candidates.single.entry.foodName,
        'Sev, thin',
      );
      expect(index.suggest('sev')!.tier, 'prefix');
      expect(
        index.suggest('khoya')!.candidates.single.entry.foodName,
        'Khoya / Mawa',
      );
    });

    test("a row's own name outranks another row's synonym", () {
      final index = CatalogIndex([
        _row('Rava kesari', 'Rava 35 g, ghee 18 g', also: ['kesari bath']),
        _row('Kesari bath', 'Rava 35 g, ghee 18 g, sugar 30 g'),
      ]);
      final suggestion = index.suggest('kesari bath')!;
      expect(suggestion.tier, 'name');
      expect(suggestion.candidates.single.entry.foodName, 'Kesari bath');
    });

    test("a synonym outranks another row's leading segment", () {
      final index = CatalogIndex([
        _row('Vermicelli, raw', 'USDA', also: ['semiya']),
        _row('Vermicelli bath', 'Vermicelli 45 g, oil 8 g'),
      ]);
      expect(
        index.suggest('semiya')!.candidates.single.entry.foodName,
        'Vermicelli, raw',
      );
      expect(
        index.suggest('vermicelli')!.candidates.single.entry.foodName,
        'Vermicelli, raw',
      );
    });

    test('several claimants are reported as a decision, not tie-broken', () {
      final index = CatalogIndex([
        _row('Palya, beans', 'French beans 95 g, oil 6 g'),
        _row('Palya, cabbage', 'Cabbage 95 g, oil 6 g'),
        _row('Palya, potato', 'Potato 100 g, oil 8 g'),
      ]);
      final suggestion = index.suggest('palya')!;
      expect(suggestion.isAmbiguous, isTrue);
      expect(suggestion.candidates, hasLength(3));
      expect(suggestion.line, startsWith('  // TODO'));
    });

    test('a row needing manual review is not offered as a candidate', () {
      final index = CatalogIndex([
        _row('Muthiya, steamed', 'Wheat flour 25 g, besan 10 g, oil 8 g'),
        _row('Muthiya, fried', 'As above + absorbed oil 6 g'),
      ]);
      final suggestion = index.suggest('muthiya')!;
      expect(suggestion.isAmbiguous, isFalse);
      expect(suggestion.candidates.single.entry.foodName, 'Muthiya, steamed');
    });

    test('a name nothing matches has no suggestion at all', () {
      expect(CatalogIndex(const []).suggest('unobtanium'), isNull);
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
