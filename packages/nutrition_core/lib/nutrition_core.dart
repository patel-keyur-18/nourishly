/// Nourishly's nutrition calculation core: units, nutrient values, target
/// derivation, aggregation, scoring, and insights.
///
/// **Pure Dart. No Flutter, Drift, or network imports** (AP-5, §12.3) — this
/// is what keeps the calculation engine testable in milliseconds and
/// portable off the client if it's ever needed. Enforced by the `domain`
/// import-lint group in the root `import_lint.yaml`.
library;

export 'src/aggregation/coverage.dart';
export 'src/aggregation/nutrient_aggregate.dart';
export 'src/insights/insight.dart';
export 'src/insights/insight_rules.dart';
export 'src/nutrients/nutrient_amount.dart';
export 'src/nutrients/nutrient_id.dart';
export 'src/scoring/curves.dart';
export 'src/scoring/daily_score.dart';
export 'src/scoring/day_scorer.dart';
export 'src/scoring/nutrient_target.dart';
export 'src/scoring/score_component.dart';
export 'src/targets/profile_inputs.dart';
export 'src/targets/target_curve_type.dart';
export 'src/targets/target_derivation.dart';
export 'src/units/quantity.dart';
export 'src/units/unit.dart';
