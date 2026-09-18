import 'package:meta/meta.dart';

import 'period_summary.dart';

/// Which way a number moved, when it moved far enough to say so.
enum TrendDirection {
  up('up', 'up'),
  down('down', 'down'),

  /// Moved, but not by enough to call it a trend (§25.6). Distinct from
  /// "no comparison available": this one has both periods and has looked.
  flat('flat', 'about the same');

  const TrendDirection(this.id, this.label);

  final String id;
  final String label;
}

/// Why a comparison could not be drawn. Never silent — a missing arrow
/// with no explanation reads as "no change", which is a different claim.
enum ComparisonWithheldReason {
  /// This period is below §25.6's logging threshold.
  currentPeriodTooSparse(
    'current_too_sparse',
    'Not enough logged days in this period to compare.',
  ),

  /// The one before it is.
  previousPeriodTooSparse(
    'previous_too_sparse',
    'Not enough logged days in the previous period to compare against.',
  ),

  /// Both are logged enough, but nothing in one of them was scored.
  nothingScored(
    'nothing_scored',
    'Neither period has enough scored days to compare.',
  );

  const ComparisonWithheldReason(this.id, this.message);

  final String id;
  final String message;
}

/// One measure moved between two periods, with the bases it moved between.
///
/// §27.11: paired values with an explicit delta, never a bare percentage —
/// "+12%" hides what it is 12% of.
@immutable
class PeriodDelta {
  const PeriodDelta({
    required this.current,
    required this.previous,
    required this.direction,
  });

  final double current;
  final double previous;
  final TrendDirection direction;

  double get delta => current - previous;

  double? get relativeDelta => previous == 0 ? null : delta / previous;

  bool get isTrend => direction != TrendDirection.flat;
}

/// This period against the one before it (§27.10).
///
/// §25.6: a comparison needs *both* periods to clear the logging
/// threshold. Comparing a six-day week to a two-day week produces a
/// meaningless delta and a misleading arrow, so this refuses to produce
/// one and says why instead.
@immutable
class PeriodComparison {
  const PeriodComparison._({
    required this.current,
    required this.previous,
    this.score,
    this.energyKcal,
    this.withheldReason,
  });

  factory PeriodComparison.between({
    required PeriodSummary current,
    required PeriodSummary previous,
  }) {
    if (!current.meetsLoggingThreshold) {
      return PeriodComparison._(
        current: current,
        previous: previous,
        withheldReason: ComparisonWithheldReason.currentPeriodTooSparse,
      );
    }
    if (!previous.meetsLoggingThreshold) {
      return PeriodComparison._(
        current: current,
        previous: previous,
        withheldReason: ComparisonWithheldReason.previousPeriodTooSparse,
      );
    }

    final scoreDelta = _delta(
      current: current.averageScore,
      previous: previous.averageScore,
      currentSample: current.scoredDayCount,
      previousSample: previous.scoredDayCount,
      minAbsolute: PeriodHonesty.minScoreDeltaForTrend,
    );
    final energyDelta = _delta(
      current: current.averageEnergyKcal,
      previous: previous.averageEnergyKcal,
      currentSample: current.averagedDayCount,
      previousSample: previous.averagedDayCount,
      // Energy has no natural absolute floor the way a 0-100 score does,
      // so it is gated on the relative movement alone.
      minAbsolute: 0,
    );

    if (scoreDelta == null && energyDelta == null) {
      return PeriodComparison._(
        current: current,
        previous: previous,
        withheldReason: ComparisonWithheldReason.nothingScored,
      );
    }

    return PeriodComparison._(
      current: current,
      previous: previous,
      score: scoreDelta,
      energyKcal: energyDelta,
    );
  }

  final PeriodSummary current;
  final PeriodSummary previous;

  /// Null when the score could not be compared.
  final PeriodDelta? score;
  final PeriodDelta? energyKcal;

  final ComparisonWithheldReason? withheldReason;

  bool get isAvailable => withheldReason == null;

  /// A delta, or null when there is not enough of a sample to have one.
  ///
  /// The direction is separately gated on effect size: a sample can be
  /// large enough to state both averages and still too small a movement to
  /// draw an arrow between them, which is [TrendDirection.flat].
  static PeriodDelta? _delta({
    required double? current,
    required double? previous,
    required int currentSample,
    required int previousSample,
    required double minAbsolute,
  }) {
    if (current == null || previous == null) return null;
    if (currentSample < PeriodHonesty.minDaysForTrend ||
        previousSample < PeriodHonesty.minDaysForTrend) {
      return null;
    }

    final delta = current - previous;
    final relative = previous == 0 ? double.infinity : delta.abs() / previous;
    final movedEnough =
        delta.abs() >= minAbsolute &&
        relative >= PeriodHonesty.minRelativeDeltaForTrend;

    return PeriodDelta(
      current: current,
      previous: previous,
      direction: !movedEnough
          ? TrendDirection.flat
          : delta > 0
          ? TrendDirection.up
          : TrendDirection.down,
    );
  }
}
