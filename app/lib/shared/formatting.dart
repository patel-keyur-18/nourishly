/// Number and name formatting shared by the dashboard, the report and the
/// goals screen, so the same quantity reads the same way wherever it
/// appears.
library;

/// "2,245" — the prototype's thousands separator.
String formatThousands(num value) {
  final rounded = value.round();
  final negative = rounded < 0;
  final digits = rounded.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return negative ? '-$buffer' : buffer.toString();
}

/// The catalog's display names are written for a nutrient list, not for a
/// 70px column: "Dietary fibre" and "Carbohydrate" truncate mid-word in
/// every bar and table row, which reads as a rendering bug rather than as
/// a long name.
String shortNutrientName(String displayName) => switch (displayName) {
  'Dietary fibre' => 'Fibre',
  'Carbohydrate' => 'Carbs',
  'Total fat' => 'Fat',
  'Saturated fat' => 'Sat fat',
  _ => displayName,
};
