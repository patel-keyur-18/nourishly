import 'package:meta/meta.dart';

import 'fdc_models.dart';
import 'nutrient_registry.dart';

/// One registry nutrient resolved to a value from an [FdcFood]'s reading.
@immutable
class NutrientMatch {
  const NutrientMatch({required this.nutrient, required this.amountPer100g});

  final NutrientDef nutrient;
  final double amountPer100g;
}

/// An [FdcFood] with its readings matched against [nutrientRegistry].
///
/// [matches] only ever contains nutrients FDC actually reported — a
/// registry nutrient with no matching reading is simply absent from this
/// list, never zero-filled (AP-4). [unmatchedFdcNutrients] is diagnostic:
/// FDC nutrient names present on the food that don't map to anything in
/// the registry, useful for noticing the registry is missing something.
@immutable
class ResolvedFdcFood {
  const ResolvedFdcFood({
    required this.food,
    required this.matches,
    required this.unmatchedFdcNutrients,
  });

  final FdcFood food;
  final List<NutrientMatch> matches;
  final List<String> unmatchedFdcNutrients;
}

/// Matches an [FdcFood]'s nutrient readings against [nutrientRegistry] by
/// name (and unit, to disambiguate cases like Energy's kcal/kJ split) —
/// deliberately not by FDC's numeric nutrient id, which this pipeline has
/// no live response to verify against until it actually runs (see
/// `nutrient_registry.dart`'s header comment).
class FdcNormalizer {
  ResolvedFdcFood normalize(FdcFood food) {
    final matches = <NutrientMatch>[];
    final matchedNames = <String>{};

    for (final def in nutrientRegistry) {
      for (final reading in food.nutrients) {
        if (def.fdcNames.contains(reading.name) &&
            reading.unit.toUpperCase() == def.fdcUnit) {
          matches.add(
            NutrientMatch(nutrient: def, amountPer100g: reading.amountPer100g),
          );
          matchedNames.add(reading.name);
          break;
        }
      }
    }

    final unmatched = [
      for (final r in food.nutrients)
        if (!matchedNames.contains(r.name)) r.name,
    ];

    return ResolvedFdcFood(
      food: food,
      matches: matches,
      unmatchedFdcNutrients: unmatched,
    );
  }
}
