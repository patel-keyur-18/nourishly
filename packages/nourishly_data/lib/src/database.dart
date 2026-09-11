import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables/catalog_tables.dart';
import 'tables/derived_tables.dart';
import 'tables/identity_tables.dart';
import 'tables/logging_tables.dart';
import 'tables/reference_tables.dart';
import 'tables/reminder_tables.dart';

part 'database.g.dart';

/// Nourishly's on-device source of truth (ADR-003, ADR-004, §13.1 AP-1).
///
/// Schema v1 (§22): every table here, minus the sync machinery dropped by
/// the personal-use scope (§0.4) — no `OutboxRecord`, `SyncState`, or
/// `Device` table, and no `sync_state`/`server_revision`/`device_id`
/// columns. UUIDv7 primary keys, `created_at`/`updated_at`, and
/// `deleted_at` tombstones are kept, because export/import merge-by-id
/// (§0.5) needs them regardless of whether a server exists.
///
/// Phase 2 adds the first DAO ([FoodSearchDao], `dao/food_search_dao.dart`)
/// over the `food_search_index` FTS5 table declared in
/// `tables/search.drift` (§22.7, NFR-P-03).
@DriftDatabase(
  include: {'tables/search.drift'},
  tables: [
    // Identity & Personalisation
    Users,
    UserProfileVersions,
    Goals,
    TargetSets,
    NutrientTargets,
    UserPreferences,
    BodyWeightEntries,
    // Reference Data
    NutrientGroups,
    Nutrients,
    RdaReferences,
    // Food Catalog
    FoodItems,
    FoodNutrientValues,
    ServingSizes,
    FoodAltNames,
    FoodExternalRefs,
    CatalogVersions,
    RecipeComponents,
    // Logging
    MealSlots,
    FoodLogEntries,
    LogEntryNutrients,
    WaterLogEntries,
    MealTemplates,
    MealTemplateItems,
    FavoriteFoods,
    // Derived (rebuildable, never synced)
    DailySummaries,
    DailySummaryNutrients,
    DailyScores,
    ScoreComponents,
    DailyInsights,
    // Reminders
    ReminderRules,
  ],
)
class NourishlyDatabase extends _$NourishlyDatabase {
  NourishlyDatabase([QueryExecutor? executor])
    : super(executor ?? _defaultExecutor());

  /// In-memory database for tests. Nothing touches disk.
  ///
  /// `closeStreamsSynchronously: true` per drift's own guidance: without
  /// it, cancelling a `.watch()` stream schedules a cleanup `Timer` that
  /// `flutter_test`'s strict pending-timer check flags as a leak, and
  /// tests that watch reactive queries (§14.5) hit this immediately.
  NourishlyDatabase.forTesting()
    : super(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      );

  @override
  int get schemaVersion => 3;

  /// v1 -> v2 adds FR-U-16's dietary preference (plus the one-time
  /// onboarding flag) and the diet class the catalog importer computes.
  /// Additive columns only, so there is nothing to move: existing rows get
  /// the defaults, and `dietClass` is filled in the next time the catalog
  /// importer runs, which is every launch.
  ///
  /// v2 -> v3 changes the default appearance from `system` to `light`.
  /// Rows still holding `system` are rewritten rather than left alone:
  /// nothing has ever been able to set this column, so every stored value
  /// is an untouched default and no one's choice is being overwritten.
  /// Once §27.13's appearance setting exists, a stored `system` will mean
  /// somebody asked for it and this migration will be long past.
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(userPreferences, userPreferences.dietaryPreference);
        await m.addColumn(userPreferences, userPreferences.onboardingSeen);
        await m.addColumn(foodItems, foodItems.dietClass);
      }
      if (from < 3) {
        await (update(userPreferences)..where((p) => p.theme.equals('system')))
            .write(const UserPreferencesCompanion(theme: Value('light')));
      }
    },
  );

  /// The bundled food catalog is excluded from platform backup (Android
  /// Auto Backup, iOS device backup) because it is large, identical on
  /// every device, and rebuildable from the app bundle — backing it up
  /// would blow Android's per-app quota for nothing (§0.5). User data
  /// lives in the same database file for now; splitting the catalog into
  /// its own file with its own backup-exclusion rule is a Phase 2/5
  /// concern once the platform channel work for that exists.
  static QueryExecutor _defaultExecutor() => driftDatabase(name: 'nourishly');
}
