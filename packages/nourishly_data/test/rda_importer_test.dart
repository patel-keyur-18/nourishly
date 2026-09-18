import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly_data/nourishly_data.dart';

/// The version field is the entire upgrade mechanism for the reference
/// table, and it fails silently in the one direction that matters: an
/// asset edited without a version bump ships to nobody who already has the
/// app, and the only install that ever sees the new numbers is a fresh
/// one. That is how the pregnancy rows were nearly lost — added, tested on
/// a fresh database, and dead on every real device.
void main() {
  late NourishlyDatabase db;

  setUp(() => db = NourishlyDatabase.forTesting());
  tearDown(() => db.close());

  const v1 = '''
  {
    "rulesetVersion": "1.0.0",
    "region": "IN",
    "sourceCitation": "ICMR-NIN 2020",
    "references": [
      {"nutrientId": "iron", "sex": "female", "ageMin": 19, "ageMax": 120,
       "rdaAmount": 29, "unit": "mg"}
    ]
  }
  ''';

  const v2 = '''
  {
    "rulesetVersion": "1.1.0",
    "region": "IN",
    "sourceCitation": "ICMR-NIN 2020",
    "references": [
      {"nutrientId": "iron", "sex": "female", "ageMin": 19, "ageMax": 120,
       "rdaAmount": 29, "unit": "mg"},
      {"nutrientId": "iron", "lifestage": "pregnant_t2", "sex": "female",
       "ageMin": 19, "ageMax": 120, "rdaAmount": 27, "unit": "mg"}
    ]
  }
  ''';

  test('a new version reaches a device that already has the old one', () async {
    expect(await RdaImporter(db).importFromString(v1), isTrue);
    expect(
      await RdaImporter(db).importFromString(v1),
      isFalse,
      reason: 'the same version is not re-imported on every launch',
    );

    expect(await RdaImporter(db).importFromString(v2), isTrue);

    final rows = await db.select(db.rdaReferences).get();
    expect(rows.map((r) => r.lifestage).toSet(), {'adult', 'pregnant_t2'});
  });

  test('the previous version is removed rather than left alongside', () async {
    await RdaImporter(db).importFromString(v1);
    await RdaImporter(db).importFromString(v2);

    final versions = await db
        .select(db.rdaReferences)
        .map((r) => r.rulesetVersion)
        .get();
    expect(
      versions.toSet(),
      {'1.1.0'},
      reason:
          'referencesFor filters on region, lifestage and age but not '
          'on version — two versions in place would have it choosing '
          'between them arbitrarily',
    );
  });

  test('a lifestage row does not collide with the adult row it sits '
      'beside', () async {
    await RdaImporter(db).importFromString(v2);

    final iron = await (db.select(
      db.rdaReferences,
    )..where((r) => r.nutrientId.equals('iron'))).get();
    expect(iron, hasLength(2));
    expect(iron.map((r) => r.id).toSet(), hasLength(2));
  });

  test('the bundled asset carries a version no shipped build has used '
      'before', () async {
    final asset = jsonDecode(
      File('../../app/assets/reference/rda_icmr_nin_2020.json')
          .readAsStringSync(),
    ) as Map<String, dynamic>;

    // Not an arbitrary assertion: 1.0.0 is what shipped without the
    // pregnancy rows. If this file ever gains a row again while the
    // version stays put, this is the test that says so.
    expect(asset['rulesetVersion'], isNot('1.0.0'));

    final references = (asset['references'] as List)
        .cast<Map<String, dynamic>>();
    final lifestages = references
        .map((r) => r['lifestage'] as String? ?? 'adult')
        .toSet();
    expect(lifestages, contains('pregnant_t2'));
    expect(lifestages, contains('lactating_0_6'));
  });
}
