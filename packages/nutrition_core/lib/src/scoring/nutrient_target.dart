import 'package:meta/meta.dart';

import '../nutrients/nutrient_id.dart';
import '../targets/target_curve_type.dart';

/// One nutrient's target and the shape of the curve it is scored against
/// (§22.5 `NutrientTarget`).
///
/// The curve parameters live here rather than in the scoring code because
/// §21.3 requires them to be data: they are persisted per target set and
/// versioned under `rulesetVersion`, so a day scored last month can be
/// re-explained with the parameters it was actually scored against.
@immutable
class NutrientTarget {
  const NutrientTarget({
    required this.nutrientId,
    required this.curveType,
    required this.amount,
    this.upperLimit,
    this.tolerance = defaultTolerance,
    this.plateauTaper = defaultPlateauTaper,
    this.overshootDecay = defaultOvershootDecay,
    this.shortfallDecay = defaultShortfallDecay,
    this.isUserOverride = false,
  });

  /// Half-width of a [TargetCurveType.range] band, as a fraction of the
  /// target. §21.3's stated default for energy.
  static const double defaultTolerance = 0.1;

  /// Where a [TargetCurveType.plateau] curve starts falling, as a fraction
  /// of the upper limit below it: 0.2 means full credit up to 80% of the
  /// UL, zero at the UL.
  ///
  /// §21.3 draws the plateau ending before the UL and the curve reaching
  /// the floor around it, but names no width. This default draws that
  /// shape; it is a parameter so a reviewed ruleset can move it without a
  /// code change.
  static const double defaultPlateauTaper = 0.2;

  /// Points lost per 1.0 of target overshot beyond a range band.
  static const double defaultOvershootDecay = 200;

  /// Points lost per 1.0 of target undershot beyond a range band.
  ///
  /// Deliberately gentler than [defaultOvershootDecay] — §21.3 asks for an
  /// asymmetric energy curve, and §21.8 requires that eating far under
  /// still costs points, so this softens the slope without flattening it.
  static const double defaultShortfallDecay = 150;

  final NutrientId nutrientId;
  final TargetCurveType curveType;

  /// The target itself: the point for [TargetCurveType.range], the minimum
  /// for [TargetCurveType.floor] and [TargetCurveType.plateau], the limit
  /// for [TargetCurveType.ceiling].
  final double amount;

  /// Tolerable upper intake level, required by [TargetCurveType.plateau].
  final double? upperLimit;

  final double tolerance;
  final double plateauTaper;
  final double overshootDecay;
  final double shortfallDecay;

  /// True when the user set this themselves, so recomputing targets from a
  /// new profile leaves it alone (FR-U-05).
  final bool isUserOverride;

  double get bandLow => amount * (1 - tolerance);
  double get bandHigh => amount * (1 + tolerance);

  NutrientTarget copyWith({double? amount, bool? isUserOverride}) =>
      NutrientTarget(
        nutrientId: nutrientId,
        curveType: curveType,
        amount: amount ?? this.amount,
        upperLimit: upperLimit,
        tolerance: tolerance,
        plateauTaper: plateauTaper,
        overshootDecay: overshootDecay,
        shortfallDecay: shortfallDecay,
        isUserOverride: isUserOverride ?? this.isUserOverride,
      );

  @override
  String toString() =>
      'NutrientTarget($nutrientId, ${curveType.name}, $amount'
      '${upperLimit != null ? ', UL $upperLimit' : ''})';
}
