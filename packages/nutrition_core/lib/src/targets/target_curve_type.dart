/// How a [NutrientTarget] amount should be interpreted when scoring or
/// displaying progress (§22.5 `NutrientTarget.curve_type`).
///
/// This is vocabulary only. The curves themselves — how a `floor` nutrient
/// like fibre scores below target versus how a `ceiling` nutrient like
/// sodium scores above it — are content defined in §21 and are not
/// implemented until the scoring engine ships in Phase 3, after the
/// nutrition review packet (§0.6).
enum TargetCurveType {
  /// Scored well within a band around the target; both too little and too
  /// much matter (e.g. energy).
  range,

  /// Scored against a minimum; more is never penalised (e.g. protein, fibre).
  floor,

  /// Scored against a maximum; less is never penalised (e.g. sodium, sugar).
  ceiling,

  /// Scored well anywhere past a threshold, with no further credit beyond it.
  plateau,
}
