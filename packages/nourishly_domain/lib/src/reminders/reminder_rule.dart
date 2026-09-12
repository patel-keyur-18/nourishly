import 'local_time.dart';
import 'reminder_schedule.dart';
import 'reminder_type.dart';

/// One row of `reminder_rules` (§22.5), read into the domain's own shape
/// so the planner never sees a Drift class (§13.3's dependency rule).
class ReminderRule {
  const ReminderRule({
    required this.id,
    required this.type,
    required this.schedule,
    required this.enabled,
    // §29.4 states conditionality as a rule, not a preference, so the
    // default is to stand down when the target is already met. Waiving it
    // takes an explicit [ReminderConditions.unconditional].
    this.conditions = const ReminderConditions(),
    this.quietHours,
    this.mealSlotKey,
  });

  final String id;
  final ReminderType type;

  /// Null when the stored schedule could not be read. The planner skips
  /// such a rule rather than guessing a time for it.
  final ReminderSchedule? schedule;

  final bool enabled;
  final ReminderConditions conditions;

  /// Null means "no quiet window on this rule"; the planner falls back to
  /// [QuietHours.defaults] so a rule written before quiet hours existed
  /// still behaves.
  final QuietHours? quietHours;

  /// For [ReminderType.meal] only: which slot this rule is about, so the
  /// notification can say "Log lunch" and the deep link can preselect it.
  final String? mealSlotKey;

  ReminderRule copyWith({
    ReminderSchedule? schedule,
    bool? enabled,
    ReminderConditions? conditions,
    QuietHours? quietHours,
  }) {
    return ReminderRule(
      id: id,
      type: type,
      schedule: schedule ?? this.schedule,
      enabled: enabled ?? this.enabled,
      conditions: conditions ?? this.conditions,
      quietHours: quietHours ?? this.quietHours,
      mealSlotKey: mealSlotKey,
    );
  }
}

/// What the app knows about the day when it re-plans (§29.3's "domain
/// events" input, collapsed into a snapshot).
///
/// The planner is a pure function of this plus the rules, which is what
/// makes §29.4's conditionality testable without a notification plugin.
class ReminderDayState {
  const ReminderDayState({
    required this.now,
    this.waterTargetMet = false,
    this.proteinTargetMet = false,
    this.lastWaterLoggedAt,
    this.loggedMealSlotKeys = const {},
    this.weekStartDay = DateTime.monday,
    this.dayHasEntries = false,
  });

  final DateTime now;
  final bool waterTargetMet;
  final bool proteinTargetMet;

  /// Drives [InactivitySchedule]. Null means nothing has been logged
  /// today, in which case the gap is measured from the start of the
  /// reminder's own active window rather than from an absent event.
  final DateTime? lastWaterLoggedAt;

  /// Meal slots that already have an entry today — a "log lunch" reminder
  /// at 13:30 is noise once lunch is logged.
  final Set<String> loggedMealSlotKeys;

  final int weekStartDay;

  /// Whether anything at all was logged today. The end-of-day summary has
  /// nothing to summarise on an empty day, and §29.1's "never punitive"
  /// rules out sending one that says so.
  final bool dayHasEntries;
}

/// A notification the scheduler should have pending (§29.3's port input).
class ScheduledReminder {
  const ScheduledReminder({
    required this.ruleId,
    required this.type,
    required this.when,
    required this.title,
    required this.body,
    required this.route,
  });

  final String ruleId;
  final ReminderType type;
  final DateTime when;
  final String title;

  /// §29.4: the notification carries the actual content, so it is useful
  /// even unopened.
  final String body;

  /// Where a tap lands (§28.5). A deep link, not a screen object — the
  /// domain does not know what a screen is.
  final String route;

  @override
  String toString() =>
      'ScheduledReminder(${type.id} @ $when → $route)';
}
