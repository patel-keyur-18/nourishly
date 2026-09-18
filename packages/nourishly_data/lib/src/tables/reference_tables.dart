import 'package:drift/drift.dart';

/// Reference data (§22.5) is pipeline-owned and read-only on the device —
/// no `Owned`/`Timestamped`/`SoftDeletable` mixins. [Nutrients] and
/// [NutrientGroups] use their stable slug as the primary key directly
/// (e.g. `protein`), not a UUID — that slug is what every nutrient-bearing
/// table keys off (TO-3, §22.4), and it must stay constant across catalog
/// rebuilds.
class NutrientGroups extends Table {
  /// e.g. `macronutrients`, `vitamins`, `minerals`, `other`.
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get sortOrder => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// The registry that makes the nutrient model extensible (§22.4, AP-6).
/// Everything nutrient-related keys off this table.
class Nutrients extends Table {
  /// Stable slug, e.g. `protein`, `vitamin_b12`.
  TextColumn get id => text()();
  TextColumn get groupId =>
      text().customConstraint('NOT NULL REFERENCES nutrient_groups (id)')();
  TextColumn get displayName => text()();

  /// `kcal` | `g` | `mg` | `ug`.
  TextColumn get canonicalUnit => text()();
  IntColumn get displayPrecision => integer()();

  /// `range` | `floor` | `ceiling` | `plateau`.
  TextColumn get defaultCurveType => text()();
  BoolColumn get isLimitNutrient => boolean()();
  IntColumn get sortOrder => integer()();
  BoolColumn get isCore => boolean()();
  RealColumn get minCoverageForScoring => real()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Target derivation lookup, keyed by age × sex × lifestage × region — data,
/// not code (AP-6, §22.5).
class RdaReferences extends Table {
  TextColumn get id => text()();
  TextColumn get nutrientId =>
      text().customConstraint('NOT NULL REFERENCES nutrients (id)')();

  /// `IN` | `INTL`.
  TextColumn get region => text()();

  /// `male` | `female` | null for a sex-independent reference value.
  TextColumn get sex => text().nullable()();
  IntColumn get ageMin => integer()();
  IntColumn get ageMax => integer()();
  TextColumn get lifestage => text()();
  RealColumn get rdaAmount => real()();
  RealColumn get aiAmount => real().nullable()();
  RealColumn get upperLimit => real().nullable()();
  TextColumn get sourceCitation => text()();
  TextColumn get rulesetVersion => text()();

  @override
  Set<Column> get primaryKey => {id};
}
