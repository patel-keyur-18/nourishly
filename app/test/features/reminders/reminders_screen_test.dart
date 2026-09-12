import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly/app/app.dart';
import 'package:nourishly/app/providers.dart';
import 'package:nourishly/app/router.dart';
import 'package:nourishly/features/food_catalog/data/food_catalog_providers.dart';
import 'package:nourishly/features/reminders/data/end_of_day_summary.dart';
import 'package:nourishly/features/reminders/data/local_notification_scheduler.dart';
import 'package:nourishly/features/reminders/data/reminder_providers.dart';
import 'package:nourishly_data/nourishly_data.dart'
    hide DailyScore, ReminderRule;
import 'package:nourishly_domain/nourishly_domain.dart';
import 'package:nutrition_core/nutrition_core.dart'
    show DailyScore, NutrientStatus;

/// §29's requirements where they meet the user: the single switch, the
/// permission notice, and the fact that the plan the screen shows is the
/// plan the scheduler is handed.
void main() {
  late NourishlyDatabase db;
  late String ownerId;
  late NoopReminderScheduler scheduler;
  final now = DateTime(2026, 9, 9, 10, 0);

  setUp(() async {
    db = NourishlyDatabase.forTesting();
    ownerId = await ensureDefaultOwner(db);
    scheduler = NoopReminderScheduler();
    await _seedReference(db);
    await PreferencesDao(db).update(ownerId, onboardingSeen: true);
  });

  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nourishlyDatabaseProvider.overrideWithValue(db),
          catalogReadyProvider.overrideWith((ref) async {}),
          clockProvider.overrideWithValue(FakeClock(now)),
          reminderSchedulerProvider.overrideWithValue(scheduler),
        ],
        child: const NourishlyApp(),
      ),
    );
    await tester.pump();
    appRouter.go('/profile/reminders');
    await tester.pumpAndSettle();
  }

  testWidgets('reminders start off, and the screen says so', (tester) async {
    await pump(tester);

    expect(find.text('Off. Nothing is scheduled.'), findsOneWidget);
    // §29.4's single switch off means the per-rule list is not even
    // offered: there is nothing to configure until reminders exist.
    expect(find.text('Drink water'), findsNothing);
    expect(scheduler.applied, isEmpty);
  });

  testWidgets('turning the master switch on asks for permission then '
      'schedules', (tester) async {
    // §29.1: the ask happens here, not at launch.
    scheduler.permissionState = NotificationPermission.notRequested;
    await pump(tester);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    expect(scheduler.permissionState, NotificationPermission.granted);
    expect(find.text('Drink water'), findsOneWidget);
    expect(find.text('Log lunch'), findsOneWidget);
    // Only the end-of-day summary is on by default, and it stands down on
    // a day with nothing logged — which this one is.
    expect(scheduler.applied, isEmpty);
  });

  testWidgets('a rule that is on and relevant reaches the scheduler', (
    tester,
  ) async {
    await PreferencesDao(db).update(ownerId, remindersEnabled: true);
    final rules = await ReminderDao(db).rulesFor(ownerId);
    final lunch = rules.firstWhere((r) => r.mealSlotKey == 'lunch');
    await ReminderDao(db).setEnabled(lunch.id, enabled: true);

    await pump(tester);

    expect(
      scheduler.applied.map((r) => r.title),
      contains('Log lunch'),
    );
    // The plan card is below the fold in a lazy ListView, so scroll to
    // it rather than asserting on a widget that was never built.
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('NEXT UP'), findsOneWidget);
  });

  testWidgets('a denied permission is explained, not re-prompted', (
    tester,
  ) async {
    scheduler.permissionState = NotificationPermission.denied;
    await PreferencesDao(db).update(ownerId, remindersEnabled: true);
    await pump(tester);

    // §29.4: shows why they are inactive, without prompting again.
    expect(
      find.textContaining('Notifications are turned off for Nourishly'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Everything else in the app works'),
      findsOneWidget,
    );
  });

  testWidgets('Settings shows the count, and links here', (tester) async {
    await PreferencesDao(db).update(ownerId, remindersEnabled: true);
    final rules = await ReminderDao(db).rulesFor(ownerId);
    for (final rule in rules.take(3)) {
      await ReminderDao(db).setEnabled(rule.id, enabled: true);
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nourishlyDatabaseProvider.overrideWithValue(db),
          catalogReadyProvider.overrideWith((ref) async {}),
          clockProvider.overrideWithValue(FakeClock(now)),
          reminderSchedulerProvider.overrideWithValue(scheduler),
        ],
        child: const NourishlyApp(),
      ),
    );
    await tester.pump();
    appRouter.go('/profile');
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();

    // Prototype 13A's "Reminders … 3 on".
    expect(find.text('Reminders'), findsOneWidget);
    expect(find.text('4 on'), findsOneWidget);
  });

  group('the end-of-day headline', () {
    test('carries the numbers, so it is useful unopened (§29.4)', () {
      final summary = _summary(
        energyKcal: 1950,
        nutrients: const [
          ('protein', 'Protein', NutrientStatus.within),
          ('fibre', 'Dietary fibre', NutrientStatus.below),
        ],
      );
      expect(
        endOfDaySummaryLine(summary),
        '1,950 kcal, protein met, fibre a bit low',
      );
    });

    test('says nothing about a day with nothing in it', () {
      expect(endOfDaySummaryLine(_summary(energyKcal: 0)), isNull);
    });

    test('over target is stated, never scolded (§21.8)', () {
      final line = endOfDaySummaryLine(
        _summary(
          energyKcal: 2400,
          nutrients: const [('sodium', 'Sodium', NutrientStatus.above)],
        ),
      );
      expect(line, contains('sodium over'));
      expect(line, isNot(contains('too')));
    });
  });
}

DaySummary _summary({
  required double energyKcal,
  List<(String, String, NutrientStatus)> nutrients = const [],
}) {
  return DaySummary(
    logDate: DateTime(2026, 9, 9),
    totalEnergyKcal: energyKcal,
    entryCount: energyKcal > 0 ? 3 : 0,
    nutrients: [
      for (final (id, name, status) in nutrients)
        SummaryNutrient(
          nutrientId: id,
          displayName: name,
          unit: 'g',
          amount: 10,
          coverage: 1,
          status: status,
        ),
    ],
    meals: const [],
    score: DailyScore.from(const []),
    insights: const [],
    waterMl: 0,
    isComplete: true,
  );
}

Future<void> _seedReference(NourishlyDatabase db) async {
  await db
      .into(db.nutrientGroups)
      .insert(
        NutrientGroupsCompanion.insert(
          id: 'macros',
          name: 'Macros',
          sortOrder: 0,
        ),
      );
  await db
      .into(db.nutrients)
      .insert(
        NutrientsCompanion.insert(
          id: 'protein',
          groupId: 'macros',
          displayName: 'Protein',
          canonicalUnit: 'g',
          displayPrecision: 0,
          defaultCurveType: 'floor',
          isLimitNutrient: false,
          sortOrder: 0,
          isCore: true,
          minCoverageForScoring: 0.5,
        ),
      );
  for (final (key, name, order) in const [
    ('breakfast', 'Breakfast', 0),
    ('lunch', 'Lunch', 1),
    ('dinner', 'Dinner', 2),
  ]) {
    await db
        .into(db.mealSlots)
        .insert(
          MealSlotsCompanion.insert(
            id: 'slot-$key',
            key: key,
            displayName: name,
            sortOrder: order,
            ownerId: const Value(null),
          ),
        );
  }
}
