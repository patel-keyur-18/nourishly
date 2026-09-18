import 'dart:io';

import 'package:catalog_pipeline/catalog_pipeline.dart';
import 'package:test/test.dart';

void main() {
  late Directory work;
  late Directory csvDir;
  late Directory mdDir;

  setUp(() {
    work = Directory.systemTemp.createTempSync('catalog_sources_');
    csvDir = Directory('${work.path}/csv')..createSync();
    mdDir = Directory('${work.path}/md')..createSync();
  });
  tearDown(() => work.deleteSync(recursive: true));

  const header = 'Food,Also,Serving,g,Composition\n';

  void csv(String name, String rows) =>
      File('${csvDir.path}/$name').writeAsStringSync('$header$rows');

  void markdown(String name, String rows) => File('${mdDir.path}/$name')
      .writeAsStringSync(
        '# Test\n\n## 1. Everything\n\n'
        '| Food | Also | Serving | g | Composition |\n|---|---|---|---|---|\n'
        '$rows',
      );

  CatalogSources load() => loadCatalogSources(
    csvDirectory: csvDir.path,
    markdownDirectory: mdDir.path,
  );

  group('discoverSourceFiles', () {
    test('puts the four hand-ordered CSVs first, then the rest '
        'alphabetically, then the markdown', () {
      csv('nourishly_west_bengal_food_catalog.csv', 'A,—,1,10,USDA a\n');
      csv('nourishly_andhra_pradesh_food_catalog.csv', 'B,—,1,10,USDA b\n');
      csv('nourishly_indian_food_catalog.csv', 'C,—,1,10,USDA c\n');
      markdown('01-common.md', '| D | — | 1 | 10 | USDA d |\n');

      final names = [
        for (final f in discoverSourceFiles(
          csvDirectory: csvDir.path,
          markdownDirectory: mdDir.path,
        ))
          f.uri.pathSegments.last,
      ];
      expect(names, [
        'nourishly_indian_food_catalog.csv',
        'nourishly_andhra_pradesh_food_catalog.csv',
        'nourishly_west_bengal_food_catalog.csv',
        '01-common.md',
      ]);
    });

    test('a missing directory is not an error — a repo may have only one', () {
      expect(
        discoverSourceFiles(
          csvDirectory: '${work.path}/nope',
          markdownDirectory: mdDir.path,
        ),
        isEmpty,
      );
    });
  });

  group('one row per food', () {
    test('the higher-precedence CSV wins and the loser is reported', () {
      csv(
        'nourishly_indian_food_catalog.csv',
        'Avial,—,1 katori,150,Coconut 25 g\n',
      );
      csv(
        'nourishly_kerala_food_catalog.csv',
        'Avial,—,1 katori,140,Coconut 30 g\n',
      );

      final sources = load();
      expect(sources.rows, hasLength(1));
      expect(sources.rows.single.entry.servingAmount, 150);
      expect(sources.superseded, hasLength(1));
      expect(
        sources.superseded.single.loser.entry.sourceFile,
        'nourishly_kerala_food_catalog.csv',
      );
    });

    test('a CSV dish supersedes the markdown row of the same name', () {
      csv(
        'nourishly_indian_food_catalog.csv',
        'Dhokla,—,1 piece,60,Besan 35 g\n',
      );
      markdown(
        '02-gujarat.md',
        '| Dhokla | khaman | 1 piece | 55 | Besan 30 g |\n',
      );

      final sources = load();
      expect(sources.rows, hasLength(1));
      expect(sources.rows.single.entry.sourceFile, endsWith('.csv'));
    });

    test('names match however they are cased or spaced, and through the '
        'brackets a row name carries', () {
      csv(
        'nourishly_indian_food_catalog.csv',
        'Chana (kabuli),—,1,100,USDA a\n',
      );
      csv(
        'nourishly_kerala_food_catalog.csv',
        'chana  kabuli,—,1,100,USDA b\n',
      );
      expect(load().rows, hasLength(1));
    });
  });

  group('an ingredient row is never displaced by a dish of the same name', () {
    test('the markdown ingredient row wins over a CSV recipe', () {
      csv(
        'nourishly_kerala_food_catalog.csv',
        'Coconut water,tender coconut water,1 glass,200,Coconut Water 200 g\n',
      );
      markdown(
        '01-common.md',
        '| Coconut water | nariyal pani | 1 glass | 200 | USDA coconut water |\n',
      );

      final sources = load();
      expect(sources.rows, hasLength(1));
      expect(sources.rows.single.composition, isA<UsdaLookup>());
      expect(
        sources.superseded.single.loser.entry.sourceFile,
        endsWith('.csv'),
      );
    });

    test('but a CSV ingredient row still beats a markdown ingredient row', () {
      csv(
        'nourishly_indian_food_catalog.csv',
        'Salt,—,100 g,100,USDA salt table\n',
      );
      markdown('01-common.md', '| Salt | mithu | 100 g | 100 | USDA salt |\n');

      expect(load().rows.single.entry.sourceFile, endsWith('.csv'));
    });
  });

  test('loadCatalogEntries returns the de-duplicated entries', () {
    csv('nourishly_indian_food_catalog.csv', 'Idli,—,2 pieces,100,Rice 45 g\n');
    csv(
      'nourishly_tamil_nadu_food_catalog.csv',
      'Idli,idly,2 pieces,100,Rice 45 g\n',
    );

    final entries = loadCatalogEntries(
      csvDirectory: csvDir.path,
      markdownDirectory: mdDir.path,
    );
    expect(entries.map((e) => e.foodName), ['Idli']);
  });
}
