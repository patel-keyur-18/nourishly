/// A port for "what time is it", so day-boundary and rollover logic (the
/// user's configurable `day_rollover_time`, §22.5 `UserPreferences`) can be
/// tested without waiting for a real day to roll over.
///
/// Every external capability sits behind a port defined in the domain
/// layer (AP-7). This is the one port worth building before it has any
/// callers: §14.6 calls it out as "valuable from day one for day-boundary
/// and rollover tests," and unlike the other ports it costs nothing to add
/// early — there's no plugin to abandon, no adapter to swap.
abstract interface class ClockPort {
  /// The current instant, in the device's local time zone.
  DateTime now();
}
