import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly_data/nourishly_data.dart' hide ReminderRule;
import 'package:uuid/uuid.dart';

/// FR-U-13, FR-S-03, §30.6 and §0.5 — the export has to be complete, the
/// import has to merge rather than duplicate, and neither may report
/// success while quietly losing a row.
void main() {
  const uuid = Uuid();
  late NourishlyDatabase db;
  late String ownerId;

  /// A minimal but real graph: reference rows, a catalog food, a profile
  /// with targets, a logged meal with its nutrient snapshot, water, a
  /// custom food, a template, a favourite and a reminder.
  Future<void> seed(NourishlyDatabase db, String ownerId) async {
    await db
        .into(db.nutrientGroups)
        .insert(
          NutrientGroupsCompanion.insert(
            id: 'macros',
            name: 'Macros',
            sortOrder: 0,
          ),
        );
    for (final id in ['energy', 'protein']) {
      await db
          .into(db.nutrients)
          .insert(
            NutrientsCompanion.insert(
              id: id,
              groupId: 'macros',
              displayName: id,
              canonicalUnit: id == 'energy' ? 'kcal' : 'g',
              displayPrecision: 0,
              defaultCurveType: 'floor',
              isLimitNutrient: false,
              sortOrder: 0,
              isCore: true,
              minCoverageForScoring: 0.5,
            ),
          );
    }
    await db
        .into(db.mealSlots)
        .insert(
          MealSlotsCompanion.insert(
            id: 'slot-lunch',
            key: 'lunch',
            displayName: 'Lunch',
            sortOrder: 1,
          ),
        );
    await db
        .into(db.foodItems)
        .insert(
          FoodItemsCompanion.insert(
            id: 'food-dal',
            kind: 'dish',
            canonicalName: 'Dal',
            qualityTier: 'derived',
            provenanceSource: 'catalog_pipeline_recipe',
          ),
        );

    // A custom food the profile owns — this one must travel.
    await db
        .into(db.foodItems)
        .insert(
          FoodItemsCompanion.insert(
            id: 'food-mine',
            ownerId: Value(ownerId),
            kind: 'user_custom',
            canonicalName: "Ba's thepla",
            qualityTier: 'user',
            provenanceSource: 'user',
          ),
        );
    await db
        .into(db.foodNutrientValues)
        .insert(
          FoodNutrientValuesCompanion.insert(
            id: uuid.v7(),
            foodId: 'food-mine',
            nutrientId: 'protein',
            amountPer100g: 8.2,
            valueSource: 'label',
          ),
        );
    await db
        .into(db.servingSizes)
        .insert(
          ServingSizesCompanion.insert(
            id: 'serving-mine',
            foodId: 'food-mine',
            label: '1 thepla',
            grams: 45,
          ),
        );

    await db
        .into(db.userProfileVersions)
        .insert(
          UserProfileVersionsCompanion.insert(
            id: uuid.v7(),
            ownerId: ownerId,
            effectiveFrom: DateTime(2026, 1, 1),
            dateOfBirth: DateTime(1990, 5, 4),
            heightCm: 174,
            weightKg: 71,
            activityLevel: 'moderate',
            lifestage: 'adult',
            regionRef: 'IN',
            source: 'user',
          ),
        );
    const targetSetId = 'ts-1';
    await db
        .into(db.targetSets)
        .insert(
          TargetSetsCompanion.insert(
            id: targetSetId,
            ownerId: ownerId,
            effectiveFrom: DateTime(2026, 1, 1),
            derivationSource: 'derived',
            rulesetVersion: '2026.09',
          ),
        );
    await db
        .into(db.nutrientTargets)
        .insert(
          NutrientTargetsCompanion.insert(
            id: 'nt-1',
            targetSetId: targetSetId,
            nutrientId: 'protein',
            targetAmount: 95,
            curveType: 'floor',
            tolerance: 0.1,
          ),
        );

    await db
        .into(db.foodLogEntries)
        .insert(
          FoodLogEntriesCompanion.insert(
            id: 'entry-1',
            ownerId: ownerId,
            logDate: DateTime(2026, 9, 9),
            mealSlotId: 'slot-lunch',
            foodId: 'food-dal',
            foodRevision: 1,
            quantity: 1,
            gramsConsumed: 180,
            loggedAt: DateTime(2026, 9, 9, 13, 20),
            source: 'manual',
            updatedAt: Value(DateTime(2026, 9, 9, 13, 20)),
          ),
        );
    await db
        .into(db.logEntryNutrients)
        .insert(
          LogEntryNutrientsCompanion.insert(
            entryId: 'entry-1',
            nutrientId: 'protein',
            amount: 12.4,
          ),
        );
    await db
        .into(db.waterLogEntries)
        .insert(
          WaterLogEntriesCompanion.insert(
            id: 'water-1',
            ownerId: ownerId,
            logDate: DateTime(2026, 9, 9),
            loggedAt: DateTime(2026, 9, 9, 9, 0),
            volumeMl: 500,
            source: 'quick_add',
          ),
        );
    await db
        .into(db.mealTemplates)
        .insert(
          MealTemplatesCompanion.insert(
            id: 'tpl-1',
            ownerId: ownerId,
            name: 'Usual breakfast',
          ),
        );
    await db
        .into(db.mealTemplateItems)
        .insert(
          MealTemplateItemsCompanion.insert(
            id: 'tpli-1',
            templateId: 'tpl-1',
            foodId: 'food-dal',
            quantity: 1,
          ),
        );
    await db
        .into(db.favoriteFoods)
        .insert(
          FavoriteFoodsCompanion.insert(
            id: 'fav-1',
            ownerId: ownerId,
            foodId: 'food-dal',
          ),
        );
    await db
        .into(db.bodyWeightEntries)
        .insert(
          BodyWeightEntriesCompanion.insert(
            id: 'bw-1',
            ownerId: ownerId,
            recordedAt: DateTime(2026, 9, 1),
            weightKg: 71,
            source: 'manual',
          ),
        );
    await PreferencesDao(db).forOwner(ownerId);
    await ReminderDao(db).rulesFor(ownerId);
  }

  setUp(() async {
    db = NourishlyDatabase.forTesting();
    ownerId = await ensureDefaultOwner(db);
    await seed(db, ownerId);
  });

  tearDown(() => db.close());

  group('the archive', () {
    test('covers every owned table, and nothing catalog-owned', () async {
      final archive = await DataExporter(db).export(ownerId: ownerId);

      expect(archive.tables.keys.toSet(), {
        for (final table in exportedTables) table.name,
      });
      expect(archive.tables['food_log_entries'], hasLength(1));
      expect(archive.tables['log_entry_nutrients'], hasLength(1));
      expect(archive.tables['water_log_entries'], hasLength(1));
      expect(archive.tables['nutrient_targets'], hasLength(1));
      expect(archive.tables['meal_template_items'], hasLength(1));
      expect(archive.tables['reminder_rules'], hasLength(7));

      // The custom food travels; the catalog food does not — it is
      // rebuilt from the bundled asset on the other device (§0.5).
      final foods = archive.tables['food_items']!;
      expect(foods.map((f) => f['id']), ['food-mine']);
      expect(archive.tables['serving_sizes'], hasLength(1));
    });

    test('carries the manifest §30.6 requires', () async {
      final archive = await DataExporter(db).export(
        ownerId: ownerId,
        rulesetVersion: '2026.09',
        appVersion: '0.1.0',
      );
      final manifest = archive.manifest;
      expect(manifest.schemaVersion, db.schemaVersion);
      expect(manifest.rulesetVersion, '2026.09');
      expect(manifest.appVersion, '0.1.0');
      expect(manifest.profileId, ownerId);
      expect(manifest.counts['food_log_entries'], 1);
      // Without these an export is not reliably re-interpretable later.
      expect(manifest.toJson()['format'], 'nourishly.export');
    });

    test('is readable: dates are ISO-8601, booleans are true/false', () async {
      final archive = await DataExporter(db).export(ownerId: ownerId);
      final entry = archive.tables['food_log_entries']!.single;
      expect(entry['log_date'], startsWith('2026-09-09'));
      expect(DateTime.parse('${entry['logged_at']}').hour, 13);

      final preferences = archive.tables['user_preferences']!.single;
      expect(preferences['show_score'], isA<bool>());
    });

    test('survives a JSON round trip unchanged', () async {
      final archive = await DataExporter(db).export(ownerId: ownerId);
      final text = encodeArchiveJson(archive.toJson());
      final reread = ExportArchive.fromJson(
        jsonDecode(text) as Map<String, Object?>,
      );
      expect(reread.rowCount, archive.rowCount);
      expect(
        reread.tables['food_log_entries']!.single['grams_consumed'],
        180.0,
      );
    });

    test('CSV gets one file per non-empty entity, with a header', () async {
      final archive = await DataExporter(db).export(ownerId: ownerId);
      final files = encodeArchiveCsv(archive.toJson());

      expect(files.keys, contains('food_log_entries.csv'));
      expect(files.keys, contains('water_log_entries.csv'));
      final lines = files['water_log_entries.csv']!.trim().split('\n');
      expect(lines, hasLength(2));
      expect(lines.first, contains('volume_ml'));
      expect(lines.last, contains('500'));
    });

    test('CSV quotes a value containing a comma or a quote', () async {
      await db
          .into(db.mealTemplates)
          .insert(
            MealTemplatesCompanion.insert(
              id: 'tpl-2',
              ownerId: ownerId,
              name: 'Rice, dal and "the good" pickle',
            ),
          );
      final archive = await DataExporter(db).export(ownerId: ownerId);
      final csv = encodeArchiveCsv(archive.toJson())['meal_templates.csv']!;
      expect(csv, contains('"Rice, dal and ""the good"" pickle"'));
      // One header plus two data rows, so the comma did not split a line.
      expect(csv.trim().split('\n'), hasLength(3));
    });
  });

  group('import into a fresh install', () {
    late NourishlyDatabase fresh;

    setUp(() async {
      fresh = NourishlyDatabase.forTesting();
      // The catalog and reference rows come from the bundled asset on a
      // real device; here they are seeded so the foreign keys resolve.
      await seed(fresh, await ensureDefaultOwner(fresh));
      await fresh.customUpdate('DELETE FROM food_log_entries');
      await fresh.customUpdate('DELETE FROM water_log_entries');
      await fresh.customUpdate("DELETE FROM food_items WHERE id = 'food-mine'");
    });

    tearDown(() => fresh.close());

    test('restores everything, and says so only after reconciling', () async {
      final archive = await DataExporter(db).export(ownerId: ownerId);
      final freshOwner = await ensureDefaultOwner(fresh);

      final report = await DataImporter(fresh)
          .import(archive, asOwner: freshOwner);

      expect(
        report.succeeded,
        isTrue,
        reason: 'every entity must reconcile: ${report.unreconciled}',
      );
      for (final entity in report.entities) {
        expect(
          entity.present,
          entity.inArchive,
          reason: '${entity.table} lost rows',
        );
      }

      final entries = await fresh
          .customSelect('SELECT * FROM food_log_entries')
          .get();
      expect(entries, hasLength(1));
      expect(entries.single.data['grams_consumed'], 180.0);
      expect(entries.single.data['owner_id'], freshOwner);
    });

    test('importing the same file twice changes nothing (§0.5)', () async {
      final archive = await DataExporter(db).export(ownerId: ownerId);
      final freshOwner = await ensureDefaultOwner(fresh);

      final first = await DataImporter(fresh)
          .import(archive, asOwner: freshOwner);
      final countAfterFirst = await _countAll(fresh);

      final second = await DataImporter(fresh)
          .import(archive, asOwner: freshOwner);

      expect(second.succeeded, isTrue);
      expect(await _countAll(fresh), countAfterFirst);
      expect(
        second.totalInserted,
        0,
        reason: 'the second pass has nothing new to insert',
      );
      expect(first.totalInserted, greaterThan(0));
    });
  });

  group('merging into a device that has moved on', () {
    test('an older export does not undo newer local data', () async {
      // Export, then edit the entry locally so the device is ahead.
      final archive = await DataExporter(db).export(ownerId: ownerId);
      await db.customUpdate(
        'UPDATE food_log_entries SET grams_consumed = 240, updated_at = ? '
        "WHERE id = 'entry-1'",
        variables: [
          Variable<int>(DateTime(2026, 9, 10).millisecondsSinceEpoch ~/ 1000),
        ],
      );

      final report = await DataImporter(db).import(archive);

      expect(report.succeeded, isTrue);
      final entry = await db
          .customSelect("SELECT * FROM food_log_entries WHERE id = 'entry-1'")
          .getSingle();
      expect(
        entry.data['grams_consumed'],
        240.0,
        reason: 'the device held the newer row, so it keeps it',
      );
      expect(report.totalSkipped, greaterThan(0));
    });

    test('a newer export wins, and replaces the child rows with it', () async {
      // Edit on "the other device": a bigger portion and a different
      // nutrient snapshot, exported with a later updated_at.
      await db.customUpdate(
        'UPDATE food_log_entries SET grams_consumed = 300, updated_at = ? '
        "WHERE id = 'entry-1'",
        variables: [
          Variable<int>(DateTime(2026, 9, 20).millisecondsSinceEpoch ~/ 1000),
        ],
      );
      await db.customUpdate(
        "DELETE FROM log_entry_nutrients WHERE entry_id = 'entry-1'",
      );
      await db
          .into(db.logEntryNutrients)
          .insert(
            LogEntryNutrientsCompanion.insert(
              entryId: 'entry-1',
              nutrientId: 'energy',
              amount: 410,
            ),
          );
      final archive = await DataExporter(db).export(ownerId: ownerId);

      // Roll the local copy back to the older state.
      await db.customUpdate(
        'UPDATE food_log_entries SET grams_consumed = 180, updated_at = ? '
        "WHERE id = 'entry-1'",
        variables: [
          Variable<int>(DateTime(2026, 9, 9).millisecondsSinceEpoch ~/ 1000),
        ],
      );
      await db.customUpdate(
        "DELETE FROM log_entry_nutrients WHERE entry_id = 'entry-1'",
      );
      await db
          .into(db.logEntryNutrients)
          .insert(
            LogEntryNutrientsCompanion.insert(
              entryId: 'entry-1',
              nutrientId: 'protein',
              amount: 12.4,
            ),
          );

      final report = await DataImporter(db).import(archive);
      expect(report.succeeded, isTrue);

      final nutrients = await db
          .customSelect(
            "SELECT * FROM log_entry_nutrients WHERE entry_id = 'entry-1'",
          )
          .get();
      expect(
        nutrients.map((r) => r.data['nutrient_id']),
        ['energy'],
        reason:
            'the stale protein snapshot must not survive alongside the '
            'imported one',
      );
    });

    test('a deletion made elsewhere travels as a tombstone', () async {
      await db.customUpdate(
        'UPDATE food_log_entries SET deleted_at = ?, updated_at = ? '
        "WHERE id = 'entry-1'",
        variables: [
          Variable<int>(DateTime(2026, 9, 15).millisecondsSinceEpoch ~/ 1000),
          Variable<int>(DateTime(2026, 9, 15).millisecondsSinceEpoch ~/ 1000),
        ],
      );
      final archive = await DataExporter(db).export(ownerId: ownerId);

      // Undo the delete locally, with an older timestamp.
      await db.customUpdate(
        'UPDATE food_log_entries SET deleted_at = NULL, updated_at = ? '
        "WHERE id = 'entry-1'",
        variables: [
          Variable<int>(DateTime(2026, 9, 9).millisecondsSinceEpoch ~/ 1000),
        ],
      );

      await DataImporter(db).import(archive);
      final entry = await db
          .customSelect("SELECT * FROM food_log_entries WHERE id = 'entry-1'")
          .getSingle();
      expect(entry.data['deleted_at'], isA<int>());
    });

    test('imported days are marked stale so summaries recompute', () async {
      final summaryId = uuid.v7();
      await db
          .into(db.dailySummaries)
          .insert(
            DailySummariesCompanion.insert(
              id: summaryId,
              ownerId: ownerId,
              logDate: DateTime(2026, 9, 9),
              totalEnergyKcal: 0,
              entryCount: 0,
              loggedMealSlots: '[]',
              completenessFlag: 'complete',
              rulesetVersion: '2026.09',
              computedAt: DateTime(2026, 9, 9),
            ),
          );
      final archive = await DataExporter(db).export(ownerId: ownerId);
      final report = await DataImporter(db).import(archive);

      expect(report.daysAffected, 1);
      final summary = await db
          .customSelect(
            'SELECT is_stale FROM daily_summaries WHERE id = ?',
            variables: [Variable<String>(summaryId)],
          )
          .getSingle();
      expect(summary.data['is_stale'], 1);
    });

    test('derived rows are never written back in', () async {
      final archive = await DataExporter(db).export(ownerId: ownerId);
      // Put a summary in the archive that the database does not have.
      archive.tables['daily_summaries']!.add({
        'id': 'ghost-summary',
        'owner_id': ownerId,
        'log_date': '2026-09-09T00:00:00.000',
        'total_energy_kcal': 9999.0,
        'entry_count': 3,
        'logged_meal_slots': '[]',
        'completeness_flag': 'complete',
        'ruleset_version': '2026.09',
        'computed_at': '2026-09-09T00:00:00.000',
        'is_stale': false,
      });

      await DataImporter(db).import(archive);
      final ghost = await db
          .customSelect(
            "SELECT * FROM daily_summaries WHERE id = 'ghost-summary'",
          )
          .get();
      expect(
        ghost,
        isEmpty,
        reason: 'summaries are recomputed from entries, never trusted',
      );
    });
  });

  group('files this build cannot read', () {
    test(
      'a newer schema version is refused with a reason, not a crash',
      () async {
        final archive = await DataExporter(db).export(ownerId: ownerId);
        final future = DataImporter(db).import(
          ExportArchive(
            manifest: ExportManifest(
              schemaVersion: db.schemaVersion + 5,
              exportedAt: DateTime(2026, 9, 9),
              profileId: ownerId,
              profileName: 'You',
              counts: const {},
            ),
            tables: archive.tables,
          ),
        );
        await expectLater(
          future,
          throwsA(
            isA<ExportFormatException>().having(
              (e) => e.message,
              'message',
              contains('newer version'),
            ),
          ),
        );
      },
    );

    test('a file that is not an export is refused', () {
      expect(
        () => ExportArchive.fromJson({'hello': 'world'}),
        throwsA(isA<ExportFormatException>()),
      );
      expect(
        () => ExportArchive.fromJson({
          'manifest': {'format': 'something.else'},
          'tables': <String, Object?>{},
        }),
        throwsA(isA<ExportFormatException>()),
      );
    });

    test(
      'an unknown column is dropped rather than failing the import',
      () async {
        final archive = await DataExporter(db).export(ownerId: ownerId);
        for (final row in archive.tables['water_log_entries']!) {
          row['a_column_from_the_future'] = 'ignored';
        }
        await db.customUpdate('DELETE FROM water_log_entries');

        final report = await DataImporter(db).import(archive);
        expect(report.succeeded, isTrue);
        final water = await db
            .customSelect('SELECT * FROM water_log_entries')
            .get();
        expect(water, hasLength(1));
      },
    );
  });
}

Future<int> _countAll(NourishlyDatabase db) async {
  var total = 0;
  for (final table in exportedTables) {
    final rows = await db
        .customSelect('SELECT COUNT(*) AS c FROM ${table.name}')
        .getSingle();
    total += rows.data['c']! as int;
  }
  return total;
}
