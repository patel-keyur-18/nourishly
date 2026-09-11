import 'package:meta/meta.dart';

import '../nutrients/nutrient_id.dart';
import 'coverage.dart';

/// A day's total for one nutrient, carrying what is *not* known alongside
/// what is (§20.8).
///
/// Three numbers instead of one, because a sum on its own cannot tell the
/// difference between "you ate 4 mg of iron" and "you ate 4 mg of iron in
/// the third of your food that reports iron". Conflating those is why most
/// nutrition apps report deficiencies that are not there.
@immutable
class NutrientAggregate {
  const NutrientAggregate({
    required this.nutrientId,
    required this.amount,
    required this.knownEnergyKcal,
    required this.totalEnergyKcal,
  });

  final NutrientId nutrientId;

  /// Summed over the entries that actually have a value. An entry with no
  /// value for this nutrient contributes to [totalEnergyKcal] and nothing
  /// else — never a zero (AP-4).
  final double amount;

  /// Energy from the foods that reported this nutrient.
  final double knownEnergyKcal;

  /// Energy from everything logged that day.
  final double totalEnergyKcal;

  /// Energy-weighted, not entry-counted: one large unmeasured meal matters
  /// more than three small measured snacks.
  Coverage get coverage => totalEnergyKcal <= 0
      ? Coverage.none
      : Coverage((knownEnergyKcal / totalEnergyKcal).clamp(0, 1));

  /// The default gate from §20.8. Below it the nutrient is reported as
  /// insufficient data rather than as a number, and is left out of scoring.
  static const double defaultMinCoverage = 0.60;

  bool isScorable({double minCoverage = defaultMinCoverage}) =>
      totalEnergyKcal > 0 && coverage.fraction >= minCoverage;

  @override
  String toString() =>
      'NutrientAggregate($nutrientId, $amount, coverage $coverage)';
}

/// Where a nutrient's intake sits against its target, for display (§22.5
/// `DailySummaryNutrient.status`).
enum NutrientStatus {
  below('below'),
  within('within'),
  above('above'),

  /// Not enough of the day's food reports this nutrient to say anything
  /// (§21.5). Renders as "—", never as zero.
  insufficientData('insufficient_data');

  const NutrientStatus(this.id);

  final String id;

  static NutrientStatus fromId(String id) =>
      values.firstWhere((s) => s.id == id);
}
