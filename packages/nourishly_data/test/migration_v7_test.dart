import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly_data/nourishly_data.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// v6 -> v7 adds `food_log_entries.status` and
/// `user_profile_versions.due_date`.
///
/// Both are additive with a safe default, but "nothing to backfill" is the
/// kind of claim that is only worth anything once it has been run against
/// a database that already holds someone's food log. The specific risk
/// here is worse than a missing column: if an entry written before the
/// upgrade came back as anything other than `logged`, a year of somebody's
/// history would silently drop out of every total.
///
/// v6 is simulated by dropping the two columns from a fresh database,
/// which is the shape a device upgrading from the previous release is in.
void main() {
  late NourishlyDatabase db;

  setUp(() => db = NourishlyDatabase.forTesting());
  tearDown(() => db.close());

  Future<void> downgradeToV6() async {
    await db.customStatement('ALTER TABLE food_log_entries DROP COLUMN status');
    await db.customStatement(
      'ALTER TABLE user_profile_versions DROP COLUMN due_date',
    );
  }

  Future<String> insertEntry() async {
    final ownerId = await ensureDefaultOwner(db);
    await db
        .into(db.foodItems)
        .insert(
          FoodItemsCompanion.insert(
            id: 'food-khichdi',
            kind: 'recipe',
            canonicalName: 'Khichdi',
            qualityTier: 'derived',
            provenanceSource: 'catalog_pipeline_recipe',
          ),
        );
    await db
        .into(db.mealSlots)
        .insert(
          MealSlotsCompanion.insert(
            id: 'slot-dinner',
            key: 'dinner',
            displayName: 'Dinner',
            sortOrder: 2,
          ),
        );
    final id = _uuid.v7();
    await db.customStatement(
      'INSERT INTO food_log_entries (id, owner_id, log_date, meal_slot_id, '
      'food_id, food_revision, quantity, grams_consumed, logged_at, source, '
      'updated_at) '
      'VALUES (?, ?, ?, ?, ?, 1, 1, 200, ?, ?, ?)',
      [
        id,
        ownerId,
        DateTime(2026, 9, 1).millisecondsSinceEpoch ~/ 1000,
        'slot-dinner',
        'food-khichdi',
        DateTime(2026, 9, 1, 20).millisecondsSinceEpoch ~/ 1000,
        'manual',
        DateTime(2026, 9, 1, 20).millisecondsSinceEpoch ~/ 1000,
      ],
    );
    return id;
  }

  test('the database reports the new schema version', () {
    expect(db.schemaVersion, 7);
  });

  test('an entry written before the upgrade still counts as eaten', () async {
    await downgradeToV6();
    final entryId = await insertEntry();

    await db.migration.onUpgrade(Migrator(db), 6, 7);

    final row = await (db.select(
      db.foodLogEntries,
    )..where((e) => e.id.equals(entryId))).getSingle();
    expect(
      row.status,
      logStatusLogged,
      reason:
          'every entry written before the planner existed is a record '
          'of a meal, not of an intention',
    );
  });

  test('a profile written before the upgrade has no due date', () async {
    await downgradeToV6();
    final ownerId = await ensureDefaultOwner(db);
    final profileId = _uuid.v7();
    await db.customStatement(
      'INSERT INTO user_profile_versions (id, owner_id, effective_from, '
      'date_of_birth, height_cm, weight_kg, activity_level, lifestage, '
      'region_ref, source, created_at, updated_at) '
      "VALUES (?, ?, ?, ?, 165, 60, 'light', 'adult', 'IN', 'user', ?, ?)",
      [
        profileId,
        ownerId,
        DateTime(2026, 1, 1).millisecondsSinceEpoch ~/ 1000,
        DateTime(1994, 5, 2).millisecondsSinceEpoch ~/ 1000,
        DateTime(2026, 1, 1).millisecondsSinceEpoch ~/ 1000,
        DateTime(2026, 1, 1).millisecondsSinceEpoch ~/ 1000,
      ],
    );

    await db.migration.onUpgrade(Migrator(db), 6, 7);

    final row = await (db.select(
      db.userProfileVersions,
    )..where((p) => p.id.equals(profileId))).getSingle();
    expect(row.dueDate, isNull);
    expect(row.lifestage, 'adult');
  });
}
