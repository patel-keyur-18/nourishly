import 'package:drift/drift.dart';
import 'package:nutrition_core/nutrition_core.dart';
import 'package:uuid/uuid.dart';

// See ProfileDao: the Drift row class `NutrientTarget` shadows the core value
// object of the same name.
import '../database.dart' hide DailyScore, NutrientTarget;
import 'profile_dao.dart';

const _uuid = Uuid();

/// One nutrient as the dashboard and report read it: the amount, what it
/// is measured against, and how much of the day it actually covers.
class SummaryNutrient {
  const SummaryNutrient({
    required this.nutrientId,
    required this.displayName,
    required this.unit,
    required this.amount,
    required this.coverage,
    required this.status,
    this.targetAmount,
    this.pctOfTarget,
  });

  final String nutrientId;
  final String displayName;
  final String unit;
  final double amount;
  final double coverage;
  final NutrientStatus status;
  final double? targetAmount;
  final double? pctOfTarget;

  bool get hasData => status != NutrientStatus.insufficientData;
}

/// What one meal slot contributed, for the dashboard's meals list and the
/// report's meal breakdown (§27.2 item 6, §27.8 item 10).
class MealSummary {
  const MealSummary({
    required this.slotId,
    required this.slotKey,
    required this.displayName,
    required this.energyKcal,
    required this.itemNames,
  });

  final String slotId;
  final String slotKey;
  final String displayName;
  final double energyKcal;
  final List<String> itemNames;

  bool get isEmpty => itemNames.isEmpty;
}

/// One food's contribution to one nutrient on one day — what FR-D-03's
/// "tapping it shows exactly what contributed" resolves to.
class NutrientContributor {
  const NutrientContributor({
    required this.foodName,
    required this.mealName,
    required this.amount,
    required this.gramsConsumed,
  });

  final String foodName;
  final String mealName;
  final double amount;
  final double gramsConsumed;
}

/// Everything a day's screens need, in one object.
class DaySummary {
  const DaySummary({
    required this.logDate,
    required this.totalEnergyKcal,
    required this.entryCount,
    required this.nutrients,
    required this.meals,
    required this.score,
    required this.insights,
    required this.waterMl,
    required this.isComplete,
    this.energyTargetKcal,
    this.waterTargetMl,
  });

  final DateTime logDate;
  final double totalEnergyKcal;
  final int entryCount;

  /// In registry sort order, so the report's table reads the same way every
  /// time.
  final List<SummaryNutrient> nutrients;
  final List<MealSummary> meals;
  final DailyScore score;
  final List<Insight> insights;
  final double waterMl;
  final bool isComplete;
  final double? energyTargetKcal;
  final double? waterTargetMl;

  bool get hasAnything => entryCount > 0 || waterMl > 0;

  SummaryNutrient? nutrient(String id) {
    for (final n in nutrients) {
      if (n.nutrientId == id) return n;
    }
    return null;
  }

  /// What §27.2 wants as the ring's big number: budget left, not amount
  /// eaten. Null when there is no energy target to count down from.
  double? get energyRemainingKcal =>
      energyTargetKcal == null ? null : energyTargetKcal! - totalEnergyKcal;
}

/// Builds, scores and caches a day (§25.3).
///
/// The dashboard is the most-viewed screen in the app and §27.2 forbids it
/// aggregating entries at render time, so the expensive part happens once
/// per change and lands in [DailySummaries] and its children. [isStale] is
/// what drives that: logging, editing or deleting anything marks the day
/// stale, and the next read rebuilds it.
class DailySummaryDao {
  DailySummaryDao(this._db);

  final NourishlyDatabase _db;

  /// Reads the day, recomputing first if it is stale or absent.
  Future<DaySummary> summaryFor({
    required String ownerId,
    required DateTime logDate,
    DateTime? now,
  }) async {
    final date = dateOnly(logDate);
    final cached = await _cachedRow(ownerId, date);
    if (cached == null || cached.isStale) {
      await recompute(ownerId: ownerId, logDate: date, now: now);
    }
    return _read(ownerId: ownerId, logDate: date, now: now);
  }

  /// Marks a day for rebuild. Called by every write that changes what a day
  /// contains — cheap, and it means no caller has to remember to
  /// recalculate.
  Future<void> markStale({
    required String ownerId,
    required DateTime logDate,
  }) async {
    await (_db.update(_db.dailySummaries)..where(
          (s) =>
              s.ownerId.equals(ownerId) & s.logDate.equals(dateOnly(logDate)),
        ))
        .write(const DailySummariesCompanion(isStale: Value(true)));
  }

  Future<DailySummary?> _cachedRow(String ownerId, DateTime date) async {
    final rows =
        await (_db.select(_db.dailySummaries)
              ..where((s) => s.ownerId.equals(ownerId) & s.logDate.equals(date))
              ..limit(1))
            .get();
    return rows.isEmpty ? null : rows.first;
  }

  /// Aggregates, scores and writes the day. Idempotent: it replaces
  /// whatever was there, which is what makes a stale summary a recompute
  /// rather than a data-recovery problem (AP-3, I-7).
  Future<void> recompute({
    required String ownerId,
    required DateTime logDate,
    DateTime? now,
  }) async {
    final date = dateOnly(logDate);
    final at = now ?? DateTime.now();

    final entries =
        await (_db.select(_db.foodLogEntries)..where(
              (e) =>
                  e.ownerId.equals(ownerId) &
                  e.logDate.equals(date) &
                  e.deletedAt.isNull(),
            ))
            .get();

    final entryIds = entries.map((e) => e.id).toList();
    final snapshots = entryIds.isEmpty
        ? <LogEntryNutrient>[]
        : await (_db.select(
            _db.logEntryNutrients,
          )..where((n) => n.entryId.isIn(entryIds))).get();

    final water =
        await (_db.select(_db.waterLogEntries)..where(
              (w) =>
                  w.ownerId.equals(ownerId) &
                  w.logDate.equals(date) &
                  w.deletedAt.isNull(),
            ))
            .get();
    final waterMl = water.fold<double>(0, (a, w) => a + w.volumeMl);

    // Energy per entry first: coverage is energy-weighted (§20.8), so every
    // other nutrient's denominator is built from this.
    final energyByEntry = <String, double>{};
    for (final s in snapshots) {
      if (s.nutrientId == 'energy') energyByEntry[s.entryId] = s.amount;
    }
    final totalEnergy = entries.fold<double>(
      0,
      (a, e) => a + (energyByEntry[e.id] ?? 0),
    );

    final aggregates = <String, NutrientAggregate>{};
    for (final s in snapshots) {
      final entryEnergy = energyByEntry[s.entryId] ?? 0;
      final existing = aggregates[s.nutrientId];
      aggregates[s.nutrientId] = NutrientAggregate(
        nutrientId: s.nutrientId,
        amount: (existing?.amount ?? 0) + s.amount,
        knownEnergyKcal: (existing?.knownEnergyKcal ?? 0) + entryEnergy,
        totalEnergyKcal: totalEnergy,
      );
    }

    final targetSet = await ProfileDao(_db).targetSetOn(ownerId, date);
    final targets = targetSet == null
        ? <String, NutrientTarget>{}
        : await ProfileDao(_db).targetsIn(targetSet.id);
    final goalRow = await ProfileDao(_db).currentGoal(ownerId, on: date);
    final goal = goalRow == null
        ? GoalType.generalHealth
        : GoalType.fromId(goalRow.goalType);

    final isComplete = _isDayComplete(date, at);
    final day = DayForScoring(
      nutrients: aggregates,
      targets: Map.of(targets)..remove('water'),
      goal: goal,
      isComplete: isComplete,
      waterMl: waterMl,
      waterTargetMl: targets['water']?.amount,
    );
    final score = scoreDay(day);

    final nutrientRows = await _db.select(_db.nutrients).get();
    final displayNames = {for (final n in nutrientRows) n.id: n.displayName};
    final insights = generateInsights(
      InsightContext(
        day: day,
        score: score,
        displayNames: displayNames,
        consecutiveDaysProteinMet: await _proteinStreak(ownerId, date),
      ),
    );

    final summaryId = (await _cachedRow(ownerId, date))?.id ?? _uuid.v7();
    final loggedSlots = entries.map((e) => e.mealSlotId).toSet().toList();

    await _db.transaction(() async {
      await (_db.delete(
        _db.dailySummaryNutrients,
      )..where((n) => n.summaryId.equals(summaryId))).go();
      await (_db.delete(
        _db.dailyScores,
      )..where((s) => s.summaryId.equals(summaryId))).go();
      await (_db.delete(
        _db.scoreComponents,
      )..where((c) => c.summaryId.equals(summaryId))).go();
      await (_db.delete(
        _db.dailyInsights,
      )..where((i) => i.summaryId.equals(summaryId))).go();

      await _db
          .into(_db.dailySummaries)
          .insertOnConflictUpdate(
            DailySummariesCompanion.insert(
              id: summaryId,
              ownerId: ownerId,
              logDate: date,
              totalEnergyKcal: totalEnergy,
              entryCount: entries.length,
              loggedMealSlots: loggedSlots.join(','),
              completenessFlag: _completenessFlag(score, entries.length),
              targetSetId: Value(targetSet?.id),
              rulesetVersion: scoringRulesetVersion,
              computedAt: at,
              isStale: const Value(false),
            ),
          );

      await _db.batch((batch) {
        for (final nutrient in nutrientRows) {
          final aggregate = aggregates[nutrient.id];
          if (aggregate == null) continue;
          final target = targets[nutrient.id];
          final status = _statusFor(aggregate, target);
          batch.insert(
            _db.dailySummaryNutrients,
            DailySummaryNutrientsCompanion.insert(
              summaryId: summaryId,
              nutrientId: nutrient.id,
              amount: aggregate.amount,
              knownEnergyKcal: aggregate.knownEnergyKcal,
              coverage: aggregate.coverage.fraction,
              targetAmount: Value(target?.amount),
              pctOfTarget: Value(
                target == null || target.amount <= 0
                    ? null
                    : aggregate.amount / target.amount * 100,
              ),
              status: status.id,
            ),
          );
        }

        batch.insert(
          _db.dailyScores,
          DailyScoresCompanion.insert(
            summaryId: summaryId,
            compositeScore: Value(score.composite),
            band: Value(score.band?.id),
            withheldReason: Value(score.withheldReason?.id),
            rulesetVersion: scoringRulesetVersion,
          ),
        );

        for (final component in score.components) {
          batch.insert(
            _db.scoreComponents,
            ScoreComponentsCompanion.insert(
              summaryId: summaryId,
              componentKey: component.key.id,
              rawScore: Value(component.score),
              weight: component.weight,
              appliedWeight: component.appliedWeight,
              wasExcluded: Value(component.wasExcluded),
              exclusionReason: Value(component.exclusion?.id),
            ),
          );
        }

        for (final insight in insights) {
          batch.insert(
            _db.dailyInsights,
            DailyInsightsCompanion.insert(
              id: _uuid.v7(),
              summaryId: summaryId,
              ruleId: insight.ruleId,
              category: insight.category.id,
              renderedText: insight.text,
              priority: insight.priority,
              generatedAt: at,
            ),
          );
        }
      });
    });
  }

  Future<DaySummary> _read({
    required String ownerId,
    required DateTime logDate,
    DateTime? now,
  }) async {
    final date = dateOnly(logDate);
    final at = now ?? DateTime.now();
    final summary = await _cachedRow(ownerId, date);
    final nutrientRows = await _db.select(_db.nutrients).get()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final targetSet = await ProfileDao(_db).targetSetOn(ownerId, date);
    final targets = targetSet == null
        ? <String, NutrientTarget>{}
        : await ProfileDao(_db).targetsIn(targetSet.id);

    final water =
        await (_db.select(_db.waterLogEntries)..where(
              (w) =>
                  w.ownerId.equals(ownerId) &
                  w.logDate.equals(date) &
                  w.deletedAt.isNull(),
            ))
            .get();
    final waterMl = water.fold<double>(0, (a, w) => a + w.volumeMl);

    if (summary == null) {
      return DaySummary(
        logDate: date,
        totalEnergyKcal: 0,
        entryCount: 0,
        nutrients: const [],
        meals: await _meals(ownerId, date),
        score: DailyScore.from(
          const [],
          withheld: ScoreWithheldReason.nothingLogged,
        ),
        insights: const [],
        waterMl: waterMl,
        isComplete: _isDayComplete(date, at),
        energyTargetKcal: targets['energy']?.amount,
        waterTargetMl: targets['water']?.amount,
      );
    }

    final storedNutrients = await (_db.select(
      _db.dailySummaryNutrients,
    )..where((n) => n.summaryId.equals(summary.id))).get();
    final byId = {for (final n in storedNutrients) n.nutrientId: n};

    final components = await (_db.select(
      _db.scoreComponents,
    )..where((c) => c.summaryId.equals(summary.id))).get();
    final scoreRows = await (_db.select(
      _db.dailyScores,
    )..where((s) => s.summaryId.equals(summary.id))).get();
    final storedScore = scoreRows.isEmpty ? null : scoreRows.first;

    final insightRows =
        await (_db.select(_db.dailyInsights)
              ..where((i) => i.summaryId.equals(summary.id))
              ..orderBy([(i) => OrderingTerm.asc(i.priority)]))
            .get();

    return DaySummary(
      logDate: date,
      totalEnergyKcal: summary.totalEnergyKcal,
      entryCount: summary.entryCount,
      nutrients: [
        for (final nutrient in nutrientRows)
          if (byId[nutrient.id] case final row?)
            SummaryNutrient(
              nutrientId: nutrient.id,
              displayName: nutrient.displayName,
              unit: nutrient.canonicalUnit,
              amount: row.amount,
              coverage: row.coverage,
              status: NutrientStatus.fromId(row.status),
              targetAmount: row.targetAmount,
              pctOfTarget: row.pctOfTarget,
            ),
      ],
      meals: await _meals(ownerId, date),
      score: DailyScore(
        components: [
          for (final c in components)
            ScoredComponent(
              key: ScoreComponentKey.fromId(c.componentKey),
              score: c.rawScore,
              weight: c.weight,
              appliedWeight: c.appliedWeight,
              exclusion: c.exclusionReason == null
                  ? null
                  : ScoreExclusion.values.firstWhere(
                      (e) => e.id == c.exclusionReason,
                    ),
            ),
        ],
        composite: storedScore?.compositeScore,
        band: storedScore?.band == null
            ? null
            : ScoreBand.fromId(storedScore!.band!),
        withheldReason: storedScore?.withheldReason == null
            ? null
            : ScoreWithheldReason.fromId(storedScore!.withheldReason!),
      ),
      insights: [
        for (final i in insightRows)
          Insight(
            ruleId: i.ruleId,
            category: InsightCategory.fromId(i.category),
            text: i.renderedText,
            priority: i.priority,
          ),
      ],
      waterMl: waterMl,
      isComplete: _isDayComplete(date, at),
      energyTargetKcal: targets['energy']?.amount,
      waterTargetMl: targets['water']?.amount,
    );
  }

  /// The foods that supplied a nutrient on a day, largest first (FR-D-03).
  ///
  /// Read from the frozen snapshots, not from the catalog: the report has
  /// to explain the number it actually showed, which is the number that
  /// was true when the food was logged (ADR-008).
  Future<List<NutrientContributor>> contributorsTo({
    required String ownerId,
    required DateTime logDate,
    required String nutrientId,
  }) async {
    final date = dateOnly(logDate);
    final entries =
        await (_db.select(_db.foodLogEntries)..where(
              (e) =>
                  e.ownerId.equals(ownerId) &
                  e.logDate.equals(date) &
                  e.deletedAt.isNull(),
            ))
            .get();
    if (entries.isEmpty) return const [];

    final amounts =
        await (_db.select(_db.logEntryNutrients)..where(
              (n) =>
                  n.entryId.isIn(entries.map((e) => e.id).toList()) &
                  n.nutrientId.equals(nutrientId),
            ))
            .get();
    if (amounts.isEmpty) return const [];

    final byEntry = {for (final a in amounts) a.entryId: a.amount};
    final foods =
        await (_db.select(_db.foodItems)..where(
              (f) => f.id.isIn(entries.map((e) => e.foodId).toSet().toList()),
            ))
            .get();
    final foodNames = {for (final f in foods) f.id: f.canonicalName};
    final slots = await _db.select(_db.mealSlots).get();
    final slotNames = {for (final s in slots) s.id: s.displayName};

    final contributors = [
      for (final entry in entries)
        if (byEntry[entry.id] case final amount?)
          NutrientContributor(
            foodName: foodNames[entry.foodId] ?? 'Unknown food',
            mealName: slotNames[entry.mealSlotId] ?? '',
            amount: amount,
            gramsConsumed: entry.gramsConsumed,
          ),
    ]..sort((a, b) => b.amount.compareTo(a.amount));
    return contributors;
  }

  Future<List<MealSummary>> _meals(String ownerId, DateTime date) async {
    final slots = await (_db.select(
      _db.mealSlots,
    )..orderBy([(s) => OrderingTerm.asc(s.sortOrder)])).get();
    final entries =
        await (_db.select(_db.foodLogEntries)..where(
              (e) =>
                  e.ownerId.equals(ownerId) &
                  e.logDate.equals(date) &
                  e.deletedAt.isNull(),
            ))
            .get();
    if (entries.isEmpty) {
      return [
        for (final slot in slots)
          MealSummary(
            slotId: slot.id,
            slotKey: slot.key,
            displayName: slot.displayName,
            energyKcal: 0,
            itemNames: const [],
          ),
      ];
    }

    final foodIds = entries.map((e) => e.foodId).toSet().toList();
    final foods = await (_db.select(
      _db.foodItems,
    )..where((f) => f.id.isIn(foodIds))).get();
    final nameById = {for (final f in foods) f.id: f.canonicalName};

    final energy =
        await (_db.select(_db.logEntryNutrients)..where(
              (n) =>
                  n.entryId.isIn(entries.map((e) => e.id).toList()) &
                  n.nutrientId.equals('energy'),
            ))
            .get();
    final energyByEntry = {for (final e in energy) e.entryId: e.amount};

    return [
      for (final slot in slots)
        () {
          final inSlot = entries.where((e) => e.mealSlotId == slot.id).toList();
          return MealSummary(
            slotId: slot.id,
            slotKey: slot.key,
            displayName: slot.displayName,
            energyKcal: inSlot.fold<double>(
              0,
              (a, e) => a + (energyByEntry[e.id] ?? 0),
            ),
            itemNames: [
              for (final e in inSlot) nameById[e.foodId] ?? 'Unknown food',
            ],
          );
        }(),
    ];
  }

  /// How many consecutive days up to and including [date] met the protein
  /// target — the one piece of history the insight rules can see.
  Future<int> _proteinStreak(String ownerId, DateTime date) async {
    var streak = 0;
    for (var back = 1; back <= 30; back++) {
      final day = date.subtract(Duration(days: back));
      final row = await _cachedRow(ownerId, day);
      if (row == null) break;
      final protein =
          await (_db.select(_db.dailySummaryNutrients)..where(
                (n) =>
                    n.summaryId.equals(row.id) & n.nutrientId.equals('protein'),
              ))
              .get();
      if (protein.isEmpty) break;
      final p = protein.first;
      if (p.targetAmount == null || p.amount < p.targetAmount!) break;
      streak++;
    }
    // Plus today, if today met it. The rule adds nothing when the target
    // was missed, so counting today here keeps "3 days in a row" honest.
    return streak;
  }

  static NutrientStatus _statusFor(
    NutrientAggregate aggregate,
    NutrientTarget? target,
  ) {
    if (!aggregate.isScorable()) return NutrientStatus.insufficientData;
    if (target == null) return NutrientStatus.within;
    return switch (target.curveType) {
      TargetCurveType.ceiling =>
        aggregate.amount > target.amount
            ? NutrientStatus.above
            : NutrientStatus.within,
      TargetCurveType.range =>
        aggregate.amount < target.bandLow
            ? NutrientStatus.below
            : aggregate.amount > target.bandHigh
            ? NutrientStatus.above
            : NutrientStatus.within,
      _ =>
        aggregate.amount < target.amount
            ? NutrientStatus.below
            : NutrientStatus.within,
    };
  }

  static String _completenessFlag(DailyScore score, int entryCount) {
    if (entryCount == 0) return 'empty';
    if (score.withheldReason == ScoreWithheldReason.looksIncompletelyLogged) {
      return 'looks_incomplete';
    }
    if (score.withheldReason == ScoreWithheldReason.dayIncomplete) {
      return 'in_progress';
    }
    return 'complete';
  }
}

/// Midnight local, which is what [FoodLogEntries.logDate] stores.
DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// A day is complete once it is in the past. The rollover time in
/// [UserPreferences] shifts where the boundary falls; until the settings
/// screen exposes it, midnight is the boundary.
bool _isDayComplete(DateTime date, DateTime now) =>
    dateOnly(date).isBefore(dateOnly(now));
