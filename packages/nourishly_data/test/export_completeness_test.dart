import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly_data/nourishly_data.dart' hide ReminderRule;

/// The guard on FR-S-03: "local data export produces a **complete**,
/// re-importable archive."
///
/// Completeness is not a property anyone can maintain by remembering. A
/// table added in a year's time is one line in `exportedTables` away from
/// being backed up, and zero lines away from being silently missing from
/// every export from then on. This test makes that omission a build
/// failure: every table in the live schema must be either exported or
/// listed below with a reason it is not.
void main() {
  /// Tables an export deliberately leaves out, each with the reason.
  ///
  /// The through-line: everything here is either rebuilt from the bundled
  /// catalog asset on launch, or is an index derived from something that
  /// is. None of it is a user's data, and none of it would survive being
  /// restored onto a build with a newer catalog anyway.
  const notExported = <String, String>{
    'nutrient_groups': 'Reference data, rebuilt from the bundled asset.',
    'nutrients': 'Reference data, rebuilt from the bundled asset.',
    'rda_references': 'Reference data, rebuilt from the bundled asset.',
    'catalog_versions': 'Catalog provenance, rebuilt on import.',
    'food_external_refs':
        'Catalog-only: barcodes and USDA ids for pipeline-owned foods. A '
        'custom food has no external reference to carry.',
    'food_search_index':
        'An FTS5 index over the catalog, rebuilt by CatalogImporter on '
        'every launch. Exporting an index rather than its source would be '
        'backing up a cache.',
  };

  late NourishlyDatabase db;

  setUp(() => db = NourishlyDatabase.forTesting());
  tearDown(() => db.close());

  test('every table is either exported or explicitly excluded', () {
    final exported = {for (final table in exportedTables) table.name};
    final live = {for (final table in db.allTables) table.actualTableName};

    final unaccounted = live
        .difference(exported)
        .difference(notExported.keys.toSet());
    expect(
      unaccounted,
      isEmpty,
      reason:
          'These tables are in the schema but in neither list. Add them to '
          '`exportedTables` so they are backed up, or to `notExported` '
          'above with the reason they should not be: $unaccounted',
    );

    // And the reverse: an export list naming a table that no longer
    // exists would fail at runtime, on the one path a user only exercises
    // when something has already gone wrong.
    expect(exported.difference(live), isEmpty);
  });

  test('every exported table names columns that exist', () {
    for (final table in exportedTables) {
      final live = db.allTables.firstWhere(
        (t) => t.actualTableName == table.name,
      );
      final columns = {for (final column in live.$columns) column.name};
      for (final key in table.primaryKey) {
        expect(
          columns,
          contains(key),
          reason: '${table.name} has no column "$key"',
        );
      }
      final relation = table.childOf;
      if (relation != null) {
        expect(
          columns,
          contains(relation.$2),
          reason: '${table.name} has no foreign key "${relation.$2}"',
        );
        expect(
          exportedTables.map((t) => t.name),
          contains(relation.$1),
          reason: '${table.name} names a parent that is not exported',
        );
      }
    }
  });

  test('parents are listed before their children', () {
    // The importer makes a single forward pass, so a child appearing
    // before its parent would insert against a row that is not there yet.
    final seen = <String>{};
    for (final table in exportedTables) {
      final relation = table.childOf;
      if (relation != null) {
        expect(
          seen,
          contains(relation.$1),
          reason: '${table.name} comes before its parent ${relation.$1}',
        );
      }
      seen.add(table.name);
    }
  });

  test('every owner-scoped table binds exactly one owner placeholder', () {
    for (final table in exportedTables) {
      expect(
        '?'.allMatches(table.scope).length,
        1,
        reason:
            '${table.name} scope must take exactly one owner id: '
            '${table.scope}',
      );
    }
  });
}
