import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly_data/nourishly_data.dart' hide ReminderRule;
import 'package:nourishly_domain/nourishly_domain.dart';

void main() {
  late NourishlyDatabase db;
  late ReminderDao dao;
  late String ownerId;

  setUp(() async {
    db = NourishlyDatabase.forTesting();
    dao = ReminderDao(db);
    ownerId = await ensureDefaultOwner(db);
  });

  tearDown(() => db.close());

  test('a profile gets one rule per type, seeded once', () async {
    final first = await dao.rulesFor(ownerId);
    expect(
      first.map((r) => r.type).toSet(),
      ReminderType.values.toSet(),
      reason: 'every v1.0 type in §29.2 gets a rule',
    );
    // One per remindable meal slot, snacks excluded.
    expect(
      first.where((r) => r.type == ReminderType.meal).map((r) => r.mealSlotKey),
      ['breakfast', 'lunch', 'dinner'],
    );

    final second = await dao.rulesFor(ownerId);
    expect(second.length, first.length, reason: 'seeding is once, not once per read');
    expect(second.map((r) => r.id), first.map((r) => r.id));
  });

  test('only the end-of-day summary starts on (§29.2)', () async {
    final rules = await dao.rulesFor(ownerId);
    final on = rules.where((r) => r.enabled).toList();
    expect(on.single.type, ReminderType.endOfDaySummary);
  });

  test('seeded rules carry the default quiet hours', () async {
    final rules = await dao.rulesFor(ownerId);
    for (final rule in rules) {
      expect(rule.quietHours, QuietHours.defaults);
    }
  });

  test('seeded rules stand down when the target is met', () async {
    final rules = await dao.rulesFor(ownerId);
    final water = rules.firstWhere((r) => r.type == ReminderType.water);
    expect(water.conditions.skipIfTargetMet, isTrue);
  });

  test('enabling and rescheduling a rule round-trips', () async {
    final rules = await dao.rulesFor(ownerId);
    final dinner = rules.firstWhere((r) => r.mealSlotKey == 'dinner');
    expect(dinner.enabled, isFalse);

    await dao.setEnabled(dinner.id, enabled: true);
    await dao.setSchedule(dinner.id, DailySchedule(time: LocalTime.of(19, 45)));

    final reread = (await dao.rulesFor(
      ownerId,
    )).firstWhere((r) => r.id == dinner.id);
    expect(reread.enabled, isTrue);
    expect((reread.schedule! as DailySchedule).time, LocalTime.of(19, 45));
    expect(await dao.enabledCount(ownerId), 2);
  });

  test('quiet hours are set for the whole profile at once', () async {
    await dao.rulesFor(ownerId);
    await dao.setQuietHours(
      ownerId,
      QuietHours(start: LocalTime.of(23, 0), end: LocalTime.of(6, 30)),
    );
    final rules = await dao.rulesFor(ownerId);
    expect(
      rules.every((r) => r.quietHours!.end == LocalTime.of(6, 30)),
      isTrue,
    );
  });

  test('the master switch and export bookkeeping persist', () async {
    final preferences = PreferencesDao(db);
    final before = await preferences.forOwner(ownerId);
    expect(before.remindersEnabled, isFalse, reason: '§29.1: opt-in');
    expect(before.lastExportedAt, isNull);

    final exportedAt = DateTime(2026, 9, 1, 8, 30);
    await preferences.update(
      ownerId,
      remindersEnabled: true,
      lastExportedAt: exportedAt,
    );

    final after = await preferences.forOwner(ownerId);
    expect(after.remindersEnabled, isTrue);
    expect(after.lastExportedAt, exportedAt);
  });

  test('the planner reads what the DAO writes', () async {
    // The seam that matters: a rule configured through the DAO produces
    // the notification the planner promises, with no translation step in
    // between that could silently drop a field.
    final rules = await dao.rulesFor(ownerId);
    final lunch = rules.firstWhere((r) => r.mealSlotKey == 'lunch');
    await dao.setEnabled(lunch.id, enabled: true);

    final plan = const ReminderPlanner().plan(
      rules: await dao.rulesFor(ownerId),
      state: ReminderDayState(now: DateTime(2026, 9, 9, 10, 0)),
      masterEnabled: true,
    );
    final lunchReminder = plan.firstWhere((r) => r.ruleId == lunch.id);
    expect(lunchReminder.when, DateTime(2026, 9, 9, 13, 30));
    expect(lunchReminder.title, 'Log lunch');
    expect(lunchReminder.route, '/log');
  });
}
