@Tags(['slow'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly_data/nourishly_data.dart' hide ReminderRule;

/// §0.5's backup design rests on one number nobody has measured: how big
/// the database actually is once the catalog is in it.
///
/// The design was written against an assumed 20–40 MB catalog replica and
/// concluded it had to be excluded from Android Auto Backup, whose quota
/// is 25 MB per app. The catalog that shipped is 383 foods, not 30,000.
/// This test measures the real file so the backup rules are set from
/// evidence, and fails if the catalog ever grows enough to invalidate
/// them — which is the point at which splitting it into its own file, and
/// its own backup exclusion, stops being premature.
void main() {
  /// Android's Auto Backup quota (`https://developer.android.com/guide/
  /// topics/data/autobackup`). Exceeding it does not warn — the backup
  /// simply stops happening.
  const androidAutoBackupQuotaBytes = 25 * 1024 * 1024;

  /// The headroom the rules assume. Years of a household's logging is a
  /// few MB; leaving the catalog at or under a third of the quota means
  /// user data has room to grow for a very long time before anyone has to
  /// think about this again.
  const catalogBudgetBytes = androidAutoBackupQuotaBytes ~/ 3;

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

  test('the catalog replica fits well inside Auto Backup s quota', () async {
    final seed =
        jsonDecode(
              File(
                '../../app/assets/catalog/seed_v1.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    await CatalogImporter(db).importIfNeeded(seed);
    // Fold the write-ahead log back in, so the measurement is of the
    // database rather than of a checkpoint that happens not to have run.
    await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');

    final bytes = file.lengthSync();
    final megabytes = (bytes / (1024 * 1024)).toStringAsFixed(1);

    expect(
      bytes,
      lessThan(catalogBudgetBytes),
      reason:
          'The catalog replica is $megabytes MB, against a budget of '
          '${(catalogBudgetBytes / (1024 * 1024)).toStringAsFixed(1)} MB. '
          'Above this, §0.5 s plan to exclude the catalog from platform '
          'backup stops being optional: the database has to be split so '
          'the catalog can carry its own exclusion rule. See '
          'app/android/app/src/main/res/xml/backup_rules.xml.',
    );

    // Printed rather than only asserted: the number is the justification
    // for the backup rules, and a reviewer should be able to see it.
    // ignore: avoid_print
    print('Catalog replica on disk: $megabytes MB '
        '(${(bytes / androidAutoBackupQuotaBytes * 100).round()}% of the '
        'Android Auto Backup quota).');
  });

  test('a household year of logging is small next to the catalog', () async {
    final ownerId = await ensureDefaultOwner(db);
    final seed =
        jsonDecode(
              File(
                '../../app/assets/catalog/seed_v1.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    await CatalogImporter(db).importIfNeeded(seed);
    await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
    final catalogOnly = file.lengthSync();

    final slot = await db.select(db.mealSlots).get().then((s) => s.first);
    final food = await (db.select(
      db.foodItems,
    )..limit(1)).getSingle();

    // 365 days at 8 entries a day — a generous year for one person.
    await db.batch((batch) {
      for (var day = 0; day < 365; day++) {
        final date = DateTime(2026, 1, 1).add(Duration(days: day));
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

    final withYear = file.lengthSync();
    final userBytes = withYear - catalogOnly;
    // ignore: avoid_print
    print(
      'A person-year of logging: ${(userBytes / 1024).round()} KB '
      '(catalog: ${(catalogOnly / 1024).round()} KB).',
    );

    expect(
      withYear,
      lessThan(25 * 1024 * 1024),
      reason:
          'Catalog plus a year of logging must still fit in the Auto '
          'Backup quota for the whole-database rule to hold.',
    );
  });
}
