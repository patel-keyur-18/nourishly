import 'package:meta/meta.dart';

import 'score_component.dart';

/// How a composite score is presented (§21.6). A band and a number
/// together, never a bare number, and never colour alone (NFR-A-04) — each
/// band carries its own label.
enum ScoreBand {
  excellent('excellent', 'Excellent', 85),
  good('good', 'Good', 70),
  fair('fair', 'Fair', 50),
  needsAttention('needs_attention', 'Needs attention', 0);

  const ScoreBand(this.id, this.label, this.lowerBound);

  final String id;
  final String label;
  final double lowerBound;

  static ScoreBand forScore(double score) => values.firstWhere(
    (b) => score >= b.lowerBound,
    orElse: () => ScoreBand.needsAttention,
  );

  static ScoreBand fromId(String id) => values.firstWhere((b) => b.id == id);
}

/// Why a day has no composite score at all. §21.6: a withheld score shows
/// its reason, never a blank or a zero.
enum ScoreWithheldReason {
  /// The day is still running. During the day the dashboard shows progress
  /// framed as remaining budget, not a score (§21.5).
  dayIncomplete(
    'day_incomplete',
    "Today is still going — this becomes a score after the day rolls over.",
  ),

  /// Logged energy is implausibly low against the target, which nearly
  /// always means a forgotten meal rather than a real deficit (§21.5).
  looksIncompletelyLogged(
    'looks_incompletely_logged',
    'This day looks incompletely logged, so it has not been scored.',
  ),

  /// Nothing was logged.
  nothingLogged('nothing_logged', 'Nothing was logged on this day.'),

  /// No target set was in force — a profile that skipped setup entirely.
  noTargets('no_targets', 'Set up your targets to see a score for the day.'),

  /// Every component was excluded, so there is nothing to average.
  allComponentsExcluded(
    'all_components_excluded',
    'Not enough of the day could be scored.',
  );

  const ScoreWithheldReason(this.id, this.message);

  final String id;
  final String message;

  static ScoreWithheldReason fromId(String id) =>
      values.firstWhere((r) => r.id == id);
}

/// A day's score, decomposed. The components are always present — §21.1
/// makes them the product and the composite the convenience, and §21.6
/// forbids showing the composite without them.
@immutable
class DailyScore {
  const DailyScore({
    required this.components,
    required this.composite,
    required this.band,
    required this.withheldReason,
  });

  /// Aggregates scored components into a composite (§21.4).
  ///
  /// Two rules do the work. Excluded components have their weight
  /// redistributed proportionally across the rest, so the remaining
  /// weights still sum to 1 rather than quietly scoring four fifths of a
  /// day as if it were whole. Then the floor guard: the weakest component
  /// pulls the composite down by up to 15%, enough that a zero is visible
  /// without letting one bad number dominate the way a harmonic mean
  /// would.
  factory DailyScore.from(
    Iterable<ScoredComponent> rawComponents, {
    ScoreWithheldReason? withheld,
  }) {
    final scored = rawComponents.where((c) => !c.wasExcluded).toList();
    final totalScoredWeight = scored.fold<double>(0, (a, c) => a + c.weight);

    final components = [
      for (final c in rawComponents)
        ScoredComponent(
          key: c.key,
          score: c.score,
          weight: c.weight,
          appliedWeight: c.wasExcluded || totalScoredWeight <= 0
              ? 0
              : c.weight / totalScoredWeight,
          exclusion: c.exclusion,
        ),
    ];

    if (withheld != null) {
      return DailyScore(
        components: components,
        composite: null,
        band: null,
        withheldReason: withheld,
      );
    }
    if (scored.isEmpty) {
      return DailyScore(
        components: components,
        composite: null,
        band: null,
        withheldReason: ScoreWithheldReason.allComponentsExcluded,
      );
    }

    final weighted = components
        .where((c) => !c.wasExcluded)
        .fold<double>(0, (a, c) => a + c.appliedWeight * c.score!);
    final minComponent = scored
        .map((c) => c.score!)
        .reduce((a, b) => a < b ? a : b);
    final composite = weighted * (0.85 + 0.15 * minComponent / 100);

    return DailyScore(
      components: components,
      composite: composite,
      band: ScoreBand.forScore(composite),
      withheldReason: null,
    );
  }

  final List<ScoredComponent> components;

  /// Null when [withheldReason] is set.
  final double? composite;
  final ScoreBand? band;
  final ScoreWithheldReason? withheldReason;

  bool get isWithheld => withheldReason != null;

  ScoredComponent? component(ScoreComponentKey key) {
    for (final c in components) {
      if (c.key == key) return c;
    }
    return null;
  }
}
