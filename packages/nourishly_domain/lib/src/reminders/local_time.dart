/// A wall-clock time of day, with no date and no zone attached.
///
/// The domain layer cannot use Flutter's `TimeOfDay` (§12.3 keeps it pure
/// Dart), and `Duration` is the wrong type: a reminder set for 08:30 means
/// half past eight on whatever day it lands on, not "eight and a half
/// hours after something". Minutes since local midnight is the same
/// representation `UserPreferences.dayRolloverTime` already uses, so the
/// two compare without conversion.
extension type const LocalTime(int minutesFromMidnight) {
  factory LocalTime.of(int hour, int minute) {
    assert(hour >= 0 && hour < 24, 'hour out of range: $hour');
    assert(minute >= 0 && minute < 60, 'minute out of range: $minute');
    return LocalTime(hour * 60 + minute);
  }

  /// Parses `HH:mm`. Returns null rather than throwing: these strings come
  /// out of a JSON column, and one bad row should disable one reminder,
  /// not crash the scheduler on launch.
  static LocalTime? tryParse(String? text) {
    if (text == null) return null;
    final parts = text.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return LocalTime(hour * 60 + minute);
  }

  static LocalTime fromDateTime(DateTime moment) =>
      LocalTime(moment.hour * 60 + moment.minute);

  int get hour => minutesFromMidnight ~/ 60;
  int get minute => minutesFromMidnight % 60;

  /// `HH:mm`, which is what the schema stores.
  String format() =>
      '${hour.toString().padLeft(2, '0')}:'
      '${minute.toString().padLeft(2, '0')}';

  /// This time of day on [day], in [day]'s own zone.
  DateTime onDay(DateTime day) =>
      DateTime(day.year, day.month, day.day, hour, minute);
}

/// The window in which nothing fires (§29.4).
///
/// Spans midnight in the normal case — 22:00 to 07:00 — which is why
/// [contains] cannot be a simple range check.
class QuietHours {
  const QuietHours({required this.start, required this.end});

  /// §29.4: "quiet hours are respected and default to sensible values."
  /// Ten at night until seven in the morning, which is late enough not to
  /// swallow an end-of-day summary and early enough to cover a lie-in.
  static final QuietHours defaults = QuietHours(
    start: LocalTime.of(22, 0),
    end: LocalTime.of(7, 0),
  );

  final LocalTime start;
  final LocalTime end;

  bool contains(LocalTime time) {
    final t = time.minutesFromMidnight;
    final from = start.minutesFromMidnight;
    final to = end.minutesFromMidnight;
    if (from == to) return false; // A zero-length window silences nothing.
    if (from < to) return t >= from && t < to;
    // Wraps past midnight: quiet from `from` to the end of the day, and
    // from the start of the next one until `to`.
    return t >= from || t < to;
  }

  /// The first moment at or after [moment] that is not quiet.
  ///
  /// Reminders are moved to the end of quiet hours rather than dropped:
  /// a water reminder at 06:30 is still worth having at 07:00, and
  /// silently losing one is harder to explain to a user than a slightly
  /// late one.
  DateTime nextAudibleAfter(DateTime moment) {
    if (!contains(LocalTime.fromDateTime(moment))) return moment;
    final endToday = end.onDay(moment);
    if (endToday.isAfter(moment)) return endToday;
    return end.onDay(moment.add(const Duration(days: 1)));
  }

  @override
  bool operator ==(Object other) =>
      other is QuietHours && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'QuietHours(${start.format()}–${end.format()})';
}
