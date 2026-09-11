import 'package:meta/meta.dart';

import '../aggregation/nutrient_aggregate.dart';
import '../nutrients/nutrient_id.dart';
import '../scoring/daily_score.dart';
import '../scoring/day_scorer.dart';
import '../scoring/nutrient_target.dart';
import '../scoring/score_component.dart';
import '../targets/target_curve_type.dart';
import 'insight.dart';

/// Ruleset version for the insight rules and their copy.
const String insightRulesetVersion = '1.0.0';

/// Everything the rules can see. Deliberately a fixed surface: a rule can
/// read the day, its targets, its coverage and a little history, and
/// nothing else.
@immutable
class InsightContext {
  const InsightContext({
    required this.day,
    required this.score,
    required this.displayNames,
    this.consecutiveDaysProteinMet = 0,
    this.daysLoggedInLastWeek = 0,
  });

  final DayForScoring day;
  final DailyScore score;

  /// Nutrient id -> display name, so a rule never has to hard-code
  /// "Fibre" and the strings stay externalisable (§27.14).
  final Map<NutrientId, String> displayNames;

  final int consecutiveDaysProteinMet;
  final int daysLoggedInLastWeek;

  NutrientAggregate? aggregate(NutrientId id) => day.nutrients[id];
  NutrientTarget? target(NutrientId id) => day.targets[id];

  String name(NutrientId id) => displayNames[id] ?? id;
}

/// A rule: a condition over the day and the sentence it produces.
///
/// Rules are data in the sense that matters — each is a small, separately
/// reviewable value with its copy attached, so §21.7's language-boundary
/// review is a read of this file rather than an audit of control flow. An
/// LLM is deliberately not used: it could not be guaranteed to stay inside
/// the boundary, and it would break offline operation.
@immutable
class InsightRule {
  const InsightRule({
    required this.id,
    required this.priority,
    required this.category,
    required this.render,
  });

  final String id;
  final int priority;
  final InsightCategory category;

  /// Returns the sentence, or null when the rule does not apply.
  final String? Function(InsightContext) render;

  Insight? evaluate(InsightContext context) {
    final text = render(context);
    return text == null
        ? null
        : Insight(
            ruleId: id,
            category: category,
            text: text,
            priority: priority,
          );
  }
}

/// Generates the day's insights, highest priority first.
///
/// §21.7 shows the top 2-4; the caller decides how many, because the daily
/// report has room for four and the dashboard has room for one.
List<Insight> generateInsights(InsightContext context, {int limit = 4}) {
  final insights = <Insight>[];
  for (final rule in insightRules) {
    final insight = rule.evaluate(context);
    if (insight != null) insights.add(insight);
  }
  insights.sort((a, b) => a.priority.compareTo(b.priority));
  return insights.take(limit).toList();
}

/// Formats a nutrient amount the way the report writes it: whole numbers
/// for milligram-scale nutrients, one decimal for gram-scale ones under 20.
String _fmt(double value) {
  if (value >= 100) return value.round().toString();
  if (value >= 20) return value.round().toString();
  return value.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
}

/// Ids that belong to another score component, so the micronutrient rule
/// does not count them as micros.
const _notAMicro = {
  'energy',
  'protein',
  'carbs',
  'fat',
  'fibre',
  'sodium',
  'sugar',
  'saturated_fat',
};

/// The ruleset.
///
/// **Every string below has been checked against §21.7's language
/// boundary**, which is part of the definition of done for this engine
/// (§37 item 10). Concretely, that table forbids: naming a deficiency
/// ("you are deficient in iron"), judging a food or a day ("unhealthy",
/// "bad day", "you failed"), recommending supplements, claiming an
/// outcome ("this will cause..."), and any diagnosis or condition name.
/// What is left is what these say: a number, its target, and — where there
/// is one — a concrete food that would close the gap.
final List<InsightRule> insightRules = [
  InsightRule(
    id: 'data_quality.micro_coverage',
    priority: 10,
    category: InsightCategory.dataQuality,
    render: (c) {
      final micros = c.score.component(ScoreComponentKey.micronutrientCoverage);
      if (micros?.exclusion != ScoreExclusion.insufficientCoverage) return null;
      final energy = c.aggregate('energy');
      if (energy == null || energy.totalEnergyKcal <= 0) return null;
      // Mean coverage across the micros that have a target, so the number
      // describes the component the reader is looking at rather than one
      // arbitrary nutrient inside it.
      final covered = [
        for (final id in c.day.targets.keys)
          if (!_notAMicro.contains(id)) c.aggregate(id)?.coverage.fraction ?? 0,
      ];
      if (covered.isEmpty) return null;
      final pct = (covered.reduce((a, b) => a + b) / covered.length * 100)
          .round();
      return 'Micronutrients are based on $pct% of today’s food, so they '
          'are a partial picture rather than the whole day.';
    },
  ),
  InsightRule(
    id: 'data_quality.incomplete_day',
    priority: 5,
    category: InsightCategory.dataQuality,
    render: (c) =>
        c.score.withheldReason == ScoreWithheldReason.looksIncompletelyLogged
        ? 'This day looks incompletely logged — the total is well under '
              'your usual, so it has not been scored. You can add what is '
              'missing, or leave it as it is.'
        : null,
  ),
  InsightRule(
    id: 'caution.limit_exceeded',
    priority: 20,
    category: InsightCategory.caution,
    render: (c) {
      for (final id in const ['sodium', 'saturated_fat', 'sugar']) {
        final target = c.target(id);
        final aggregate = c.aggregate(id);
        if (target == null || aggregate == null || !aggregate.isScorable()) {
          continue;
        }
        if (target.curveType == TargetCurveType.ceiling &&
            aggregate.amount > target.amount) {
          return '${c.name(id)} came in at ${_fmt(aggregate.amount)} against '
              'the ${_fmt(target.amount)} daily limit.';
        }
      }
      return null;
    },
  ),
  InsightRule(
    id: 'suggest.fibre_gap',
    priority: 30,
    category: InsightCategory.suggest,
    render: (c) {
      final target = c.target('fibre');
      final aggregate = c.aggregate('fibre');
      if (target == null || aggregate == null || !aggregate.isScorable()) {
        return null;
      }
      final gap = target.amount - aggregate.amount;
      if (gap <= target.amount * 0.15) return null;
      return 'Fibre came in at ${_fmt(aggregate.amount)} g against your '
          '${_fmt(target.amount)} g target. A katori of dal or a guava would '
          'close most of it.';
    },
  ),
  InsightRule(
    id: 'inform.protein_short',
    priority: 35,
    category: InsightCategory.inform,
    render: (c) {
      final target = c.target('protein');
      final aggregate = c.aggregate('protein');
      if (target == null || aggregate == null || !aggregate.isScorable()) {
        return null;
      }
      if (aggregate.amount >= target.amount * 0.85) return null;
      return 'Protein came in at ${_fmt(aggregate.amount)} g against your '
          '${_fmt(target.amount)} g target.';
    },
  ),
  InsightRule(
    id: 'celebrate.protein_streak',
    priority: 40,
    category: InsightCategory.celebrate,
    render: (c) {
      final target = c.target('protein');
      final aggregate = c.aggregate('protein');
      if (target == null || aggregate == null) return null;
      if (aggregate.amount < target.amount) return null;
      final streak = c.consecutiveDaysProteinMet;
      if (streak < 3) {
        return 'Protein reached your ${_fmt(target.amount)} g target today.';
      }
      return '$streak days in a row hitting your protein target.';
    },
  ),
  InsightRule(
    id: 'inform.hydration_short',
    priority: 45,
    category: InsightCategory.inform,
    render: (c) {
      final target = c.day.waterTargetMl;
      final actual = c.day.waterMl;
      if (target == null || target <= 0 || actual == null) return null;
      if (actual >= target * 0.85) return null;
      final short = ((target - actual) / 1000);
      return 'Water came in ${short.toStringAsFixed(1)} L under your '
          '${(target / 1000).toStringAsFixed(1)} L target.';
    },
  ),
  InsightRule(
    id: 'inform.energy_under_band',
    priority: 50,
    category: InsightCategory.inform,
    render: (c) {
      final target = c.target('energy');
      final aggregate = c.aggregate('energy');
      if (target == null || aggregate == null || aggregate.amount <= 0) {
        return null;
      }
      if (aggregate.amount >= target.bandLow) return null;
      if (c.score.withheldReason ==
          ScoreWithheldReason.looksIncompletelyLogged) {
        return null;
      }
      return 'Energy came to ${_fmt(aggregate.amount)} kcal, below your '
          '${_fmt(target.bandLow)}–${_fmt(target.bandHigh)} kcal range '
          'for the day.';
    },
  ),
  InsightRule(
    id: 'celebrate.solid_day',
    priority: 60,
    category: InsightCategory.celebrate,
    render: (c) {
      final band = c.score.band;
      if (band != ScoreBand.excellent) return null;
      return 'Today landed close to your targets across the board.';
    },
  ),
];
