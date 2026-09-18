import 'package:meta/meta.dart';

import '../aggregation/nutrient_aggregate.dart';

/// How completely a day was logged (§21.5, mirrored by
/// `DailySummary.completenessFlag`).
///
/// This is the distinction §25.6 turns on: a day nobody logged and a day
/// somebody logged badly are different kinds of absence, and only one of
/// them belongs in an average.
enum DayCompleteness {
  /// Nothing at all was logged.
  empty('empty'),

  /// Still running — not yet a finished day.
  inProgress('in_progress'),

  /// Logged, but so far under target that a forgotten meal is the likelier
  /// explanation than a genuinely tiny day (§21.5).
  looksIncomplete('looks_incomplete'),

  /// A finished, plausibly complete day.
  complete('complete');

  const DayCompleteness(this.id);

  final String id;

  static DayCompleteness fromId(String id) =>
      values.firstWhere((f) => f.id == id, orElse: () => empty);
}

/// One nutrient on one day, as a period reads it.
@immutable
class PeriodDayNutrient {
  const PeriodDayNutrient({
    required this.nutrientId,
    required this.amount,
    required this.coverage,
    required this.status,
    this.targetAmount,
  });

  final String nutrientId;
  final double amount;

  /// Fraction of the day's energy that came from foods reporting this
  /// nutrient (§20.8). Carried through so a period average can state the
  /// coverage it was built from (§25.6).
  final double coverage;

  final NutrientStatus status;
  final double? targetAmount;

  bool get metTarget => status == NutrientStatus.within;
  bool get hasData => status != NutrientStatus.insufficientData;
}

/// One calendar day's contribution to a period.
///
/// Every day in the period gets one of these, logged or not: a period that
/// only carries the days somebody logged has already lost the denominator
/// §25.6 insists on showing.
@immutable
class PeriodDay {
  const PeriodDay({
    required this.date,
    required this.completeness,
    required this.entryCount,
    required this.totalEnergyKcal,
    required this.waterMl,
    required this.nutrients,
    this.score,
    this.energyTargetKcal,
    this.waterTargetMl,
    this.loggedMealSlots = const {},
  });

  /// An untouched day. The shape a period needs for a date nothing was
  /// written against.
  const PeriodDay.unlogged(this.date)
    : completeness = DayCompleteness.empty,
      entryCount = 0,
      totalEnergyKcal = 0,
      waterMl = 0,
      nutrients = const {},
      score = null,
      energyTargetKcal = null,
      waterTargetMl = null,
      loggedMealSlots = const {};

  final DateTime date;
  final DayCompleteness completeness;
  final int entryCount;
  final double totalEnergyKcal;
  final double waterMl;

  /// Keyed by nutrient id.
  final Map<String, PeriodDayNutrient> nutrients;

  /// Null when the day's score was withheld (§21.5) — which is not zero,
  /// and is left as a gap rather than interpolated (§27.11).
  final double? score;

  final double? energyTargetKcal;
  final double? waterTargetMl;
  final Set<String> loggedMealSlots;

  /// Somebody put something here. Water alone counts: Persona 4 logs
  /// nothing else, and a water-only day is a logged day.
  bool get wasLogged => entryCount > 0 || waterMl > 0;

  /// Whether this day may be averaged.
  ///
  /// §25.6: days flagged as incompletely logged are excluded by default,
  /// because a forgotten dinner averaged in reads as a deliberate deficit.
  /// A day still in progress is excluded for the same reason — it is not
  /// finished, so it is not yet a data point.
  bool get countsTowardAverages =>
      wasLogged &&
      completeness != DayCompleteness.looksIncomplete &&
      completeness != DayCompleteness.inProgress;

  bool get isExcludedAsIncomplete =>
      wasLogged && completeness == DayCompleteness.looksIncomplete;
}
