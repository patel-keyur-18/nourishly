import '../targets/target_curve_type.dart';
import 'nutrient_target.dart';

/// Scores one nutrient's intake against its target, on the 0-100 scale
/// §21.3 defines. Every curve is capped at 100 and floored at 0: the cap is
/// the anti-gaming mechanism (three times the protein target cannot buy
/// back a missing fibre target), and the floor keeps a single catastrophic
/// nutrient from dragging a component negative.
double scoreNutrient(NutrientTarget target, double intake) {
  if (target.amount <= 0) return 100;
  return switch (target.curveType) {
    TargetCurveType.range => _range(target, intake),
    TargetCurveType.floor => _floor(target, intake),
    TargetCurveType.ceiling => _ceiling(target, intake),
    TargetCurveType.plateau => _plateau(target, intake),
  };
}

/// Type 1 — a target with an acceptable band, decaying in both directions
/// but not at the same rate. Deviation is measured as a fraction of the
/// target beyond the band's edge, so the curve scales with the target
/// rather than with its units.
double _range(NutrientTarget t, double x) {
  if (x >= t.bandLow && x <= t.bandHigh) return 100;
  final (edge, decay) = x > t.bandHigh
      ? (t.bandHigh, t.overshootDecay)
      : (t.bandLow, t.shortfallDecay);
  final deviation = (x - edge).abs() / t.amount;
  return (100 - decay * deviation).clamp(0, 100);
}

/// Type 2 — "more is fine": ramps to the target, then flat. No credit above
/// it (§21.4).
double _floor(NutrientTarget t, double x) =>
    (100 * (x / t.amount)).clamp(0, 100);

/// Type 3 — a limit nutrient: full credit up to the limit, then decaying to
/// zero at twice it.
double _ceiling(NutrientTarget t, double x) {
  if (x <= t.amount) return 100;
  return (100 * (1 - (x - t.amount) / t.amount)).clamp(0, 100);
}

/// Type 4 — floor with an upper limit: ramp to the RDA, hold, then taper
/// into the UL. Falls back to a plain floor curve when no UL is known,
/// which is the honest reading of "no upper limit has been established"
/// rather than inventing one.
double _plateau(NutrientTarget t, double x) {
  final ul = t.upperLimit;
  if (ul == null || ul <= t.amount) return _floor(t, x);
  if (x < t.amount) return _floor(t, x);

  final taperStart = ul * (1 - t.plateauTaper);
  if (x <= taperStart) return 100;
  if (x >= ul) return 0;
  return (100 * (ul - x) / (ul - taperStart)).clamp(0, 100);
}
