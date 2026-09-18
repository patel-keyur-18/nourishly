import 'clock_port.dart';

/// The real [ClockPort] adapter, backed by the system clock. Wired at the
/// composition root (`app/lib/main.dart`); nothing in the domain or
/// application layers constructs this directly.
class SystemClock implements ClockPort {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}
