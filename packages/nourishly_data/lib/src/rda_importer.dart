import 'dart:convert';

import 'package:drift/drift.dart';

import 'database.dart';

/// Loads the bundled ICMR-NIN reference table into [RdaReferences].
///
/// Separate from [CatalogImporter] because the two have nothing to do with
/// each other: the catalog comes out of the FoodData Central pipeline and
/// changes whenever the household curates a new dish, while this is a
/// published reference table that changes when a standards body revises it.
/// Bundling them would mean a catalog rebuild could silently move
/// somebody's iron target.
class RdaImporter {
  RdaImporter(this._db);

  final NourishlyDatabase _db;

  /// Imports [json] unless a table with the same ruleset version is already
  /// present. Returns true if rows were written.
  Future<bool> importIfNeeded(Map<String, dynamic> json) async {
    final rulesetVersion = json['rulesetVersion'] as String;
    final existing =
        await (_db.select(_db.rdaReferences)
              ..where((r) => r.rulesetVersion.equals(rulesetVersion))
              ..limit(1))
            .get();
    if (existing.isNotEmpty) return false;

    final region = json['region'] as String;
    final defaultCitation = json['sourceCitation'] as String;
    final references = (json['references'] as List)
        .cast<Map<String, dynamic>>();

    await _db.batch((batch) {
      for (final r in references) {
        final nutrientId = r['nutrientId'] as String;
        final sex = r['sex'] as String?;
        final ageMin = r['ageMin'] as int;
        final ageMax = r['ageMax'] as int;
        batch.insert(
          _db.rdaReferences,
          RdaReferencesCompanion.insert(
            // Deterministic rather than a UUID: re-importing the same
            // table must not create a second copy of a row, and the tuple
            // it is keyed on is exactly what makes a reference unique.
            id: '$rulesetVersion.$region.$nutrientId.${sex ?? 'any'}.$ageMin-$ageMax',
            nutrientId: nutrientId,
            region: region,
            sex: Value(sex),
            ageMin: ageMin,
            ageMax: ageMax,
            lifestage: (r['lifestage'] as String?) ?? 'adult',
            rdaAmount: (r['rdaAmount'] as num).toDouble(),
            aiAmount: Value((r['aiAmount'] as num?)?.toDouble()),
            upperLimit: Value((r['upperLimit'] as num?)?.toDouble()),
            sourceCitation: (r['sourceCitation'] as String?) ?? defaultCitation,
            rulesetVersion: rulesetVersion,
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
    return true;
  }

  Future<bool> importFromString(String source) =>
      importIfNeeded(jsonDecode(source) as Map<String, dynamic>);
}
