import 'package:meta/meta.dart';

import '../aggregation/nutrient_aggregate.dart';
import 'period_day.dart';

/// A week or a month. The engine treats them identically; the distinction
/// exists so a screen can say which one it is showing.
enum PeriodKind {
  week('week', 'Week'),
  month('month', 'Month');

  const PeriodKind(this.id, this.label);

  final String id;
  final String label;
}

/// §25.6's thresholds, in one place because they are the rules that stop
/// the reports lying and they should be readable as a group.
class PeriodHonesty {
  const PeriodHonesty._();

  /// "A period with < 3 logged days shows raw data and no averages or
  /// trends." Stated by §25.6; not a judgement call.
  static const int minDaysForAverages = 3;

  /// A trend arrow needs a minimum sample as well as a minimum effect.
  ///
  /// [ASSUMPTION] §25.6 requires both and names neither. Five averaged
  /// days in each period is a little over a working week's worth of
  /// evidence and is the smallest sample where a direction is worth
  /// drawing at all.
  static const int minDaysForTrend = 5;

  /// The smallest score movement that may be drawn as a trend.
  ///
  /// [ASSUMPTION] §25.6's own example — "a 1.5% change across 5 days is
  /// not a trend" — puts the floor above 1.5. Three points on a 0-100
  /// score is roughly one band's worth of movement over a third of a band,
  /// and below it the arrow would mostly be tracking which days got
  /// logged.
  static const double minScoreDeltaForTrend = 3;

  /// The smallest relative movement in a nutrient average that may be
  /// drawn as a trend.
  ///
  /// [ASSUMPTION] As above: 5% of the earlier average, so a 19 g fibre
  /// week and a 19.5 g fibre week do not get an arrow between them.
  static const double minRelativeDeltaForTrend = 0.05;

  /// How much of a period a nutrient must miss its target on before the
  /// report calls it chronic.
  ///
  /// [ASSUMPTION] §27.10 asks for "chronically low and chronically high"
  /// and defines neither. Half the averaged days is the point where a miss
  /// stops being a bad week and starts being how the household eats — and
  /// the count is always shown next to it ("19 of 24 days"), so the reader
  /// can judge the threshold for themselves.
  static const double chronicShare = 0.5;
}

/// One nutrient averaged across a period, carrying every denominator
/// §25.6 requires it to be stated against.
@immutable
class PeriodNutrientAverage {
  const PeriodNutrientAverage({
    required this.nutrientId,
    required this.average,
    required this.daysAveraged,
    required this.daysMet,
    required this.daysWithData,
    required this.averageCoverage,
    this.targetAmount,
  });

  final String nutrientId;

  /// Mean across [daysAveraged] — never across the calendar days of the
  /// period, and never across days with no data for this nutrient.
  final double average;

  /// The denominator. Displayed with the average, always.
  final int daysAveraged;

  /// How many of [daysAveraged] met the target.
  final int daysMet;

  /// How many days reported this nutrient at all — below [daysAveraged]
  /// when some of the period's food has no value for it.
  final int daysWithData;

  /// Mean energy-weighted coverage across the days averaged. §25.6: "a
  /// month's iron average built from 40% coverage must say so."
  final double averageCoverage;

  final double? targetAmount;

  int get daysMissed => daysAveraged - daysMet;

  double? get shareMet => daysAveraged == 0 ? null : daysMet / daysAveraged;
}

/// A nutrient the period was short of, or over on, often enough to be
/// worth naming (§27.10).
@immutable
class ChronicNutrient {
  const ChronicNutrient({
    required this.nutrientId,
    required this.days,
    required this.outOf,
    required this.status,
  });

  final String nutrientId;

  /// Days it was [status] on.
  final int days;

  /// Days averaged — the denominator, shown as "19 of 24 days".
  final int outOf;

  final NutrientStatus status;

  double get share => outOf == 0 ? 0 : days / outOf;
}

/// One point on a trend line. A day with no score is a point with no
/// value, not a missing point: §27.11 leaves gaps as gaps rather than
/// interpolating across them, because interpolation invents data.
@immutable
class ScorePoint {
  const ScorePoint({required this.date, this.score});

  final DateTime date;
  final double? score;
}

/// A week or a month of days, reduced to what a report may honestly say
/// about them.
///
/// Everything §25.6 forbids is structurally impossible here rather than
/// left to the screen: [nutrientAverages] is empty below the logging
/// threshold, every average carries its denominator, and a day flagged as
/// incompletely logged never reaches an average.
@immutable
class PeriodSummary {
  PeriodSummary({
    required this.kind,
    required this.start,
    required this.end,
    required List<PeriodDay> days,
    List<String> nutrientOrder = const [],
  }) : days = List.unmodifiable(days),
       nutrientOrder = List.unmodifiable(nutrientOrder);

  final PeriodKind kind;

  /// Inclusive, both ends.
  final DateTime start;
  final DateTime end;

  /// Every calendar day in the period, in order — including the ones
  /// nothing was logged on, which are what make the denominator real.
  final List<PeriodDay> days;

  /// Nutrient ids in registry order, so every list this produces reads the
  /// same way every time. Ids not named here follow, in whatever order
  /// they turned up.
  final List<String> nutrientOrder;

  int get calendarDayCount => days.length;

  Iterable<PeriodDay> get loggedDays => days.where((d) => d.wasLogged);

  /// The days an average may be built from.
  Iterable<PeriodDay> get averagedDays =>
      days.where((d) => d.countsTowardAverages);

  int get loggedDayCount => loggedDays.length;
  int get averagedDayCount => averagedDays.length;

  /// Logged, but held out of the averages because the day looks like it is
  /// missing a meal. Shown, not hidden — §25.6 wants the exclusion visible.
  List<PeriodDay> get daysExcludedAsIncomplete =>
      days.where((d) => d.isExcludedAsIncomplete).toList();

  /// Below this, the screen shows the raw days and an explanation instead
  /// of averages.
  bool get meetsLoggingThreshold =>
      averagedDayCount >= PeriodHonesty.minDaysForAverages;

  /// Days that were scored. A logged day whose score was withheld is not
  /// one of them.
  List<PeriodDay> get scoredDays =>
      days.where((d) => d.score != null).toList(growable: false);

  /// Null below the logging threshold, and null when nothing was scored.
  double? get averageScore {
    if (!meetsLoggingThreshold) return null;
    final scored = averagedDays.where((d) => d.score != null).toList();
    if (scored.isEmpty) return null;
    return scored.fold<double>(0, (a, d) => a + d.score!) / scored.length;
  }

  int get scoredDayCount => averagedDays.where((d) => d.score != null).length;

  /// Null below the logging threshold.
  double? get averageEnergyKcal {
    if (!meetsLoggingThreshold) return null;
    final withFood = averagedDays.where((d) => d.entryCount > 0).toList();
    if (withFood.isEmpty) return null;
    return withFood.fold<double>(0, (a, d) => a + d.totalEnergyKcal) /
        withFood.length;
  }

  /// Null below the logging threshold. Averaged over days something was
  /// logged on, not over days water was logged on: a day of food and no
  /// water really did have no water.
  double? get averageWaterMl {
    if (!meetsLoggingThreshold) return null;
    final counted = averagedDays.toList();
    if (counted.isEmpty) return null;
    return counted.fold<double>(0, (a, d) => a + d.waterMl) / counted.length;
  }

  /// The score line, one point per calendar day, unlogged days left as
  /// gaps (§27.11).
  List<ScorePoint> get scoreSeries => [
    for (final day in days) ScorePoint(date: day.date, score: day.score),
  ];

  /// A trailing mean over [window] days, the smoothed signal §27.11 wants
  /// under a noisy monthly line.
  ///
  /// A point is null until [window] days have passed and until at least
  /// half the window has a score — averaging one scored day out of seven
  /// and drawing it as a seven-day average would be the same lie as
  /// averaging a week over two days.
  List<ScorePoint> movingAverage({int window = 7}) {
    final series = scoreSeries;
    return [
      for (var i = 0; i < series.length; i++)
        () {
          if (i + 1 < window) return ScorePoint(date: series[i].date);
          final slice = series.sublist(i + 1 - window, i + 1);
          final scores = [for (final p in slice) ?p.score];
          if (scores.length * 2 < window) {
            return ScorePoint(date: series[i].date);
          }
          return ScorePoint(
            date: series[i].date,
            score: scores.reduce((a, b) => a + b) / scores.length,
          );
        }(),
    ];
  }

  /// Averages for every nutrient the period has data for, in
  /// [nutrientOrder]. Empty below the logging threshold.
  ///
  /// Computed once: a month's report reads this from several places in one
  /// build, and it walks every day of the period.
  late final List<PeriodNutrientAverage> nutrientAverages = _averages();

  List<PeriodNutrientAverage> _averages() {
    if (!meetsLoggingThreshold) return const [];

    final counted = averagedDays.toList();
    final ids = <String>{for (final day in counted) ...day.nutrients.keys};
    final ordered = [
      for (final id in nutrientOrder)
        if (ids.contains(id)) id,
      for (final id in ids)
        if (!nutrientOrder.contains(id)) id,
    ];

    return [
      for (final id in ordered)
        () {
          final present = [
            for (final day in counted)
              if (day.nutrients[id] case final n?)
                if (n.hasData) n,
          ];
          if (present.isEmpty) return null;
          return PeriodNutrientAverage(
            nutrientId: id,
            average:
                present.fold<double>(0, (a, n) => a + n.amount) /
                present.length,
            daysAveraged: present.length,
            daysMet: present.where((n) => n.metTarget).length,
            daysWithData: present.length,
            averageCoverage:
                present.fold<double>(0, (a, n) => a + n.coverage) /
                present.length,
            targetAmount: present
                .map((n) => n.targetAmount)
                .whereType<double>()
                .firstOrNull,
          );
        }(),
    ].whereType<PeriodNutrientAverage>().toList();
  }

  /// One nutrient's average, or null if the period has none for it.
  PeriodNutrientAverage? nutrientAverage(String nutrientId) {
    for (final average in nutrientAverages) {
      if (average.nutrientId == nutrientId) return average;
    }
    return null;
  }

  /// The best-scoring day, or null when nothing in the period was scored.
  PeriodDay? get bestDay {
    PeriodDay? best;
    for (final day in averagedDays) {
      if (day.score == null) continue;
      if (best == null || day.score! > best.score!) best = day;
    }
    return best;
  }

  /// Nutrients missed most often, worst first — §27.9's "most-missed
  /// nutrients". Only nutrients with a target, since a nutrient with
  /// nothing to miss cannot be missed.
  List<PeriodNutrientAverage> mostMissed({int limit = 3}) {
    final missed =
        nutrientAverages
            .where((n) => n.targetAmount != null && n.daysMissed > 0)
            .toList()
          ..sort((a, b) => b.daysMissed.compareTo(a.daysMissed));
    return missed.take(limit).toList();
  }

  /// Nutrients below target on at least [PeriodHonesty.chronicShare] of
  /// the averaged days (§27.10).
  List<ChronicNutrient> get chronicallyLow => _chronic(NutrientStatus.below);

  /// Nutrients above target on at least the same share.
  List<ChronicNutrient> get chronicallyHigh => _chronic(NutrientStatus.above);

  List<ChronicNutrient> _chronic(NutrientStatus status) {
    if (!meetsLoggingThreshold) return const [];
    final counted = averagedDays.toList();
    final ids = <String>{for (final day in counted) ...day.nutrients.keys};

    final result = <ChronicNutrient>[];
    for (final id in ids) {
      final withData = [
        for (final day in counted)
          if (day.nutrients[id] case final n?)
            if (n.hasData && n.targetAmount != null) n,
      ];
      if (withData.isEmpty) continue;
      final hits = withData.where((n) => n.status == status).length;
      if (hits / withData.length < PeriodHonesty.chronicShare) continue;
      result.add(
        ChronicNutrient(
          nutrientId: id,
          days: hits,
          outOf: withData.length,
          status: status,
        ),
      );
    }
    return result..sort((a, b) => b.share.compareTo(a.share));
  }

  /// Which days were logged, for §27.11's consistency strip. One entry per
  /// calendar day, so the gaps are as visible as the fills.
  List<DayCompleteness> get consistencyStrip => [
    for (final day in days) day.completeness,
  ];
}
