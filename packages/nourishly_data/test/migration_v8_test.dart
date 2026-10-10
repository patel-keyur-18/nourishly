import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly_data/nourishly_data.dart';

/// v7 -> v8 adds `user_preferences.share_with_navmaas` (ADR-012).
///
/// The one thing that must hold: a phone upgrading from v7 does not start
/// sharing on its own. Sharing is something she turns on, so every row
/// written before the switch existed has to come back as off.
///
/// v7 is simulated by dropping the column from a fresh database, which is
/// the shape a device upgrading from the previous release is in.
void main() {
  late NourishlyDatabase db;

  setUp(() => db = NourishlyDatabase.forTesting());
  tearDown(() => db.close());

  test('the database reports the new schema version', () {
    expect(db.schemaVersion, 8);
  });

  test('preferences written before the upgrade do not share', () async {
    final ownerId = await ensureDefaultOwner(db);
    await PreferencesDao(db).forOwner(ownerId);
    await db.customStatement(
      'ALTER TABLE user_preferences DROP COLUMN share_with_navmaas',
    );

    await db.migration.onUpgrade(Migrator(db), 7, 8);

    final prefs = await PreferencesDao(db).forOwner(ownerId);
    expect(prefs.shareWithNavmaas, isFalse);
  });

  test('the switch round-trips', () async {
    final ownerId = await ensureDefaultOwner(db);
    final dao = PreferencesDao(db);
    expect((await dao.forOwner(ownerId)).shareWithNavmaas, isFalse);
    await dao.update(ownerId, shareWithNavmaas: true);
    expect((await dao.forOwner(ownerId)).shareWithNavmaas, isTrue);
    await dao.update(ownerId, shareWithNavmaas: false);
    expect((await dao.forOwner(ownerId)).shareWithNavmaas, isFalse);
  });
}
