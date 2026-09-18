import 'package:meta/meta.dart';

import '../aggregation/nutrient_aggregate.dart';
import '../nutrients/nutrient_id.dart';
import '../targets/target_curve_type.dart';
import 'curves.dart';
import 'daily_score.dart';
import 'nutrient_target.dart';
import 'score_component.dart';

/// The ruleset this engine implements. Bumped whenever a curve, weight or
/// gate changes, so a day keeps the score it was given rather than
/// silently acquiring a new one (§25.7).
const String scoringRulesetVersion = '1.0.0';

/// Everything scoring needs to know about a day, independent of how it was
/// stored or where it came from.
@immutable
class DayForScoring {
  const DayForScoring({
    required this.nutrients,
    required this.targets,
    required this.goal,
    required this.isComplete,
    this.waterMl,
    this.waterTargetMl,
  });

  /// Keyed by nutrient id. A nutrient absent from this map was not reported
  /// by anything logged.
  final Map<NutrientId, NutrientAggregate> nutrients;

  /// Keyed by nutrient id. Absent means no target, which excludes the
  /// nutrient from scoring rather than defaulting it.
  final Map<NutrientId, NutrientTarget> targets;

  final GoalType goal;

  /// False while the day is still running (§21.5's day-completeness gate).
  final bool isComplete;

  final double? waterMl;
  final double? waterTargetMl;

  double get totalEnergyKcal => nutrients['energy']?.amount ?? 0;
  double? get energyTarget => targets['energy']?.amount;
}

/// Turns a day into sub-scores and a composite (§21.4-21.6).
///
/// The gates run before the arithmetic, because most of the value here is
/// in refusing to score things that cannot honestly be scored. A day
/// missing its dinner is the single most common source of a false signal
/// in nutrition apps, and it is indistinguishable from a real deficit
/// unless you check for it explicitly.
DailyScore scoreDay(DayForScoring day) {
  final weights = ScoreWeights.forGoal(day.goal);

  final withheld = _withholdReason(day);
  final components = [
    _energyComponent(day, weights),
    _macroComponent(day, weights),
    _microComponent(day, weights),
    _limitComponent(day, weights),
    _hydrationComponent(day, weights),
  ];

  return DailyScore.from(components, withheld: withheld);
}

/// A day logged at less than this fraction of its energy target is treated
/// as incompletely logged rather than as a severe deficit (§21.5).
const double implausiblyLowEnergyFraction = 0.40;

ScoreWithheldReason? _withholdReason(DayForScoring day) {
  if (day.targets.isEmpty) return ScoreWithheldReason.noTargets;
  if (!day.isComplete) return ScoreWithheldReason.dayIncomplete;
  if (day.totalEnergyKcal <= 0) return ScoreWithheldReason.nothingLogged;

  final energyTarget = day.energyTarget;
  if (energyTarget != null &&
      energyTarget > 0 &&
      day.totalEnergyKcal < energyTarget * implausiblyLowEnergyFraction) {
    return ScoreWithheldReason.looksIncompletelyLogged;
  }
  return null;
}

ScoredComponent _excluded(
  ScoreComponentKey key,
  double weight,
  ScoreExclusion reason,
) => ScoredComponent(
  key: key,
  score: null,
  weight: weight,
  appliedWeight: 0,
  exclusion: reason,
);

ScoredComponent _energyComponent(DayForScoring day, ScoreWeights w) {
  final weight = w[ScoreComponentKey.energyAdherence];
  final target = day.targets['energy'];
  final aggregate = day.nutrients['energy'];
  if (target == null) {
    return _excluded(
      ScoreComponentKey.energyAdherence,
      weight,
      ScoreExclusion.noTarget,
    );
  }
  if (aggregate == null) {
    return _excluded(
      ScoreComponentKey.energyAdherence,
      weight,
      ScoreExclusion.noData,
    );
  }
  return ScoredComponent(
    key: ScoreComponentKey.energyAdherence,
    score: scoreNutrient(target, aggregate.amount),
    weight: weight,
    appliedWeight: weight,
  );
}

/// Protein, fibre, fat and carbs, sub-weighted within the component. A
/// macro with no target or no data drops out and its sub-weight is
/// redistributed, on the same principle as the components themselves.
ScoredComponent _macroComponent(DayForScoring day, ScoreWeights w) {
  final weight = w[ScoreComponentKey.macroBalance];
  var totalSubWeight = 0.0;
  var accumulated = 0.0;

  w.macroSubWeights.forEach((nutrientId, subWeight) {
    final target = day.targets[nutrientId];
    final aggregate = day.nutrients[nutrientId];
    if (target == null || aggregate == null || !aggregate.isScorable()) return;
    totalSubWeight += subWeight;
    accumulated += subWeight * scoreNutrient(target, aggregate.amount);
  });

  if (totalSubWeight <= 0) {
    return _excluded(
      ScoreComponentKey.macroBalance,
      weight,
      ScoreExclusion.noData,
    );
  }
  return ScoredComponent(
    key: ScoreComponentKey.macroBalance,
    score: accumulated / totalSubWeight,
    weight: weight,
    appliedWeight: weight,
  );
}

/// The fraction of scorable micronutrients that must clear the coverage
/// gate before the component is scored at all (§21.5).
const double minMicronutrientsClearingGate = 0.60;

/// Mean of the micros that cleared their coverage gate. If fewer than 60%
/// of them cleared it, the whole component is excluded rather than
/// reporting an average of the third of the day that happened to be
/// measured.
ScoredComponent _microComponent(DayForScoring day, ScoreWeights w) {
  final weight = w[ScoreComponentKey.micronutrientCoverage];
  final micros = day.targets.entries
      .where(
        (e) =>
            !_macroIds.contains(e.key) &&
            !_limitIds.contains(e.key) &&
            e.key != 'energy',
      )
      .toList();
  if (micros.isEmpty) {
    return _excluded(
      ScoreComponentKey.micronutrientCoverage,
      weight,
      ScoreExclusion.noTarget,
    );
  }

  final scores = <double>[];
  for (final entry in micros) {
    final aggregate = day.nutrients[entry.key];
    if (aggregate == null || !aggregate.isScorable()) continue;
    scores.add(scoreNutrient(entry.value, aggregate.amount));
  }

  if (scores.length / micros.length < minMicronutrientsClearingGate) {
    return _excluded(
      ScoreComponentKey.micronutrientCoverage,
      weight,
      ScoreExclusion.insufficientCoverage,
    );
  }
  return ScoredComponent(
    key: ScoreComponentKey.micronutrientCoverage,
    score: scores.reduce((a, b) => a + b) / scores.length,
    weight: weight,
    appliedWeight: weight,
  );
}

ScoredComponent _limitComponent(DayForScoring day, ScoreWeights w) {
  final weight = w[ScoreComponentKey.limitNutrients];
  final scores = <double>[];
  for (final id in _limitIds) {
    final target = day.targets[id];
    final aggregate = day.nutrients[id];
    if (target == null || aggregate == null || !aggregate.isScorable()) {
      continue;
    }
    scores.add(scoreNutrient(target, aggregate.amount));
  }
  if (scores.isEmpty) {
    return _excluded(
      ScoreComponentKey.limitNutrients,
      weight,
      ScoreExclusion.noData,
    );
  }
  return ScoredComponent(
    key: ScoreComponentKey.limitNutrients,
    score: scores.reduce((a, b) => a + b) / scores.length,
    weight: weight,
    appliedWeight: weight,
  );
}

ScoredComponent _hydrationComponent(DayForScoring day, ScoreWeights w) {
  final weight = w[ScoreComponentKey.hydration];
  final target = day.waterTargetMl;
  if (target == null || target <= 0) {
    return _excluded(
      ScoreComponentKey.hydration,
      weight,
      ScoreExclusion.noTarget,
    );
  }
  return ScoredComponent(
    key: ScoreComponentKey.hydration,
    score: scoreNutrient(
      NutrientTarget(
        nutrientId: 'water',
        curveType: TargetCurveType.floor,
        amount: target,
      ),
      day.waterMl ?? 0,
    ),
    weight: weight,
    appliedWeight: weight,
  );
}

const _macroIds = {'protein', 'carbs', 'fat', 'fibre'};

/// §21.4's limit component. Saturated fat and added sugar sit here rather
/// than with the macros because they are scored as ceilings, not floors.
const _limitIds = {'sodium', 'sugar', 'saturated_fat'};
