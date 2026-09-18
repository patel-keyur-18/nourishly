/// The canonical units nutrient amounts and quantities are expressed in.
///
/// Every [Nutrient] row names one of these as its canonical unit (§22.5),
/// and every stored [NutrientAmount] is in that unit — never a display
/// unit. Unit conversion for display (e.g. water in litres vs. fluid
/// ounces) is a presentation concern (§20.6) and does not live here.
enum Unit {
  kcal,
  gram,
  milligram,
  microgram,
  milliliter,
  liter;

  /// The symbol used in nutrient displays and canonical-unit configuration,
  /// matching the tokens used throughout the architecture docs (`g`, `mg`,
  /// `ug`, `kcal`).
  String get symbol => switch (this) {
    Unit.kcal => 'kcal',
    Unit.gram => 'g',
    Unit.milligram => 'mg',
    Unit.microgram => 'ug',
    Unit.milliliter => 'ml',
    Unit.liter => 'L',
  };
}
