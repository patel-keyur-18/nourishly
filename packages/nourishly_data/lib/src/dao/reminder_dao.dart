import 'package:drift/drift.dart';
import 'package:nourishly_domain/nourishly_domain.dart';
import 'package:uuid/uuid.dart';

// Drift names a row class after the singular of its table, so
// `reminder_rules` generates a `ReminderRule` that collides with the
// domain entity of the same name. As in [ProfileDao], the domain type is
// the one this DAO speaks in; the row is reached under a prefix, and only
// where a row has to be named.
import '../database.dart' hide ReminderRule;
import '../database.dart' as rows show ReminderRule;

/// Reads and writes `reminder_rules` (§22.5) and hands the planner domain
/// objects rather than Drift rows (§13.3).
///
/// The five v1.0 types each get exactly one rule per profile, seeded on
/// first read. That is a deliberate simplification of the schema, which
/// would allow many: §29.1's cap is 3–4 notifications a day in total, so a
/// profile with three water rules is a configuration the design does not
/// want to be reachable. Meals are the exception — one rule per slot —
/// and they are distinguished by [ReminderRules.mealSlotKey].
class ReminderDao {
  ReminderDao(this._db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final NourishlyDatabase _db;
  final Uuid _uuid;

  /// The meal slots that get a reminder rule. Snacks deliberately do not:
  /// §29.1's cap leaves no room for a fifth daily nudge, and a reminder to
  /// eat a snack is the one that reads as instruction rather than record-
  /// keeping.
  static const remindableMealSlots = ['breakfast', 'lunch', 'dinner'];

  /// §29.2's defaults, applied once per profile.
  ///
  /// Every rule is created off except the end-of-day summary, which §29.2
  /// marks as on "if any reminder is enabled" — and the master switch
  /// (`UserPreferences.remindersEnabled`) is what "any reminder is
  /// enabled" means in practice. So the rows exist with sensible times
  /// from the start, and the user turns on the switch rather than being
  /// asked to build a schedule from nothing.
  Future<List<ReminderRule>> rulesFor(String ownerId) async {
    final existing = await _read(ownerId);
    if (existing.isNotEmpty) return existing;
    await _seed(ownerId);
    return _read(ownerId);
  }

  Stream<List<ReminderRule>> watch(String ownerId) {
    return (_db.select(_db.reminderRules)
          ..where((r) => r.ownerId.equals(ownerId)))
        .watch()
        .map((rows) => rows.map(_toDomain).toList()..sort(_byTypeThenSlot));
  }

  Future<void> setEnabled(String ruleId, {required bool enabled}) {
    return (_db.update(
      _db.reminderRules,
    )..where((r) => r.id.equals(ruleId))).write(
      ReminderRulesCompanion(
        enabled: Value(enabled),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> setSchedule(String ruleId, ReminderSchedule schedule) {
    return (_db.update(
      _db.reminderRules,
    )..where((r) => r.id.equals(ruleId))).write(
      ReminderRulesCompanion(
        schedule: Value(schedule.encode()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Quiet hours are stored per rule by the schema but edited for the
  /// whole profile by the UI — one window is what §29.4 describes, and
  /// per-reminder quiet hours would be a setting nobody wants to maintain.
  Future<void> setQuietHours(String ownerId, QuietHours quietHours) {
    return (_db.update(
      _db.reminderRules,
    )..where((r) => r.ownerId.equals(ownerId))).write(
      ReminderRulesCompanion(
        quietHoursStart: Value(quietHours.start.format()),
        quietHoursEnd: Value(quietHours.end.format()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> setConditions(String ruleId, ReminderConditions conditions) {
    return (_db.update(
      _db.reminderRules,
    )..where((r) => r.id.equals(ruleId))).write(
      ReminderRulesCompanion(
        conditions: Value(conditions.encode()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// How many rules are on, for Settings' "3 on" summary row.
  Future<int> enabledCount(String ownerId) async {
    final rules = await rulesFor(ownerId);
    return rules.where((r) => r.enabled).length;
  }

  Future<List<ReminderRule>> _read(String ownerId) async {
    final rows = await (_db.select(
      _db.reminderRules,
    )..where((r) => r.ownerId.equals(ownerId))).get();
    return rows.map(_toDomain).toList()..sort(_byTypeThenSlot);
  }

  Future<void> _seed(String ownerId) async {
    final now = DateTime.now();
    final rows = <ReminderRulesCompanion>[
      _row(
        ownerId,
        ReminderType.water,
        // Three waking hours without water is the gap worth a nudge; any
        // shorter and it fires on a normal morning.
        const InactivitySchedule(
          gap: Duration(hours: 3),
          windowStart: LocalTime(8 * 60),
          windowEnd: LocalTime(21 * 60),
        ),
        now,
      ),
      for (final slot in remindableMealSlots)
        _row(
          ownerId,
          ReminderType.meal,
          DailySchedule(time: _defaultMealTime(slot)),
          now,
          mealSlotKey: slot,
        ),
      _row(
        ownerId,
        ReminderType.endOfDaySummary,
        DailySchedule(time: LocalTime.of(21, 30)),
        now,
        enabled: true,
      ),
      _row(
        ownerId,
        ReminderType.goalAchieved,
        DailySchedule(time: LocalTime.of(20, 0)),
        now,
      ),
      _row(
        ownerId,
        ReminderType.weeklyReport,
        DailySchedule(time: LocalTime.of(9, 0)),
        now,
      ),
    ];
    await _db.batch((batch) => batch.insertAll(_db.reminderRules, rows));
  }

  ReminderRulesCompanion _row(
    String ownerId,
    ReminderType type,
    ReminderSchedule schedule,
    DateTime now, {
    String? mealSlotKey,
    bool? enabled,
  }) {
    return ReminderRulesCompanion.insert(
      id: _uuid.v7(),
      ownerId: ownerId,
      type: type.id,
      schedule: schedule.encode(),
      enabled: Value(enabled ?? type.defaultEnabled),
      conditions: Value(const ReminderConditions().encode()),
      quietHoursStart: Value(QuietHours.defaults.start.format()),
      quietHoursEnd: Value(QuietHours.defaults.end.format()),
      mealSlotKey: Value(mealSlotKey),
      createdAt: Value(now),
      updatedAt: Value(now),
    );
  }

  static LocalTime _defaultMealTime(String slot) => switch (slot) {
    'breakfast' => LocalTime.of(9, 0),
    'lunch' => LocalTime.of(13, 30),
    _ => LocalTime.of(20, 30),
  };

  static ReminderRule _toDomain(rows.ReminderRule row) {
    final start = LocalTime.tryParse(row.quietHoursStart);
    final end = LocalTime.tryParse(row.quietHoursEnd);
    return ReminderRule(
      id: row.id,
      // An unknown type id means a row written by a newer version of the
      // app and then imported here. Mapping it to null would need a
      // nullable type on the whole model for one edge case, so it is
      // filtered out at [_read] instead.
      type: ReminderType.fromId(row.type) ?? ReminderType.water,
      schedule: ReminderSchedule.tryDecode(row.schedule),
      enabled: row.enabled && ReminderType.fromId(row.type) != null,
      conditions: ReminderConditions.decode(row.conditions),
      quietHours: start != null && end != null
          ? QuietHours(start: start, end: end)
          : null,
      mealSlotKey: row.mealSlotKey,
    );
  }

  /// Settings lists reminders in the order a day runs, not in insertion
  /// order: water, then the meals in slot order, then the evening summary.
  static int _byTypeThenSlot(ReminderRule a, ReminderRule b) {
    final byType = a.type.index.compareTo(b.type.index);
    if (byType != 0) return byType;
    final aSlot = remindableMealSlots.indexOf(a.mealSlotKey ?? '');
    final bSlot = remindableMealSlots.indexOf(b.mealSlotKey ?? '');
    return aSlot.compareTo(bSlot);
  }
}
