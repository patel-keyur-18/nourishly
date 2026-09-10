import 'package:meta/meta.dart';

/// One nutrient reading on an FDC food, as returned by either the search
/// or food-details endpoint. The two endpoints shape this differently
/// (search: flat `nutrientName`/`unitName`/`value`; details: nested
/// `nutrient: {name, unitName}` + `amount`) — [FdcNutrientReading.fromJson]
/// handles both rather than assuming one.
@immutable
class FdcNutrientReading {
  const FdcNutrientReading({
    required this.name,
    required this.unit,
    required this.amountPer100g,
  });

  final String name;
  final String unit;
  final double amountPer100g;

  static FdcNutrientReading? fromJson(Map<String, dynamic> json) {
    final nested = json['nutrient'] as Map<String, dynamic>?;
    final name = (nested?['name'] ?? json['nutrientName']) as String?;
    final unit = (nested?['unitName'] ?? json['unitName']) as String?;
    final amount = (json['amount'] ?? json['value']) as num?;
    if (name == null || unit == null || amount == null) return null;
    return FdcNutrientReading(
      name: name,
      unit: unit,
      amountPer100g: amount.toDouble(),
    );
  }
}

/// A single food record from FDC — one hit from search, or the result of
/// fetching a food by id. Per-100g values only; FDC does not report
/// per-serving amounts consistently across dataTypes, and the catalog
/// pipeline's own [CatalogSourceEntry] servings are the source of truth
/// for household portions anyway (catalog spec §0.3).
@immutable
class FdcFood {
  const FdcFood({
    required this.fdcId,
    required this.description,
    required this.dataType,
    required this.nutrients,
  });

  final int fdcId;
  final String description;

  /// `Foundation` | `SR Legacy` | `Survey (FNDDS)` | `Branded`, etc.
  final String dataType;
  final List<FdcNutrientReading> nutrients;

  static FdcFood fromJson(Map<String, dynamic> json) {
    final nutrientsJson = (json['foodNutrients'] as List?) ?? const [];
    return FdcFood(
      fdcId: json['fdcId'] as int,
      description: json['description'] as String,
      dataType: json['dataType'] as String? ?? 'unknown',
      nutrients: [
        for (final n in nutrientsJson)
          if (FdcNutrientReading.fromJson(n as Map<String, dynamic>)
              case final reading?)
            reading,
      ],
    );
  }
}
