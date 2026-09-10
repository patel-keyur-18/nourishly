import 'package:drift/drift.dart';

import 'common.dart';

/// Derived (rebuildable, never synced — §15.3, §22.5). Every row here is
/// reproducible from entries + targets + ruleset (I-7); `isStale` and
/// `rulesetVersion` drive lazy recomputation (§25.7). A corrupted or stale
/// aggregate is a recompute, never a data-recovery incident (AP-3).
class DailySummaries extends Table with Identifiable, Owned {
  DateTimeColumn get logDate => dateTime()();
  RealColumn get totalEnergyKcal => real()();
  IntColumn get entryCount => integer()();

  /// JSON-encoded list of meal slot ids logged that day.
  TextColumn get loggedMealSlots => text()();
  TextColumn get completenessFlag => text()();
  TextColumn get targetSetId =>
      text().nullable().customConstraint('REFERENCES target_sets (id)')();
  TextColumn get rulesetVersion => text()();
  DateTimeColumn get computedAt => dateTime()();
  BoolColumn get isStale => boolean().withDefault(const Constant(false))();
}

class DailySummaryNutrients extends Table {
  TextColumn get summaryId =>
      text().customConstraint('NOT NULL REFERENCES daily_summaries (id)')();
  TextColumn get nutrientId =>
      text().customConstraint('NOT NULL REFERENCES nutrients (id)')();

  /// Sum of KNOWN values only — never zero-filled for unknowns (AP-4).
  RealColumn get amount => real()();
  RealColumn get knownEnergyKcal => real()();
  RealColumn get coverage => real()();
  RealColumn get targetAmount => real().nullable()();
  RealColumn get pctOfTarget => real().nullable()();

  /// `below` | `within` | `above` | `insufficient_data`.
  TextColumn get status => text()();

  @override
  Set<Column> get primaryKey => {summaryId, nutrientId};
}

class DailyScores extends Table {
  TextColumn get summaryId =>
      text().customConstraint('NOT NULL REFERENCES daily_summaries (id)')();
  RealColumn get compositeScore => real().nullable()();
  TextColumn get band => text().nullable()();
  TextColumn get withheldReason => text().nullable()();
  TextColumn get rulesetVersion => text()();

  @override
  Set<Column> get primaryKey => {summaryId};
}

class ScoreComponents extends Table {
  TextColumn get summaryId =>
      text().customConstraint('NOT NULL REFERENCES daily_summaries (id)')();
  TextColumn get componentKey => text()();
  RealColumn get rawScore => real().nullable()();
  RealColumn get weight => real()();
  RealColumn get appliedWeight => real()();
  BoolColumn get wasExcluded => boolean().withDefault(const Constant(false))();
  TextColumn get exclusionReason => text().nullable()();

  @override
  Set<Column> get primaryKey => {summaryId, componentKey};
}

/// Persisted so the daily report is stable rather than regenerating
/// differently on each view (§22.5).
class DailyInsights extends Table with Identifiable {
  TextColumn get summaryId =>
      text().customConstraint('NOT NULL REFERENCES daily_summaries (id)')();
  TextColumn get ruleId => text()();
  TextColumn get category => text()();
  TextColumn get renderedText => text()();
  IntColumn get priority => integer()();
  DateTimeColumn get generatedAt => dateTime()();
}
