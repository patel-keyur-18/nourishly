import 'clock_port.dart';

/// A settable [ClockPort] for tests — day-boundary, rollover, and
/// effective-dated target logic (I-3) all need to pin "now" to exact
/// instants around midnight and the user's rollover time.
///
/// Exported from the package (not left in `test/`) so every feature's test
/// suite can depend on it without reaching into `nourishly_domain`'s own
/// tests.
class FakeClock implements ClockPort {
  FakeClock([DateTime? initial]) : _now = initial ?? DateTime(2026, 1, 1);

  DateTime _now;

  @override
  DateTime now() => _now;

  /// Sets the clock to an exact instant.
  void set(DateTime value) => _now = value;

  /// Moves the clock forward (or, with a negative duration, backward).
  void advance(Duration duration) => _now = _now.add(duration);
}
