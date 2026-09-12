import 'dart:io';

import 'package:catalog_pipeline/catalog_pipeline.dart';
import 'package:test/test.dart';

void main() {
  group('cuisine', () {
    test('comes from the file for a single-cuisine file', () {
      expect(
        cuisineFor(sourceFile: '02-gujarat.md', section: 'Shaak'),
        'gujarati',
      );
      expect(
        cuisineFor(sourceFile: '05-everyday-north.md', section: 'Dal'),
        'north-indian',
      );
    });

    test('a mixed file overrides per section', () {
      // 07 holds pasta, Indian vermicelli and a breakfast from nowhere.
      expect(
        cuisineFor(sourceFile: '07-pasta-and-modern.md', section: 'Pasta'),
        'italian',
      );
      expect(
        cuisineFor(sourceFile: '07-pasta-and-modern.md', section: 'Vermicelli'),
        'pan-indian',
      );
      expect(
        cuisineFor(
          sourceFile: '07-pasta-and-modern.md',
          section: 'Modern breakfast',
        ),
        'modern',
      );
    });

    test('an unclassified file is null, not a guessed default', () {
      // A new file nobody has classified is a gap to notice.
      expect(cuisineFor(sourceFile: '99-new.md', section: 'Whatever'), isNull);
    });
  });

  group('course', () {
    test('a direct-USDA row is an ingredient whatever shelf it sits on', () {
      // "Dals and pulses" is a shelf, not a course: raw toor dal is not a
      // gravy, and tagging it as one would be false.
      expect(
        courseFor(section: 'Dals and pulses', isIngredient: true),
        'ingredient',
      );
      expect(
        courseFor(section: 'Dals and pulses', isIngredient: false),
        'gravy',
      );
    });

    test('reads the section heading', () {
      expect(
        courseFor(section: 'Breads and rotla', isIngredient: false),
        'bread',
      );
      expect(
        courseFor(section: 'Rice preparations', isIngredient: false),
        'rice',
      );
      expect(
        courseFor(section: 'Sweets (mithai)', isIngredient: false),
        'sweet',
      );
      expect(
        courseFor(
          section: 'Farsan (snacks and steamed items)',
          isIngredient: false,
        ),
        'snack',
      );
      expect(
        courseFor(section: 'Tiffin — the daily core', isIngredient: false),
        'tiffin',
      );
    });

    test('biryani beats the bare word rice in the same heading', () {
      // Ordering in the keyword table is load-bearing.
      expect(
        courseFor(section: 'Rice dishes and biryani', isIngredient: false),
        'rice',
      );
    });

    test('an unrecognised heading is null rather than mislabelled', () {
      expect(courseFor(section: 'Miscellany', isIngredient: false), isNull);
    });
  });

  group('the committed catalog', () {
    late List<CatalogRow> rows;

    setUpAll(() {
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
      rows = [
        for (final file in files)
          for (final entry in parser.parseFile(file))
            CatalogRow(entry, compositionParser.parse(entry.rawComposition)),
      ];
    });

    test('every row gets a cuisine', () {
      final untagged = [
        for (final row in rows)
          if (cuisineFor(
                sourceFile: row.entry.sourceFile,
                section: row.entry.section,
              ) ==
              null)
            '${row.entry.sourceFile} § ${row.entry.section}',
      ];
      expect(
        untagged.toSet(),
        isEmpty,
        reason: 'add these to _cuisineByFile or _cuisineBySection',
      );
    });

    test('every dish gets a course, bar the one heading that spans many', () {
      // A missing course is allowed exactly where it is honest: one
      // heading in 01-common.md holds khichdi, rice dishes, sabzis and
      // chutneys together, and no single label covers those. Everything
      // else must be classified.
      final untagged = <String>{};
      for (final row in rows) {
        if (row.composition is UsdaLookup) continue;
        final course = courseFor(
          section: row.entry.section,
          isIngredient: false,
        );
        if (course == null) {
          untagged.add('${row.entry.sourceFile} § ${row.entry.section}');
        }
      }
      expect(untagged, {
        '01-common.md § Everyday preparations shared across all three states',
      }, reason: 'add any new heading to _courseKeywords');
    });

    test('a dish with no course still gets its cuisine', () {
      // No course must never cost a row its other tag.
      final chutney = rows.firstWhere(
        (r) => r.entry.foodName == 'Coconut chutney',
      );
      expect(
        cuisineTagsFor(
          sourceFile: chutney.entry.sourceFile,
          section: chutney.entry.section,
          isIngredient: false,
        ),
        ['cuisine:pan-indian'],
      );
    });

    test('the duplicate display names become distinguishable', () {
      // The bug this fixes, stated as a test: the shipped catalog carries
      // twelve names that two or three rows share, and search renders them
      // as identical lines. Their cuisines must differ, or the tag does
      // not actually help anyone choose.
      final byName = <String, List<CatalogRow>>{};
      for (final row in rows) {
        (byName[row.entry.foodName] ??= []).add(row);
      }
      final shared = byName.entries.where((e) => e.value.length > 1);
      expect(shared, isNotEmpty, reason: 'the duplicates are real');

      for (final entry in shared) {
        final cuisines = {
          for (final row in entry.value)
            cuisineFor(
              sourceFile: row.entry.sourceFile,
              section: row.entry.section,
            ),
        };
        expect(
          cuisines,
          hasLength(entry.value.length),
          reason:
              '"${entry.key}" is ${entry.value.length} rows but only '
              '${cuisines.length} cuisine(s) — still unchoosable in search',
        );
      }
    });
  });
}
