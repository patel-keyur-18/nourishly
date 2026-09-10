import 'dart:io';

import 'package:catalog_pipeline/catalog_pipeline.dart';
import 'package:test/test.dart';

/// These tests run against the real, committed `docs/catalog/*.md` files
/// rather than fixtures — the parser's whole job is to understand exactly
/// those files, so a fixture would test something else.
void main() {
  final parser = CatalogSourceParser();
  const catalogDir = '../../docs/catalog';

  test('parses every Tier-1-marked row in 01-common.md without throwing', () {
    final entries = parser.parseFile(File('$catalogDir/01-common.md'));

    expect(entries, isNotEmpty);
    expect(entries.where((e) => e.isTier1), isNotEmpty);
  });

  test(
    'every entry has a non-empty food name and a positive serving amount',
    () {
      for (final fileName in [
        '01-common.md',
        '02-gujarat.md',
        '03-tamil-nadu.md',
        '04-karnataka.md',
      ]) {
        final entries = parser.parseFile(File('$catalogDir/$fileName'));
        for (final entry in entries) {
          expect(entry.foodName, isNotEmpty, reason: 'in $fileName');
          expect(
            entry.servingAmount,
            greaterThan(0),
            reason: '${entry.foodName} in $fileName',
          );
          expect(
            entry.rawComposition,
            isNotEmpty,
            reason: '${entry.foodName} in $fileName',
          );
        }
      }
    },
  );

  test('a known row parses exactly as written (Rice, white, cooked)', () {
    final entries = parser.parseFile(File('$catalogDir/01-common.md'));
    final rice = entries.firstWhere((e) => e.foodName == 'Rice, white, cooked');

    expect(rice.isTier1, isTrue);
    expect(rice.alsoNames, ['chawal', 'sadam', 'anna', 'bhaat']);
    expect(rice.servingLabel, '1 katori');
    expect(rice.servingAmount, 150);
    expect(rice.section, 'Grains and breads');
    expect(rice.rawComposition, 'USDA rice white long-grain cooked');
  });

  test('a row with "—" for Also parses to an empty alt-names list', () {
    final entries = parser.parseFile(File('$catalogDir/01-common.md'));
    final entry = entries.firstWhere((e) => e.foodName == 'Rice, white, raw');

    expect(entry.alsoNames, isEmpty);
  });

  test('the g/ml weight-column header is captured, not assumed', () {
    final entries = parser.parseFile(File('$catalogDir/01-common.md'));
    final dairySection = entries.where((e) => e.section == 'Dairy');

    expect(dairySection, isNotEmpty);
    expect(dairySection.first.weightColumnLabel, 'g/ml');
  });

  test('total rows across all four files are in the ballpark the catalog README claims (~365)', () {
    var total = 0;
    for (final fileName in [
      '01-common.md',
      '02-gujarat.md',
      '03-tamil-nadu.md',
      '04-karnataka.md',
    ]) {
      total += parser.parseFile(File('$catalogDir/$fileName')).length;
    }
    // README.md says ~130+85+80+70 = ~365; allow slack since "~" counts
    // are approximate by the README's own admission.
    expect(total, inInclusiveRange(300, 430));
  });
}
