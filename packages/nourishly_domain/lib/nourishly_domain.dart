/// Nourishly's domain layer: entities, value objects, and repository/service
/// ports (§12.3, §14.3).
///
/// **Pure Dart. No Flutter, Drift, or network imports** — enforced by the
/// `domain` import-lint group in the root `import_lint.yaml`. Data
/// implements these ports; the domain never names a concrete data class
/// (§13.3's dependency rule).
///
/// Entities and most ports arrive alongside the features that need them
/// (§14.4: "if two features need a type, it belongs in the shared domain
/// package"). [ClockPort] ships from Phase 1 because day-boundary logic
/// needs it testable from the first date-handling feature onward (§14.6).
/// Phase 5 adds the reminder model and [ReminderScheduler] (§29): the
/// rules about what fires and when are the part worth testing, and they
/// belong nowhere near a notification plugin.
library;

export 'src/ports/clock_port.dart';
export 'src/ports/fake_clock.dart';
export 'src/ports/reminder_scheduler.dart';
export 'src/ports/system_clock.dart';
export 'src/reminders/local_time.dart';
export 'src/reminders/reminder_planner.dart';
export 'src/reminders/reminder_rule.dart';
export 'src/reminders/reminder_schedule.dart';
export 'src/reminders/reminder_type.dart';
