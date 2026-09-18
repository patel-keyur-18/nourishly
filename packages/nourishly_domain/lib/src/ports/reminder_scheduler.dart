import '../reminders/reminder_rule.dart';

/// Whether the OS will let the app post a notification (§29.4, §30.5).
enum NotificationPermission {
  /// Never asked. §29.1: the ask happens when the first reminder is
  /// configured, never at launch.
  notRequested,
  granted,

  /// Denied, or revoked later in system settings. Reminder settings stay
  /// visible and explain why they are inactive, without re-prompting.
  denied,
}

/// The port behind every notification the app posts (§14.6, §29.3).
///
/// The v1.0 adapter is local notifications. There is no push adapter and
/// no server to drive one — §29.3 is explicit that adding push because a
/// backend happens to exist would be capability-driven design.
///
/// [apply] is deliberately not `schedule(one)`: the planner computes the
/// complete set of pending notifications every time, so the adapter's job
/// is to make the platform match that set. Reconciling a whole list is
/// idempotent; scheduling one at a time is not, and the duplicate
/// notification after a rebuild is the classic bug this shape avoids.
abstract interface class ReminderScheduler {
  Future<NotificationPermission> permission();

  /// Asks the OS. Call only in response to the user enabling a reminder
  /// (§29.1), never on launch.
  Future<NotificationPermission> requestPermission();

  /// Replaces every pending Nourishly notification with [reminders].
  Future<void> apply(List<ScheduledReminder> reminders);

  /// Cancels everything. §29.4's single switch.
  Future<void> cancelAll();

  /// The deep link of the notification that launched or resumed the app,
  /// consumed once (§28.5). Null when the app was opened normally.
  Future<String?> takeLaunchRoute();
}
