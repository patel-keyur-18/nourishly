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

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const _monthsShort = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const _monthsLong = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// "Thursday, 9 Sep" — the prototype's date format.
String formatLongDate(DateTime date) =>
    '${_weekdays[date.weekday - 1]}, ${date.day} ${monthAbbreviation(date.month)}';

/// "Sep". [month] is 1-based, as `DateTime.month` is.
String monthAbbreviation(int month) => _monthsShort[month - 1];

/// "September".
String monthName(int month) => _monthsLong[month - 1];

/// "Thursday".
String weekdayName(int weekday) => _weekdays[weekday - 1];

/// The single letter under a bar in a week chart: M T W T F S S.
String weekdayInitial(int weekday) => _weekdays[weekday - 1][0];

String relativeDayLabel(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);
  final difference = today.difference(target).inDays;
  return switch (difference) {
    0 => 'Today',
    1 => 'Yesterday',
    _ => '$difference days ago',
  };
}
