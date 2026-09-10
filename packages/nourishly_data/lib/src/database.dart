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
/// This is schema only for Phase 1 — no DAOs or repository
/// implementations yet (§12.3's `nourishly_data` package layout; the "Data"
/// layer in §13.3 arrives with the features that need it).
@DriftDatabase(
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
  NourishlyDatabase.forTesting() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;

  /// The bundled food catalog is excluded from platform backup (Android
  /// Auto Backup, iOS device backup) because it is large, identical on
  /// every device, and rebuildable from the app bundle — backing it up
  /// would blow Android's per-app quota for nothing (§0.5). User data
  /// lives in the same database file for now; splitting the catalog into
  /// its own file with its own backup-exclusion rule is a Phase 2/5
  /// concern once the platform channel work for that exists.
  static QueryExecutor _defaultExecutor() => driftDatabase(name: 'nourishly');
}
