import 'dart:convert';

import 'local_time.dart';

/// When a reminder wants to fire (§22.5 `reminder_rules.schedule`).
///
/// Stored as JSON in one text column rather than as a set of nullable
/// columns, because the two shapes share almost nothing: a daily reminder
/// has a time and a day mask, an inactivity reminder has a gap and an
/// active window. Nullable columns for both would let the schema express
/// combinations that mean nothing.
sealed class ReminderSchedule {
  const ReminderSchedule();

  /// Decodes the stored column. Returns null for anything unreadable —
  /// see [LocalTime.tryParse] for why this does not throw.
  static ReminderSchedule? tryDecode(String? source) {
    if (source == null || source.isEmpty) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, Object?>) return null;
    return switch (decoded['kind']) {
      'daily' => DailySchedule._tryFrom(decoded),
      'after_inactivity' => InactivitySchedule._tryFrom(decoded),
      _ => null,
    };
  }

  Map<String, Object?> toMap();

  String encode() => jsonEncode(toMap());
}

/// A clock time on a chosen set of weekdays.
class DailySchedule extends ReminderSchedule {
  DailySchedule({required this.time, Set<int>? weekdays})
    : weekdays = {...weekdays ?? _everyDay}
        ..removeWhere((day) => day < DateTime.monday || day > DateTime.sunday);

  static const _everyDay = {1, 2, 3, 4, 5, 6, 7};

  static DailySchedule? _tryFrom(Map<String, Object?> map) {
    final time = LocalTime.tryParse(map['time'] as String?);
    if (time == null) return null;
    final rawDays = map['weekdays'];
    return DailySchedule(
      time: time,
      weekdays: rawDays is List
          ? {
              for (final day in rawDays)
                if (day is int) day else if (day is num) day.toInt(),
            }
          : null,
    );
  }

  final LocalTime time;

  /// ISO weekday numbers, 1 (Monday) – 7 (Sunday). Empty means the rule
  /// can never fire, which [ReminderPlanner] treats as off rather than as
  /// an error — a user who unticks every day has said something clear.
  final Set<int> weekdays;

  bool firesOn(DateTime day) => weekdays.contains(day.weekday);

  @override
  Map<String, Object?> toMap() => {
    'kind': 'daily',
    'time': time.format(),
    'weekdays': (weekdays.toList()..sort()),
  };
}

/// "Nudge me if I have not logged for N hours", bounded to a waking
/// window so it cannot chase the user through the night (§29.2's water
/// reminder, second form).
class InactivitySchedule extends ReminderSchedule {
  const InactivitySchedule({
    required this.gap,
    required this.windowStart,
    required this.windowEnd,
  });

  static InactivitySchedule? _tryFrom(Map<String, Object?> map) {
    final hours = map['hours'];
    if (hours is! num || hours <= 0) return null;
    return InactivitySchedule(
      gap: Duration(minutes: (hours * 60).round()),
      windowStart:
          LocalTime.tryParse(map['from'] as String?) ?? LocalTime.of(8, 0),
      windowEnd:
          LocalTime.tryParse(map['to'] as String?) ?? LocalTime.of(21, 0),
    );
  }

  final Duration gap;
  final LocalTime windowStart;
  final LocalTime windowEnd;

  /// The moment this schedule wants to fire, given when the thing it
  /// watches last happened. Clamped into the active window: a gap that
  /// lands at 03:00 becomes the window's opening time instead.
  DateTime nextAfter(DateTime lastActivity) {
    final due = lastActivity.add(gap);
    final dueTime = LocalTime.fromDateTime(due);
    if (dueTime.minutesFromMidnight < windowStart.minutesFromMidnight) {
      return windowStart.onDay(due);
    }
    if (dueTime.minutesFromMidnight >= windowEnd.minutesFromMidnight) {
      return windowStart.onDay(due.add(const Duration(days: 1)));
    }
    return due;
  }

  @override
  Map<String, Object?> toMap() => {
    'kind': 'after_inactivity',
    'hours': gap.inMinutes / 60,
    'from': windowStart.format(),
    'to': windowEnd.format(),
  };
}

/// The firing conditions in `reminder_rules.conditions` (§29.4).
///
/// Only one condition exists, and it is the one that matters: **do not
/// fire if the thing being reminded about is already done.** §29.4 puts it
/// plainly — "firing irrelevant reminders is the fastest route to being
/// muted".
class ReminderConditions {
  const ReminderConditions({this.skipIfTargetMet = true});

  static const unconditional = ReminderConditions(skipIfTargetMet: false);

  static ReminderConditions decode(String? source) {
    if (source == null || source.isEmpty) return unconditional;
    try {
      final decoded = jsonDecode(source);
      if (decoded is! Map<String, Object?>) return unconditional;
      return ReminderConditions(
        skipIfTargetMet: decoded['skip_if_target_met'] == true,
      );
    } on FormatException {
      return unconditional;
    }
  }

  final bool skipIfTargetMet;

  String encode() => jsonEncode({'skip_if_target_met': skipIfTargetMet});

  @override
  bool operator ==(Object other) =>
      other is ReminderConditions && other.skipIfTargetMet == skipIfTargetMet;

  @override
  int get hashCode => skipIfTargetMet.hashCode;
}
