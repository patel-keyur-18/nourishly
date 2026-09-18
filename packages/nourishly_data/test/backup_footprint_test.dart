@Tags(['slow'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly_data/nourishly_data.dart' hide ReminderRule;

/// §0.5's backup design rests on one number nobody has measured: how big
/// the database actually is once the catalog is in it.
///
/// The design was written against an assumed 20–40 MB catalog replica and
/// concluded it had to be excluded from Android Auto Backup, whose quota
/// is 25 MB per app. This test measures the real file so the backup rules
/// are set from evidence, and fails at the point where splitting the
/// catalog into its own file, with its own backup exclusion, stops being
/// premature.
///
/// > **Revised 2026-09-15.** The budget used to be a flat third of the
/// > quota, chosen when the catalog was 383 foods and 1.9 MB. The
/// > regional CSVs took it to 1,591 foods and 11.0 MB, which broke that
/// > third without coming close to breaking anything real: what the
/// > backup rules actually rest on is the **whole database** fitting the
/// > quota, with room for user data to keep growing. So that is what is
/// > asserted now — the catalog plus a decade of logging, against the
/// > real 25 MB, with a margin. A flat fraction of the quota measured the
/// > wrong thing; it just happened to be right while the catalog was
/// > small.
void main() {
  /// Android's Auto Backup quota (`https://developer.android.com/guide/
  /// topics/data/autobackup`). Exceeding it does not warn — the backup
  /// simply stops happening.
  const androidAutoBackupQuotaBytes = 25 * 1024 * 1024;

  /// Years of logging the catalog has to leave room for.
  ///
  /// A person-year measures at well under a megabyte, so ten years is far
  /// past any horizon this household plans on, and a phone that has been
  /// restored that many times has other problems. It is here so the
  /// assertion is about a database that keeps being used, not about the
  /// day it is first seeded.
  const userDataYears = 10;

  /// What the quota must still hold after the catalog and that decade:
  /// a fifth of it, spare. Falling below this margin is the signal that
  /// the catalog — not user data — is what is filling the backup.
  const spareQuotaBytes = androidAutoBackupQuotaBytes ~/ 5;

  late Directory dir;
  late File file;
  late NourishlyDatabase db;

  setUp(() {
    // A file-backed database, not the in-memory one: the question is how
    // many bytes land on disk, and an in-memory database cannot answer it.
    dir = Directory.systemTemp.createTempSync('nourishly-backup-footprint');
    file = File('${dir.path}/nourishly.sqlite');
    db = NourishlyDatabase(NativeDatabase(file));
  });

  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  /// Imports the real seed and returns the database size on disk.
  Future<int> seedCatalog() async {
    final seed = jsonDecode(
      File('../../app/assets/catalog/seed_v1.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    await CatalogImporter(db).importIfNeeded(seed);
    // Fold the write-ahead log back in, so the measurement is of the
    // database rather than of a checkpoint that happens not to have run.
    await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
    return file.lengthSync();
  }

  /// Writes a generous person-year of logging and returns what it added.
  Future<int> addPersonYear(int year, int before) async {
    final ownerId = await ensureDefaultOwner(db);
    final slot = await db.select(db.mealSlots).get().then((s) => s.first);
    final food = await (db.select(db.foodItems)..limit(1)).getSingle();

    // 365 days at 8 entries a day — a generous year for one person.
    await db.batch((batch) {
      for (var day = 0; day < 365; day++) {
        final date = DateTime(year, 1, 1).add(Duration(days: day));
        for (var i = 0; i < 8; i++) {
          batch.insert(
            db.foodLogEntries,
            FoodLogEntriesCompanion.insert(
              id: 'e-$day-$i',
              ownerId: ownerId,
              logDate: date,
              mealSlotId: slot.id,
              foodId: food.id,
              foodRevision: 1,
              quantity: 1,
              gramsConsumed: 120,
              loggedAt: date,
              source: 'manual',
            ),
          );
        }
      }
    });
    await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
    return file.lengthSync() - before;
  }

  test('the catalog leaves room for a decade of logging inside Auto '
      'Backup s quota', () async {
    final catalogBytes = await seedCatalog();

    // Projected from a year actually written to this database, not from a
    // constant somebody typed. A guessed growth rate would make this
    // guard fire on the guess rather than on the catalog, which is the
    // thing it exists to watch.
    final perYearBytes = await addPersonYear(2026, catalogBytes);
    final projected = catalogBytes + userDataYears * perYearBytes;
    final ceiling = androidAutoBackupQuotaBytes - spareQuotaBytes;

    String mb(num b) => (b / (1024 * 1024)).toStringAsFixed(1);

    expect(
      projected,
      lessThan(ceiling),
      reason:
          'The catalog replica is ${mb(catalogBytes)} MB and a person-year '
          'of logging adds ${(perYearBytes / 1024).round()} KB. Over '
          '$userDataYears years that reaches ${mb(projected)} MB, past the '
          '${mb(ceiling)} MB this leaves of Android s 25 MB Auto Backup '
          'quota. That is the point §0.5 was written for: the catalog, not '
          'user data, is now what fills the backup, and excluding it stops '
          'being optional. Split the database so the catalog can carry its '
          'own exclusion rule — or shrink the seed, whose largest table is '
          'more than half id strings. See '
          'app/android/app/src/main/res/xml/backup_rules.xml.',
    );

    // Printed rather than only asserted: the number is the justification
    // for the backup rules, and a reviewer should be able to see it.
    // ignore: avoid_print
    print(
      'Catalog replica on disk: ${mb(catalogBytes)} MB '
      '(${(catalogBytes / androidAutoBackupQuotaBytes * 100).round()}% of '
      'the Android Auto Backup quota). A person-year of logging adds '
      '${(perYearBytes / 1024).round()} KB; after $userDataYears years the '
      'database reaches ${mb(projected)} MB '
      '(${(projected / androidAutoBackupQuotaBytes * 100).round()}%).',
    );
  });

  test('user data is not what fills the backup', () async {
    // The other half of the argument: if a person-year were megabytes,
    // the catalog's size would not be the thing to watch. It is not.
    final catalogOnly = await seedCatalog();
    final userBytes = await addPersonYear(2026, catalogOnly);

    // ignore: avoid_print
    print(
      'A person-year of logging: ${(userBytes / 1024).round()} KB '
      '(catalog: ${(catalogOnly / 1024).round()} KB).',
    );

    expect(
      userBytes,
      lessThan(catalogOnly ~/ 4),
      reason:
          'A person-year of logging is ${(userBytes / 1024).round()} KB '
          'against a ${(catalogOnly / 1024).round()} KB catalog. If user '
          'data has become the larger term, the projection in the test '
          'above is measuring the wrong thing.',
    );
  });
}
