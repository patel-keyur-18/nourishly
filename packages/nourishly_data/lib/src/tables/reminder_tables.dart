import 'package:drift/drift.dart';

import 'common.dart';

/// Reminder type, schedule, conditions, and quiet hours (§22.5, §29).
/// Ships in v1.0 as a purely local table — the [ReminderScheduler] port
/// (§14.6) has a local-notifications adapter only; there is no server to
/// sync this against in the personal-use scope, so the "syncable" note in
/// §22.5 no longer applies.
class ReminderRules extends Table with Identifiable, Owned, Timestamped {
  /// `water` | `meal` | `end_of_day_summary` | `goal_achieved` | `weekly_report`.
  TextColumn get type => text()();

  /// JSON-encoded schedule (time-of-day, days, or an "after N hours" rule).
  TextColumn get schedule => text()();
  BoolColumn get enabled => boolean().withDefault(const Constant(false))();

  /// JSON-encoded firing conditions, e.g. "skip if today's water target is
  /// already met" (§29.4) — null means unconditional.
  TextColumn get conditions => text().nullable()();

  /// `HH:mm`, local time.
  TextColumn get quietHoursStart => text().nullable()();
  TextColumn get quietHoursEnd => text().nullable()();
}
