import 'local_time.dart';
import 'reminder_rule.dart';
import 'reminder_schedule.dart';
import 'reminder_type.dart';

/// Turns reminder rules plus the state of the day into the exact set of
/// notifications that should be pending (§29.3, §29.4).
///
/// Pure, and deliberately the whole of the decision-making: the local
/// notifications adapter does nothing but hand this list to the platform.
/// Every rule §29 states — conditionality, quiet hours, the daily cap,
/// the master switch — is enforced here, where it can be tested without a
/// device.
class ReminderPlanner {
  const ReminderPlanner({this.dailyCap = 4});

  /// §29.1: "a hard default cap of 3–4 per day." Four, because the five
  /// types cannot all be useful on the same day and the cap is what stops
  /// the app from proving otherwise.
  final int dailyCap;

  /// The notifications that should be pending, soonest first.
  ///
  /// [masterEnabled] is §29.4's single switch: off, and the list is empty
  /// and the app stays fully functional. [summaryLine] supplies the
  /// end-of-day headline, which only the caller can compute — it reads a
  /// day summary, and the domain does not depend on the scoring engine.
  List<ScheduledReminder> plan({
    required List<ReminderRule> rules,
    required ReminderDayState state,
    required bool masterEnabled,
    String? summaryLine,
  }) {
    if (!masterEnabled) return const [];

    final planned = <ScheduledReminder>[];
    for (final rule in rules) {
      if (!rule.enabled) continue;
      final reminder = _planOne(rule, state, summaryLine);
      if (reminder != null) planned.add(reminder);
    }

    planned.sort((a, b) => a.when.compareTo(b.when));

    // The cap is per day, not per plan: a plan covering a Friday evening
    // and a Saturday morning is two days and may legitimately hold more
    // than [dailyCap] entries.
    final perDay = <DateTime, int>{};
    final kept = <ScheduledReminder>[];
    for (final reminder in planned) {
      final day = DateTime(
        reminder.when.year,
        reminder.when.month,
        reminder.when.day,
      );
      final count = perDay[day] ?? 0;
      if (count >= dailyCap) continue;
      perDay[day] = count + 1;
      kept.add(reminder);
    }
    return kept;
  }

  ScheduledReminder? _planOne(
    ReminderRule rule,
    ReminderDayState state,
    String? summaryLine,
  ) {
    final schedule = rule.schedule;
    if (schedule == null) return null;

    // §29.4's conditionality, applied before a time is even computed: a
    // reminder that would be irrelevant is not scheduled late, it is not
    // scheduled.
    //
    // Two kinds of irrelevance, and only one of them is the user's to
    // waive. A notification with *nothing to say* is never sent — an
    // end-of-day summary of an empty day would be a notification that the
    // user did not log, which is exactly the punitive framing §29.1 rules
    // out. A notification about a target that is *already met* is the
    // user's call: the default is to stand down, and switching that off
    // is a deliberate "remind me anyway".
    if (_hasNothingToSay(rule, state)) return null;
    if (rule.conditions.skipIfTargetMet && _alreadyDone(rule, state)) {
      return null;
    }

    final DateTime? due = switch (schedule) {
      DailySchedule() => _nextDailyOccurrence(rule, schedule, state),
      InactivitySchedule() => _nextInactivityOccurrence(schedule, state),
    };
    if (due == null) return null;

    final quiet = rule.quietHours ?? QuietHours.defaults;
    final when = quiet.nextAudibleAfter(due);

    final (title, body) = _copyFor(rule, state, summaryLine);
    return ScheduledReminder(
      ruleId: rule.id,
      type: rule.type,
      when: when,
      title: title,
      body: body,
      route: _routeFor(rule),
    );
  }

  /// Irrelevance the user cannot waive: the notification would have no
  /// content, or its content would be an observation about not logging.
  bool _hasNothingToSay(ReminderRule rule, ReminderDayState state) {
    return switch (rule.type) {
      ReminderType.endOfDaySummary => !state.dayHasEntries,
      // The inverse of the others: this one fires *because* a target was
      // met, so an unmet target is what leaves it with nothing to say.
      ReminderType.goalAchieved =>
        !(state.waterTargetMet || state.proteinTargetMet),
      _ => false,
    };
  }

  /// Irrelevance the user may waive with `skip_if_target_met: false` —
  /// the thing being nudged about is already done today.
  bool _alreadyDone(ReminderRule rule, ReminderDayState state) {
    return switch (rule.type) {
      ReminderType.water => state.waterTargetMet,
      ReminderType.meal =>
        rule.mealSlotKey != null &&
            state.loggedMealSlotKeys.contains(rule.mealSlotKey),
      _ => false,
    };
  }

  DateTime? _nextDailyOccurrence(
    ReminderRule rule,
    DailySchedule schedule,
    ReminderDayState state,
  ) {
    if (schedule.weekdays.isEmpty) return null;
    // The weekly report is pinned to the profile's own week-start day
    // rather than to whatever day mask happens to be stored, so changing
    // "week starts on" in Settings moves the reminder with it.
    final allowed = rule.type == ReminderType.weeklyReport
        ? {state.weekStartDay}
        : schedule.weekdays;

    for (var offset = 0; offset <= 7; offset++) {
      final day = state.now.add(Duration(days: offset));
      if (!allowed.contains(day.weekday)) continue;
      final at = schedule.time.onDay(day);
      if (at.isAfter(state.now)) return at;
    }
    return null;
  }

  DateTime? _nextInactivityOccurrence(
    InactivitySchedule schedule,
    ReminderDayState state,
  ) {
    // No water logged yet today: measure the gap from when the window
    // opened, not from an event that never happened. Otherwise a user who
    // has not drunk anything would be the one person the water reminder
    // never reaches.
    final anchor =
        state.lastWaterLoggedAt ?? schedule.windowStart.onDay(state.now);
    final due = schedule.nextAfter(anchor);
    return due.isAfter(state.now) ? due : schedule.nextAfter(state.now);
  }

  /// §21.7's language boundary applies to notification copy too (§29.4):
  /// no diagnosis, no praise for restriction, no guilt for a missed day.
  /// These read as statements of fact with a suggested action at most.
  (String, String) _copyFor(
    ReminderRule rule,
    ReminderDayState state,
    String? summaryLine,
  ) {
    return switch (rule.type) {
      ReminderType.water => (
        'Water',
        'A glass of water if you have not had one.',
      ),
      ReminderType.meal => (
        'Log ${_mealName(rule.mealSlotKey)}',
        'Add what you ate while you remember it.',
      ),
      ReminderType.endOfDaySummary => (
        'Today so far',
        summaryLine ?? 'Your day is ready to look at.',
      ),
      ReminderType.goalAchieved => (
        'Target met',
        state.waterTargetMet
            ? 'You have reached your water target for today.'
            : 'You have reached your protein target for today.',
      ),
      ReminderType.weeklyReport => (
        'Your week is ready',
        'Seven days of logging, summarised.',
      ),
    };
  }

  /// §28.5: a tap lands on the right screen, and for a dated screen on the
  /// right date.
  String _routeFor(ReminderRule rule) => switch (rule.type) {
    ReminderType.water => '/water',
    ReminderType.meal => '/log',
    ReminderType.endOfDaySummary => '/today/report',
    ReminderType.goalAchieved => '/today',
    ReminderType.weeklyReport => '/insights/week',
  };

  static String _mealName(String? slotKey) => switch (slotKey) {
    'breakfast' => 'breakfast',
    'lunch' => 'lunch',
    'dinner' => 'dinner',
    'snack' => 'a snack',
    _ => 'a meal',
  };
}
