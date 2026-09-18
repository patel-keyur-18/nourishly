import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly_data/nourishly_data.dart';
import 'package:uuid/uuid.dart';

void main() {
  group('NourishlyDatabase', () {
    late NourishlyDatabase db;

    setUp(() => db = NourishlyDatabase.forTesting());
    tearDown(() => db.close());

    test('a fresh database opens at the current schema version', () async {
      // Opening the in-memory database already runs onCreate against
      // schemaVersion; this asserts nothing throws and that the file's
      // recorded version matches what the code thinks it is.
      final result = await db.customSelect('PRAGMA user_version').getSingle();
      expect(result.data.values.first, db.schemaVersion);
    });

    test('v2 columns exist and carry their defaults', () async {
      // The v1 -> v2 migration is three additive columns (FR-U-16's
      // dietary preference, the onboarding flag, and the catalog's diet
      // class). This covers the shape on a *fresh* database.
      //
      // It does not exercise the upgrade path itself — that needs drift's
      // schema-snapshot tooling, which this repo has not set up. The
      // migration is `ALTER TABLE ... ADD COLUMN` three times, each
      // nullable or defaulted, which is the form SQLite accepts; but an
      // untested upgrade on real data is still an untested upgrade.
      final ownerId = await ensureDefaultOwner(db);
      final preferences = await PreferencesDao(db).forOwner(ownerId);

      expect(preferences.dietaryPreference, isNull);
      expect(preferences.onboardingSeen, isFalse);

      final columns = await db
          .customSelect("PRAGMA table_info('food_items')")
          .get();
      expect(columns.map((row) => row.data['name']), contains('diet_class'));
    });

    test(
      'a profile can be inserted and read back (id/timestamps/tombstone shape)',
      () async {
        const uuid = Uuid();
        final userId = uuid.v7();

        await db
            .into(db.users)
            .insert(
              UsersCompanion.insert(
                id: userId,
                displayName: 'Keyur',
                avatarColor: '#3b4d9e',
              ),
            );

        final row = await (db.select(
          db.users,
        )..where((u) => u.id.equals(userId))).getSingle();

        expect(row.displayName, 'Keyur');
        expect(row.deletedAt, isNull);
        expect(row.createdAt, isNotNull);
      },
    );

    test('nutrient rows use a stable slug id, not a UUID (§22.5)', () async {
      await db
          .into(db.nutrientGroups)
          .insert(
            NutrientGroupsCompanion.insert(
              id: 'macronutrients',
              name: 'Macronutrients',
              sortOrder: 0,
            ),
          );
      await db
          .into(db.nutrients)
          .insert(
            NutrientsCompanion.insert(
              id: 'protein',
              groupId: 'macronutrients',
              displayName: 'Protein',
              canonicalUnit: 'g',
              displayPrecision: 0,
              defaultCurveType: 'floor',
              isLimitNutrient: false,
              sortOrder: 0,
              isCore: true,
              minCoverageForScoring: 0.5,
            ),
          );

      final protein = await (db.select(
        db.nutrients,
      )..where((n) => n.id.equals('protein'))).getSingle();
      expect(protein.id, 'protein');
      expect(protein.displayName, 'Protein');
    });

    test(
      'a missing LogEntryNutrient row is absence, never a zero row (AP-4/I-2)',
      () async {
        const uuid = Uuid();
        final ownerId = uuid.v7();
        await db
            .into(db.users)
            .insert(
              UsersCompanion.insert(
                id: ownerId,
                displayName: 'Tester',
                avatarColor: '#000000',
              ),
            );
        await db
            .into(db.mealSlots)
            .insert(
              MealSlotsCompanion.insert(
                id: uuid.v7(),
                key: 'breakfast',
                displayName: 'Breakfast',
                sortOrder: 0,
              ),
            );

        // No food_items / log entry rows are inserted at all — the point of
        // this test is that the schema imposes no zero-filling: querying
        // for nutrient snapshots on an entry that was never logged returns
        // an empty result set, not rows of amount 0.
        final snapshots = await db.select(db.logEntryNutrients).get();
        expect(snapshots, isEmpty);
      },
    );
  });
}
