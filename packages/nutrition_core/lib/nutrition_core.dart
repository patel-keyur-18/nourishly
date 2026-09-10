/// Nourishly's nutrition calculation core: units, nutrient values, target
/// curves, and (from Phase 2 onward) aggregation, scoring, and insights.
///
/// **Pure Dart. No Flutter, Drift, or network imports** (AP-5, §12.3) — this
/// is what keeps the calculation engine testable in milliseconds and
/// portable off the client if it's ever needed. Enforced by the `domain`
/// import-lint group in the root `import_lint.yaml`.
library;

export 'src/aggregation/coverage.dart';
export 'src/nutrients/nutrient_amount.dart';
export 'src/nutrients/nutrient_id.dart';
export 'src/targets/target_curve_type.dart';
export 'src/units/quantity.dart';
export 'src/units/unit.dart';
