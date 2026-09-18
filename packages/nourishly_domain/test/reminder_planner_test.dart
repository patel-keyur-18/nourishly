import 'package:nourishly_domain/nourishly_domain.dart';
import 'package:test/test.dart';

/// §29.4's behavioural requirements, one test each. These are the rules
/// that decide whether the app is useful or muted, and none of them needs
/// a notification plugin to check.
void main() {
  // A Wednesday.
  final now = DateTime(2026, 9, 9, 10, 0);

  ReminderRule water({
    bool enabled = true,
    bool skipIfMet = true,
    ReminderSchedule? schedule,
  }) => ReminderRule(
    id: 'r-water',
    type: ReminderType.water,
    enabled: enabled,
    conditions: ReminderConditions(skipIfTargetMet: skipIfMet),
    schedule: schedule ?? DailySchedule(time: LocalTime.of(15, 0)),
  );

  ReminderRule meal(String slot, int hour) => ReminderRule(
    id: 'r-$slot',
    type: ReminderType.meal,
    enabled: true,
    mealSlotKey: slot,
    schedule: DailySchedule(time: LocalTime.of(hour, 0)),
  );

  ReminderRule summary({int hour = 21}) => ReminderRule(
    id: 'r-eod',
    type: ReminderType.endOfDaySummary,
    enabled: true,
    schedule: DailySchedule(time: LocalTime.of(hour, 0)),
  );

  group('conditionality', () {
    test('a water reminder does not fire once the goal is met', () {
      final plan = const ReminderPlanner().plan(
        rules: [water()],
        state: ReminderDayState(now: now, waterTargetMet: true),
        masterEnabled: true,
      );
      expect(plan, isEmpty);
    });

    test('it does fire when the goal is still short', () {
      final plan = const ReminderPlanner().plan(
        rules: [water()],
        state: ReminderDayState(now: now),
        masterEnabled: true,
      );
      expect(plan.single.type, ReminderType.water);
      expect(plan.single.when, DateTime(2026, 9, 9, 15, 0));
    });

    test('a meal reminder stands down once that slot is logged', () {
      final state = ReminderDayState(
        now: now,
        loggedMealSlotKeys: const {'lunch'},
      );
      final plan = const ReminderPlanner().plan(
        rules: [meal('lunch', 13), meal('dinner', 20)],
        state: state,
        masterEnabled: true,
      );
      expect(plan.map((r) => r.ruleId), ['r-dinner']);
    });

    test('the end-of-day summary is silent on a day with nothing in it', () {
      // §29.1: never punitive. A notification whose content would be
      // "you logged nothing" is the one this rule exists to prevent.
      final plan = const ReminderPlanner().plan(
        rules: [summary()],
        state: ReminderDayState(now: now),
        masterEnabled: true,
      );
      expect(plan, isEmpty);
    });
  });

  group('quiet hours', () {
    test('default to 22:00–07:00 and span midnight', () {
      final quiet = QuietHours.defaults;
      expect(quiet.contains(LocalTime.of(23, 30)), isTrue);
      expect(quiet.contains(LocalTime.of(2, 0)), isTrue);
      expect(quiet.contains(LocalTime.of(6, 59)), isTrue);
      expect(quiet.contains(LocalTime.of(7, 0)), isFalse);
      expect(quiet.contains(LocalTime.of(21, 59)), isFalse);
    });

    test('a reminder inside the window moves to the end of it, not away', () {
      final plan = const ReminderPlanner().plan(
        rules: [
          ReminderRule(
            id: 'r-water',
            type: ReminderType.water,
            enabled: true,
            schedule: DailySchedule(time: LocalTime.of(23, 0)),
            conditions: ReminderConditions.unconditional,
          ),
        ],
        state: ReminderDayState(now: now),
        masterEnabled: true,
      );
      // 23:00 Wednesday is quiet, so it lands at 07:00 Thursday.
      expect(plan.single.when, DateTime(2026, 9, 10, 7, 0));
    });

    test('a zero-length window silences nothing', () {
      final quiet = QuietHours(
        start: LocalTime.of(9, 0),
        end: LocalTime.of(9, 0),
      );
      expect(quiet.contains(LocalTime.of(9, 0)), isFalse);
    });
  });

  group('the single switch', () {
    test('master off means nothing is pending', () {
      final plan = const ReminderPlanner().plan(
        rules: [water(), meal('dinner', 20), summary()],
        state: ReminderDayState(now: now, dayHasEntries: true),
        masterEnabled: false,
      );
      expect(plan, isEmpty);
    });

    test('a disabled rule is skipped while its siblings still fire', () {
      final plan = const ReminderPlanner().plan(
        rules: [water(enabled: false), meal('dinner', 20)],
        state: ReminderDayState(now: now),
        masterEnabled: true,
      );
      expect(plan.map((r) => r.ruleId), ['r-dinner']);
    });
  });

  group('the daily cap', () {
    test('no more than four land on one day', () {
      final rules = [
        water(skipIfMet: false),
        meal('breakfast', 11),
        meal('lunch', 13),
        meal('snack', 17),
        meal('dinner', 20),
        summary(),
      ];
      final plan = const ReminderPlanner().plan(
        rules: rules,
        state: ReminderDayState(now: now, dayHasEntries: true),
        masterEnabled: true,
      );
      final wednesday = plan.where((r) => r.when.day == 9);
      expect(wednesday.length, 4);
      // Soonest first, so the ones that survive are the ones closest to
      // now rather than an arbitrary four.
      expect(wednesday.map((r) => r.when.hour), [11, 13, 15, 17]);
    });

    test('the cap is per day, not per plan', () {
      // A plan that reaches into tomorrow may hold more than four in
      // total, as long as no single day does.
      final plan = const ReminderPlanner().plan(
        rules: [
          meal('breakfast', 11),
          meal('lunch', 13),
          meal('snack', 17),
          meal('dinner', 20),
          // 23:00 is quiet, so this one lands tomorrow morning.
          water(
            skipIfMet: false,
            schedule: DailySchedule(time: LocalTime.of(23, 0)),
          ),
        ],
        state: ReminderDayState(now: now),
        masterEnabled: true,
      );
      expect(plan.length, 5);
      expect(plan.where((r) => r.when.day == 9).length, 4);
      expect(plan.where((r) => r.when.day == 10).length, 1);
    });
  });

  group('content', () {
    test('the end-of-day summary carries the headline it was given', () {
      const headline = '1,950 kcal, protein met, fibre a bit low';
      final plan = const ReminderPlanner().plan(
        rules: [summary()],
        state: ReminderDayState(now: now, dayHasEntries: true),
        masterEnabled: true,
        summaryLine: headline,
      );
      // §29.4: useful even unopened.
      expect(plan.single.body, headline);
    });

    test('every reminder deep-links somewhere real', () {
      final plan = const ReminderPlanner().plan(
        rules: [
          water(skipIfMet: false),
          meal('dinner', 20),
          summary(),
          ReminderRule(
            id: 'r-week',
            type: ReminderType.weeklyReport,
            enabled: true,
            schedule: DailySchedule(time: LocalTime.of(9, 0)),
          ),
        ],
        state: ReminderDayState(now: now, dayHasEntries: true),
        masterEnabled: true,
      );
      expect(plan.map((r) => r.route).toSet(), {
        '/water',
        '/log',
        '/today/report',
        '/insights/week',
      });
    });
  });

  group('schedules', () {
    test('a weekday mask skips the days it excludes', () {
      final plan = const ReminderPlanner().plan(
        rules: [
          ReminderRule(
            id: 'r-weekend',
            type: ReminderType.water,
            enabled: true,
            conditions: ReminderConditions.unconditional,
            schedule: DailySchedule(
              time: LocalTime.of(9, 0),
              weekdays: const {DateTime.saturday, DateTime.sunday},
            ),
          ),
        ],
        state: ReminderDayState(now: now),
        masterEnabled: true,
      );
      expect(plan.single.when, DateTime(2026, 9, 12, 9, 0)); // Saturday.
    });

    test('an empty weekday set is off, not an error', () {
      final plan = const ReminderPlanner().plan(
        rules: [
          ReminderRule(
            id: 'r-none',
            type: ReminderType.water,
            enabled: true,
            conditions: ReminderConditions.unconditional,
            schedule: DailySchedule(
              time: LocalTime.of(9, 0),
              weekdays: const {},
            ),
          ),
        ],
        state: ReminderDayState(now: now),
        masterEnabled: true,
      );
      expect(plan, isEmpty);
    });

    test('the weekly report follows the profile week-start day', () {
      final rule = ReminderRule(
        id: 'r-week',
        type: ReminderType.weeklyReport,
        enabled: true,
        schedule: DailySchedule(
          time: LocalTime.of(9, 0),
          weekdays: const {DateTime.monday},
        ),
      );
      final sundayStart = const ReminderPlanner().plan(
        rules: [rule],
        state: ReminderDayState(now: now, weekStartDay: DateTime.sunday),
        masterEnabled: true,
      );
      expect(sundayStart.single.when.weekday, DateTime.sunday);
    });

    test('inactivity fires a gap after the last log, inside its window', () {
      final plan = const ReminderPlanner().plan(
        rules: [
          ReminderRule(
            id: 'r-gap',
            type: ReminderType.water,
            enabled: true,
            conditions: ReminderConditions.unconditional,
            schedule: const InactivitySchedule(
              gap: Duration(hours: 3),
              windowStart: LocalTime(8 * 60),
              windowEnd: LocalTime(21 * 60),
            ),
          ),
        ],
        state: ReminderDayState(
          now: now,
          lastWaterLoggedAt: DateTime(2026, 9, 9, 9, 30),
        ),
        masterEnabled: true,
      );
      expect(plan.single.when, DateTime(2026, 9, 9, 12, 30));
    });

    test('an inactivity gap landing after the window waits for morning', () {
      final plan = const ReminderPlanner().plan(
        rules: [
          ReminderRule(
            id: 'r-gap',
            type: ReminderType.water,
            enabled: true,
            conditions: ReminderConditions.unconditional,
            schedule: const InactivitySchedule(
              gap: Duration(hours: 3),
              windowStart: LocalTime(8 * 60),
              windowEnd: LocalTime(21 * 60),
            ),
          ),
        ],
        state: ReminderDayState(
          now: DateTime(2026, 9, 9, 20, 0),
          lastWaterLoggedAt: DateTime(2026, 9, 9, 19, 30),
        ),
        masterEnabled: true,
      );
      expect(plan.single.when, DateTime(2026, 9, 10, 8, 0));
    });

    test('nothing logged yet measures the gap from the window opening', () {
      final plan = const ReminderPlanner().plan(
        rules: [
          ReminderRule(
            id: 'r-gap',
            type: ReminderType.water,
            enabled: true,
            conditions: ReminderConditions.unconditional,
            schedule: const InactivitySchedule(
              gap: Duration(hours: 3),
              windowStart: LocalTime(8 * 60),
              windowEnd: LocalTime(21 * 60),
            ),
          ),
        ],
        state: ReminderDayState(now: now),
        masterEnabled: true,
      );
      expect(plan.single.when, DateTime(2026, 9, 9, 11, 0));
    });
  });

  group('stored schedules survive a round trip', () {
    test('daily', () {
      final original = DailySchedule(
        time: LocalTime.of(20, 30),
        weekdays: const {1, 3, 5},
      );
      final decoded = ReminderSchedule.tryDecode(original.encode());
      expect(decoded, isA<DailySchedule>());
      expect((decoded! as DailySchedule).time, original.time);
      expect((decoded as DailySchedule).weekdays, {1, 3, 5});
    });

    test('inactivity', () {
      const original = InactivitySchedule(
        gap: Duration(hours: 2, minutes: 30),
        windowStart: LocalTime(9 * 60),
        windowEnd: LocalTime(22 * 60),
      );
      final decoded =
          ReminderSchedule.tryDecode(original.encode())! as InactivitySchedule;
      expect(decoded.gap, const Duration(hours: 2, minutes: 30));
      expect(decoded.windowStart.format(), '09:00');
      expect(decoded.windowEnd.format(), '22:00');
    });

    test('an unreadable schedule disables one rule rather than throwing', () {
      expect(ReminderSchedule.tryDecode('not json'), isNull);
      expect(ReminderSchedule.tryDecode('{"kind":"daily"}'), isNull);
      expect(ReminderSchedule.tryDecode('{"kind":"martian"}'), isNull);

      final plan = const ReminderPlanner().plan(
        rules: const [
          ReminderRule(
            id: 'r-broken',
            type: ReminderType.water,
            enabled: true,
            schedule: null,
          ),
        ],
        state: ReminderDayState(now: now),
        masterEnabled: true,
      );
      expect(plan, isEmpty);
    });
  });
}
