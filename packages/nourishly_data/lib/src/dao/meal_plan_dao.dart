import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/logging_tables.dart';
import 'daily_summary_dao.dart';
import 'food_logging_dao.dart';
import 'log_status.dart';

/// Reads and writes over the planned half of the food log (FR-P-01…07).
///
/// Separate from [FoodLoggingDao] because the questions are different
/// shapes: that one writes and edits a single entry, this one reads a week
/// at a time and answers "if the plan holds, where does this day land?".
/// The write path is not duplicated — planning a food and filling a slot
/// from a template both go through [FoodLoggingDao.logFood] and
/// [MealTemplateDao.applyTemplate] with a `planned` status, so a planned
/// entry is built by exactly the code that builds a logged one.
class MealPlanDao {
  MealPlanDao(this._db);

  final NourishlyDatabase _db;

  /// Every planned, eaten or skipped entry in `[from, to]`, with the food
  /// and slot names joined in — one query for the whole week rather than
  /// one per day (NFR-P-05's reason for the `(owner_id, log_date)` index).
  Stream<List<PlannedFood>> watchRange({
    required String ownerId,
    required DateTime from,
    required DateTime to,
  }) {
    final start = dateOnly(from);
    final end = dateOnly(to);
    final query =
        _db.select(_db.foodLogEntries).join([
            innerJoin(
              _db.foodItems,
              _db.foodItems.id.equalsExp(_db.foodLogEntries.foodId),
            ),
            innerJoin(
              _db.mealSlots,
              _db.mealSlots.id.equalsExp(_db.foodLogEntries.mealSlotId),
            ),
            leftOuterJoin(
              _db.servingSizes,
              _db.servingSizes.id.equalsExp(_db.foodLogEntries.servingSizeId),
            ),
            // I-2 again: a food with no energy value has no row here, and
            // the outer join is what keeps that "unknown" rather than
            // collapsing it to 0 kcal.
            leftOuterJoin(
              _db.logEntryNutrients,
              _db.logEntryNutrients.entryId.equalsExp(_db.foodLogEntries.id) &
                  _db.logEntryNutrients.nutrientId.equals('energy'),
            ),
          ])
          ..where(
            _db.foodLogEntries.ownerId.equals(ownerId) &
                _db.foodLogEntries.logDate.isBiggerOrEqualValue(start) &
                _db.foodLogEntries.logDate.isSmallerOrEqualValue(end) &
                _db.foodLogEntries.deletedAt.isNull(),
          )
          ..orderBy([
            OrderingTerm.asc(_db.foodLogEntries.logDate),
            OrderingTerm.asc(_db.mealSlots.sortOrder),
            OrderingTerm.asc(_db.foodLogEntries.loggedAt),
          ]);

    return query.watch().map(
      (rows) => [
        for (final row in rows)
          PlannedFood(
            entry: row.readTable(_db.foodLogEntries),
            foodName: row.readTable(_db.foodItems).canonicalName,
            mealSlotId: row.readTable(_db.mealSlots).id,
            mealSlotName: row.readTable(_db.mealSlots).displayName,
            servingLabel: row.readTableOrNull(_db.servingSizes)?.label,
            energyKcal: row.readTableOrNull(_db.logEntryNutrients)?.amount,
          ),
      ],
    );
  }

  /// Copies a week forward as a plan (FR-P-02) — the one-tap start that
  /// makes a 28-slot week a realistic thing to fill in.
  ///
  /// Everything that was eaten *or* planned in the source week is copied;
  /// a skipped entry is not, because it is a record of a plan that did not
  /// work. Entries are rebuilt through [FoodLoggingDao.logFood], so each
  /// copy takes a fresh snapshot from the catalog as it is today rather
  /// than inheriting a snapshot frozen last week. That is the right way
  /// round: the copy is a new intention about the future, not a claim
  /// about the past, and ADR-008 protects the past, not the plan.
  ///
  /// Refuses to write into a day that already has something on it, per
  /// [onConflict]. "Something" is any entry that is not skipped — eaten
  /// as well as planned. A day you have already eaten is not an empty day,
  /// and copying a plan over Monday on a Thursday would put meals you did
  /// not eat next to the ones you did.
  ///
  /// Returns how many entries were written.
  Future<int> copyWeek({
    required String ownerId,
    required DateTime fromWeekStart,
    required DateTime toWeekStart,
    CopyWeekConflict onConflict = CopyWeekConflict.skipDay,
  }) async {
    final sourceStart = dateOnly(fromWeekStart);
    final targetStart = dateOnly(toWeekStart);
    final shift = targetStart.difference(sourceStart).inDays;
    if (shift == 0) return 0;

    final source =
        await (_db.select(_db.foodLogEntries)..where(
              (e) =>
                  e.ownerId.equals(ownerId) &
                  e.logDate.isBiggerOrEqualValue(sourceStart) &
                  e.logDate.isSmallerOrEqualValue(
                    sourceStart.add(const Duration(days: 6)),
                  ) &
                  isProjected(e),
            ))
            .get();
    if (source.isEmpty) return 0;

    final existing = await daysWithEntries(
      ownerId: ownerId,
      from: targetStart,
      to: targetStart.add(const Duration(days: 6)),
    );

    final logging = FoodLoggingDao(_db);
    var written = 0;
    for (final entry in source) {
      final targetDate = dateOnly(entry.logDate).add(Duration(days: shift));
      if (onConflict == CopyWeekConflict.skipDay &&
          existing.contains(targetDate)) {
        continue;
      }
      final servingId = entry.servingSizeId;
      // No serving recorded means no portion this copy could honestly
      // restate, so it is left out rather than guessed at (AP-4).
      if (servingId == null) continue;
      await logging.logFood(
        ownerId: ownerId,
        foodId: entry.foodId,
        servingId: servingId,
        quantity: entry.quantity,
        mealSlotId: entry.mealSlotId,
        logDate: targetDate,
        status: logStatusPlanned,
        source: 'copy',
      );
      written++;
    }
    return written;
  }

  /// The dates in `[from, to]` that already hold at least one entry that
  /// is not skipped — eaten or planned.
  ///
  /// This is what "this day already has something on it" means to
  /// [copyWeek]. Deliberately not "has a plan": a day whose meals were
  /// eaten is the *most* finished a day can be, and it would read as empty
  /// to a check that only looked for planned rows.
  Future<Set<DateTime>> daysWithEntries({
    required String ownerId,
    required DateTime from,
    required DateTime to,
  }) async {
    final rows =
        await (_db.selectOnly(_db.foodLogEntries, distinct: true)
              ..addColumns([_db.foodLogEntries.logDate])
              ..where(
                _db.foodLogEntries.ownerId.equals(ownerId) &
                    _db.foodLogEntries.logDate.isBiggerOrEqualValue(
                      dateOnly(from),
                    ) &
                    _db.foodLogEntries.logDate.isSmallerOrEqualValue(
                      dateOnly(to),
                    ) &
                    isProjected(_db.foodLogEntries),
              ))
            .get();
    return {
      for (final row in rows) dateOnly(row.read(_db.foodLogEntries.logDate)!),
    };
  }

  /// What a day comes to if the plan holds: the eaten total, the planned
  /// total, and their sum, per nutrient (FR-P-06).
  ///
  /// Deliberately not materialised into [DailySummaries]. That table is
  /// the record of days that happened; a forecast in it would be a number
  /// nobody ate sitting in the same place as numbers they did. This is a
  /// screen-time read over at most a week, which is cheap enough that the
  /// honest shape is also the easy one.
  Future<Map<String, ProjectedNutrient>> projectionFor({
    required String ownerId,
    required DateTime logDate,
  }) async {
    final date = dateOnly(logDate);
    final entries =
        await (_db.select(_db.foodLogEntries)..where(
              (e) =>
                  e.ownerId.equals(ownerId) &
                  e.logDate.equals(date) &
                  isProjected(e),
            ))
            .get();
    if (entries.isEmpty) return const {};

    final plannedIds = {
      for (final e in entries)
        if (e.status == logStatusPlanned) e.id,
    };
    final amounts = await (_db.select(
      _db.logEntryNutrients,
    )..where((n) => n.entryId.isIn([for (final e in entries) e.id]))).get();

    final projected = <String, ProjectedNutrient>{};
    for (final row in amounts) {
      final current =
          projected[row.nutrientId] ??
          ProjectedNutrient(nutrientId: row.nutrientId, eaten: 0, planned: 0);
      projected[row.nutrientId] = plannedIds.contains(row.entryId)
          ? current.addPlanned(row.amount)
          : current.addEaten(row.amount);
    }
    return projected;
  }

  /// [projectionFor], for every day of a week, keyed by date.
  Future<Map<DateTime, Map<String, ProjectedNutrient>>> projectionForWeek({
    required String ownerId,
    required DateTime weekStart,
  }) async {
    final start = dateOnly(weekStart);
    return {
      for (var i = 0; i < 7; i++)
        start.add(Duration(days: i)): await projectionFor(
          ownerId: ownerId,
          logDate: start.add(Duration(days: i)),
        ),
    };
  }
}

/// What [MealPlanDao.copyWeek] does about a target day that already holds
/// a plan.
enum CopyWeekConflict {
  /// Leave that day exactly as it is. The default, because the copy is a
  /// convenience and a day somebody has already thought about is not
  /// something a convenience should overwrite.
  skipDay,

  /// Copy into it anyway, adding to what is there.
  addAnyway,
}

/// One entry in a plan, with the names a list needs already joined in.
class PlannedFood {
  const PlannedFood({
    required this.entry,
    required this.foodName,
    required this.mealSlotId,
    required this.mealSlotName,
    required this.servingLabel,
    required this.energyKcal,
  });

  final FoodLogEntry entry;
  final String foodName;
  final String mealSlotId;
  final String mealSlotName;
  final String? servingLabel;

  /// Null when the food reports no energy value — unknown, not zero (I-2).
  final double? energyKcal;

  bool get isPlanned => entry.status == logStatusPlanned;
  bool get isEaten => entry.status == logStatusLogged;
  bool get isSkipped => entry.status == logStatusSkipped;
}

/// One nutrient on a projected day, split by what is already true and what
/// is still an intention.
class ProjectedNutrient {
  const ProjectedNutrient({
    required this.nutrientId,
    required this.eaten,
    required this.planned,
  });

  final String nutrientId;
  final double eaten;
  final double planned;

  double get total => eaten + planned;

  ProjectedNutrient addEaten(double amount) => ProjectedNutrient(
    nutrientId: nutrientId,
    eaten: eaten + amount,
    planned: planned,
  );

  ProjectedNutrient addPlanned(double amount) => ProjectedNutrient(
    nutrientId: nutrientId,
    eaten: eaten,
    planned: planned + amount,
  );
}
