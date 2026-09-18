/// The reminder kinds that ship in v1.0 (§29.2).
///
/// `re_engagement` — "you have not logged for N days" — is deliberately
/// absent. §29.2 defers it to v1.1 because it is the one type that can
/// actively harm the user, and it should not ship before there is usage
/// data to tune it against.
enum ReminderType {
  /// Time-based, or after N hours without a water log.
  water('water', 'Drink water'),

  /// A user-set time per meal slot.
  meal('meal', 'Log a meal'),

  /// A configurable evening time, after rollover. The one with clear
  /// value, so it is the one that comes on by default (§29.2).
  endOfDaySummary('end_of_day_summary', 'Day summary'),

  /// Water or protein target met.
  goalAchieved('goal_achieved', 'Goal reached'),

  /// Fires on the week-start day.
  weeklyReport('weekly_report', 'Weekly report ready');

  const ReminderType(this.id, this.displayName);

  /// The value stored in `reminder_rules.type`.
  final String id;

  /// How the type is named to the user, in Settings and in the
  /// notification itself.
  final String displayName;

  static ReminderType? fromId(String? id) {
    for (final type in values) {
      if (type.id == id) return type;
    }
    return null;
  }

  /// Whether this type fires on a clock time the user picks, as opposed to
  /// being driven by inactivity or by an event.
  bool get isTimed => this != goalAchieved;

  /// §29.2's defaults. Only the end-of-day summary starts on, and even
  /// that is conditional on the user having enabled reminders at all —
  /// which [ReminderRule.enabled] carries and the master switch gates.
  bool get defaultEnabled => this == endOfDaySummary;
}
