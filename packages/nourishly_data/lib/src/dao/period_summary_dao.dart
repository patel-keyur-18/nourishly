import 'package:drift/drift.dart';
import 'package:nutrition_core/nutrition_core.dart';

// See ProfileDao: the Drift row classes shadow core value objects of the
// same name.
import '../database.dart' hide DailyScore, NutrientTarget;
// The stored score row, whose class name the core value object shadows.
import '../database.dart' as rows show DailyScore;
import 'daily_summary_dao.dart';
import 'profile_dao.dart';

/// Builds a week or a month out of the stored daily summaries (§25.8:
/// reports are computed on device, over materialised days).
///
/// It does not re-aggregate entries. Every day in the range is read from
/// [DailySummaries] and its children, and only a day that is stale or
/// missing *and* has something logged on it is recomputed first — a month
/// of untouched days should cost nothing and write nothing.
///
/// The arithmetic and every §25.6 honesty rule live in `nutrition_core`'s
/// [PeriodSummary], not here (AP-5): this class's whole job is turning
/// rows into [PeriodDay]s.
class PeriodSummaryDao {
  PeriodSummaryDao(this._db);

  final NourishlyDatabase _db;

  /// The week containing [containing], starting on [weekStartDay]
  /// (`DateTime.monday`..`DateTime.sunday`, from `UserPreferences`).
  Future<PeriodSummary> week({
    required String ownerId,
    required DateTime containing,
    int weekStartDay = DateTime.monday,
    DateTime? now,
  }) {
    final start = startOfWeek(containing, weekStartDay);
    return forRange(
      ownerId: ownerId,
      kind: PeriodKind.week,
      start: start,
      end: start.add(const Duration(days: 6)),
      now: now,
    );
  }

  /// The calendar month containing [containing].
  Future<PeriodSummary> month({
    required String ownerId,
    required DateTime containing,
    DateTime? now,
  }) => forRange(
    ownerId: ownerId,
    kind: PeriodKind.month,
    start: startOfMonth(containing),
    end: endOfMonth(containing),
    now: now,
  );

  /// Both ends inclusive.
  Future<PeriodSummary> forRange({
    required String ownerId,
    required PeriodKind kind,
    required DateTime start,
    required DateTime end,
    DateTime? now,
  }) async {
    final from = dateOnly(start);
    final to = dateOnly(end);
    final at = now ?? DateTime.now();

    await _refreshStaleDays(ownerId: ownerId, from: from, to: to, now: at);

    final summaries =
        await (_db.select(_db.dailySummaries)..where(
              (s) =>
                  s.ownerId.equals(ownerId) &
                  s.logDate.isBiggerOrEqualValue(from) &
                  s.logDate.isSmallerOrEqualValue(to),
            ))
            .get();
    final summaryByDate = {for (final s in summaries) s.logDate: s};
    final summaryIds = summaries.map((s) => s.id).toList();

    final nutrientRows = summaryIds.isEmpty
        ? <DailySummaryNutrient>[]
        : await (_db.select(
            _db.dailySummaryNutrients,
          )..where((n) => n.summaryId.isIn(summaryIds))).get();
    final nutrientsBySummary = <String, List<DailySummaryNutrient>>{};
    for (final row in nutrientRows) {
      (nutrientsBySummary[row.summaryId] ??= []).add(row);
    }

    final scoreRows = summaryIds.isEmpty
        ? <rows.DailyScore>[]
        : await (_db.select(
            _db.dailyScores,
          )..where((s) => s.summaryId.isIn(summaryIds))).get();
    final scoreBySummary = {for (final s in scoreRows) s.summaryId: s};

    final waterByDate = await _waterByDate(ownerId, from, to);
    final waterTargetByDate = await _waterTargetByDate(ownerId, from, to);

    final order = await (_db.select(
      _db.nutrients,
    )..orderBy([(n) => OrderingTerm.asc(n.sortOrder)])).get();

    final days = <PeriodDay>[];
    for (
      var date = from;
      !date.isAfter(to);
      date = DateTime(date.year, date.month, date.day + 1)
    ) {
      final water = waterByDate[date] ?? 0;
      final summary = summaryByDate[date];

      if (summary == null) {
        // No summary row at all. Water alone still makes it a logged day
        // — Persona 4 logs nothing else (§28.3).
        days.add(
          water > 0
              ? PeriodDay(
                  date: date,
                  completeness: _completenessOf(date, at, 'complete'),
                  entryCount: 0,
                  totalEnergyKcal: 0,
                  waterMl: water,
                  nutrients: const {},
                  waterTargetMl: waterTargetByDate[date],
                )
              : PeriodDay.unlogged(date),
        );
        continue;
      }

      final nutrients = {
        for (final row
            in nutrientsBySummary[summary.id] ?? const <DailySummaryNutrient>[])
          row.nutrientId: PeriodDayNutrient(
            nutrientId: row.nutrientId,
            amount: row.amount,
            coverage: row.coverage,
            status: NutrientStatus.fromId(row.status),
            targetAmount: row.targetAmount,
          ),
      };

      days.add(
        PeriodDay(
          date: date,
          completeness: _completenessOf(date, at, summary.completenessFlag),
          entryCount: summary.entryCount,
          totalEnergyKcal: summary.totalEnergyKcal,
          waterMl: water,
          nutrients: nutrients,
          score: scoreBySummary[summary.id]?.compositeScore,
          energyTargetKcal: nutrients['energy']?.targetAmount,
          waterTargetMl: waterTargetByDate[date],
          loggedMealSlots: summary.loggedMealSlots.isEmpty
              ? const {}
              : summary.loggedMealSlots.split(',').toSet(),
        ),
      );
    }

    return PeriodSummary(
      kind: kind,
      start: from,
      end: to,
      days: days,
      nutrientOrder: [for (final n in order) n.id],
    );
  }

  /// Recomputes the days in the range that need it.
  ///
  /// Only days something was actually logged on: a summary row for an
  /// untouched day is a write for nothing, and thirty of them on opening a
  /// month is thirty writes for nothing.
  Future<void> _refreshStaleDays({
    required String ownerId,
    required DateTime from,
    required DateTime to,
    required DateTime now,
  }) async {
    final entryDates =
        await (_db.selectOnly(_db.foodLogEntries, distinct: true)
              ..addColumns([_db.foodLogEntries.logDate])
              ..where(
                _db.foodLogEntries.ownerId.equals(ownerId) &
                    _db.foodLogEntries.logDate.isBiggerOrEqualValue(from) &
                    _db.foodLogEntries.logDate.isSmallerOrEqualValue(to) &
                    _db.foodLogEntries.deletedAt.isNull(),
              ))
            .map((row) => row.read(_db.foodLogEntries.logDate)!)
            .get();

    if (entryDates.isEmpty) return;

    final fresh =
        await (_db.select(_db.dailySummaries)..where(
              (s) =>
                  s.ownerId.equals(ownerId) &
                  s.logDate.isBiggerOrEqualValue(from) &
                  s.logDate.isSmallerOrEqualValue(to) &
                  s.isStale.equals(false),
            ))
            .get();
    final upToDate = {for (final s in fresh) s.logDate};

    final dao = DailySummaryDao(_db);
    for (final date in entryDates) {
      if (upToDate.contains(date)) continue;
      await dao.recompute(ownerId: ownerId, logDate: date, now: now);
    }
  }

  Future<Map<DateTime, double>> _waterByDate(
    String ownerId,
    DateTime from,
    DateTime to,
  ) async {
    final total = _db.waterLogEntries.volumeMl.sum();
    final rows =
        await (_db.selectOnly(_db.waterLogEntries)
              ..addColumns([_db.waterLogEntries.logDate, total])
              ..where(
                _db.waterLogEntries.ownerId.equals(ownerId) &
                    _db.waterLogEntries.logDate.isBiggerOrEqualValue(from) &
                    _db.waterLogEntries.logDate.isSmallerOrEqualValue(to) &
                    _db.waterLogEntries.deletedAt.isNull(),
              )
              ..groupBy([_db.waterLogEntries.logDate]))
            .get();
    return {
      for (final row in rows)
        row.read(_db.waterLogEntries.logDate)!: row.read(total) ?? 0,
    };
  }

  /// The water target in force on each day of the range.
  ///
  /// Read per day rather than once for the period: targets are
  /// effective-dated and never retroactive (§20.4, I-3), so a period that
  /// spans a target change has two of them, and "met on 3 of 6 days" must
  /// be counted against whichever one applied that day.
  Future<Map<DateTime, double>> _waterTargetByDate(
    String ownerId,
    DateTime from,
    DateTime to,
  ) async {
    final profile = ProfileDao(_db);
    final byTargetSet = <String, double?>{};
    final result = <DateTime, double>{};

    for (
      var date = from;
      !date.isAfter(to);
      date = DateTime(date.year, date.month, date.day + 1)
    ) {
      final set = await profile.targetSetOn(ownerId, date);
      if (set == null) continue;
      if (!byTargetSet.containsKey(set.id)) {
        byTargetSet[set.id] = (await profile.targetsIn(
          set.id,
        ))['water']?.amount;
      }
      if (byTargetSet[set.id] case final amount?) result[date] = amount;
    }
    return result;
  }

  /// A day that has not finished yet is `in_progress` whatever the stored
  /// flag says — the flag was written when the summary was last computed,
  /// which for today may have been an hour ago.
  static DayCompleteness _completenessOf(
    DateTime date,
    DateTime now,
    String storedFlag,
  ) {
    final isPast = dateOnly(date).isBefore(dateOnly(now));
    if (!isPast) return DayCompleteness.inProgress;
    return DayCompleteness.fromId(storedFlag);
  }
}

/// The [weekStartDay]-starting week containing [date]. [weekStartDay] uses
/// `DateTime`'s constants, where Monday is 1 and Sunday is 7.
DateTime startOfWeek(DateTime date, int weekStartDay) {
  final day = dateOnly(date);
  final back = (day.weekday - weekStartDay + 7) % 7;
  return day.subtract(Duration(days: back));
}

DateTime startOfMonth(DateTime date) => DateTime(date.year, date.month);

/// Day zero of the next month is the last day of this one, which also
/// handles February and leap years without a table.
DateTime endOfMonth(DateTime date) => DateTime(date.year, date.month + 1, 0);
