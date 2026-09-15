import 'dart:io';

import 'package:catalog_pipeline/catalog_pipeline.dart';
import 'package:test/test.dart';

void main() {
  late Directory work;

  setUp(() => work = Directory.systemTemp.createTempSync('csv_source_'));
  tearDown(() => work.deleteSync(recursive: true));

  File write(String name, String contents) =>
      File('${work.path}/$name')..writeAsStringSync(contents);

  const header = 'Food,Also,Serving,g,Composition\n';

  group('sectionFor', () {
    test('names the section after the file, not after a heading', () {
      expect(
        CsvSourceParser.sectionFor('nourishly_kerala_food_catalog.csv'),
        'Kerala food catalog',
      );
    });

    test('strips the shared prefix the regional files all carry', () {
      expect(
        CsvSourceParser.sectionFor('nourishly_west_bengal_food_catalog.csv'),
        'West bengal food catalog',
      );
    });
  });

  group('parseFile', () {
    test('reads the same five columns the markdown tables use', () {
      final entries = CsvSourceParser().parseFile(
        write(
          'nourishly_kerala_food_catalog.csv',
          '${header}Avial,aviyal,1 katori,150,'
              '"Mixed Vegetables 90 g, Coconut 25 g, Curd 20 g"\n',
        ),
      );

      expect(entries, hasLength(1));
      final entry = entries.single;
      expect(entry.foodName, 'Avial');
      expect(entry.alsoNames, ['aviyal']);
      expect(entry.servingLabel, '1 katori');
      expect(entry.servingAmount, 150);
      expect(entry.section, 'Kerala food catalog');
      expect(entry.rawComposition, contains('Coconut 25 g'));
    });

    test('keeps a quoted composition whole rather than splitting its '
        'commas into columns', () {
      final entries = CsvSourceParser().parseFile(
        write(
          'nourishly_bihar_food_catalog.csv',
          '${header}Litti,—,2 pieces,120,"Wheat Flour 60 g, Sattu 25 g, Ghee 8 g"\n',
        ),
      );
      expect(
        entries.single.rawComposition,
        'Wheat Flour 60 g, Sattu 25 g, Ghee 8 g',
      );
    });

    test(
      'drops a byte-order mark instead of naming the first column after it',
      () {
        final entries = CsvSourceParser().parseFile(
          write(
            'nourishly_gujarat_food_catalog.csv',
            '\u{FEFF}${header}Dhokla,khaman,1 piece,60,Besan 35 g\n',
          ),
        );
        expect(entries.single.foodName, 'Dhokla');
      },
    );

    test('ignores a trailing blank line', () {
      final entries = CsvSourceParser().parseFile(
        write(
          'nourishly_tamil_nadu_food_catalog.csv',
          '${header}Idli,idly,2 pieces,100,Rice 45 g\n\n',
        ),
      );
      expect(entries, hasLength(1));
    });

    test('rejects a file whose columns are not the catalog five', () {
      expect(
        () => CsvSourceParser().parseFile(
          write('nourishly_x_food_catalog.csv', 'Dish,Weight\nIdli,100\n'),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('refuses to guess a serving weight that is not a number', () {
      expect(
        () => CsvSourceParser().parseFile(
          write(
            'nourishly_x_food_catalog.csv',
            '${header}Idli,—,2 pieces,about 100,Rice 45 g\n',
          ),
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('cooking yield'),
          ),
        ),
      );
    });

    test('splits Also on commas and slashes, and treats a dash as none', () {
      final entries = CsvSourceParser().parseFile(
        write(
          'nourishly_x_food_catalog.csv',
          '${header}Medu vada,"medhu vadai, ulundu vadai",2 pieces,100,Urad Dal 55 g\n'
              'Chapati,—,1 piece,40,Wheat Flour 32 g\n',
        ),
      );
      expect(entries.first.alsoNames, ['medhu vadai', 'ulundu vadai']);
      expect(entries.last.alsoNames, isEmpty);
    });
  });
}
