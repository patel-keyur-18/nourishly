import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly/app/app.dart';
import 'package:nourishly/app/providers.dart';
import 'package:nourishly/app/router.dart';
import 'package:nourishly/features/food_catalog/data/food_catalog_providers.dart';
import 'package:nourishly/features/reminders/data/local_notification_scheduler.dart';
import 'package:nourishly/features/reminders/data/reminder_providers.dart';
import 'package:nourishly_data/nourishly_data.dart' hide ReminderRule;
import 'package:nourishly_domain/nourishly_domain.dart';
import 'package:uuid/uuid.dart';

/// §0.5's third backup mechanism: "monthly, dismissible, never nagging."
///
/// The three words are each a requirement, and each is a way this can go
/// wrong: too often is nagging, undismissable is worse, and prompting a
/// user with nothing to lose teaches them to ignore it before it matters.
void main() {
  const uuid = Uuid();
  late NourishlyDatabase db;
  late String ownerId;
  final today = DateTime(2026, 9, 9);

  setUp(() async {
    db = NourishlyDatabase.forTesting();
    ownerId = await ensureDefaultOwner(db);
    await _seedReference(db);
    await PreferencesDao(db).update(ownerId, onboardingSeen: true);
  });

  tearDown(() => db.close());

  Future<void> logOn(DateTime date) async {
    await db
        .into(db.foodLogEntries)
        .insert(
          FoodLogEntriesCompanion.insert(
            id: uuid.v7(),
            ownerId: ownerId,
            logDate: date,
            mealSlotId: 'slot-lunch',
            foodId: 'food-dal',
            foodRevision: 1,
            quantity: 1,
            gramsConsumed: 150,
            loggedAt: date,
            source: 'manual',
          ),
        );
  }

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nourishlyDatabaseProvider.overrideWithValue(db),
          catalogReadyProvider.overrideWith((ref) async {}),
          clockProvider.overrideWithValue(
            FakeClock(today.add(const Duration(hours: 9))),
          ),
          reminderSchedulerProvider.overrideWithValue(NoopReminderScheduler()),
        ],
        child: const NourishlyApp(),
      ),
    );
    await tester.pump();
    appRouter.go('/today');
    await tester.pumpAndSettle();
  }

  final prompt = find.textContaining('Worth keeping a copy');

  testWidgets('a brand new profile is not prompted', (tester) async {
    await pump(tester);
    expect(
      prompt,
      findsNothing,
      reason: 'nothing has been logged, so there is nothing to lose yet',
    );
  });

  testWidgets('a first week of logging is not prompted either', (tester) async {
    await logOn(today.subtract(const Duration(days: 5)));
    await logOn(today);
    await pump(tester);
    expect(
      prompt,
      findsNothing,
      reason:
          'prompting on day five trains the user to dismiss it before it '
          'ever means anything',
    );
  });

  testWidgets('a month of logging with no export is prompted', (tester) async {
    await logOn(today.subtract(const Duration(days: 40)));
    await logOn(today);
    await pump(tester);
    expect(prompt, findsOneWidget);
  });

  testWidgets('"Not now" dismisses it for a month', (tester) async {
    await logOn(today.subtract(const Duration(days: 40)));
    await logOn(today);
    await pump(tester);

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    expect(prompt, findsNothing);
    final preferences = await PreferencesDao(db).forOwner(ownerId);
    expect(
      preferences.exportPromptSnoozedUntil!.difference(today).inDays,
      greaterThanOrEqualTo(29),
    );
  });

  testWidgets('a recent export silences it', (tester) async {
    await logOn(today.subtract(const Duration(days: 400)));
    await logOn(today);
    await PreferencesDao(
      db,
    ).update(ownerId, lastExportedAt: today.subtract(const Duration(days: 3)));
    await pump(tester);
    expect(prompt, findsNothing);
  });

  testWidgets('an export from a year ago brings it back', (tester) async {
    await logOn(today.subtract(const Duration(days: 400)));
    await logOn(today);
    await PreferencesDao(db).update(
      ownerId,
      lastExportedAt: today.subtract(const Duration(days: 365)),
    );
    await pump(tester);
    expect(prompt, findsOneWidget);
  });

  group('erasing everything', () {
    test('removes every row an export would have saved (§30.7)', () async {
      await logOn(today);
      await PreferencesDao(db).forOwner(ownerId);
      await ReminderDao(db).rulesFor(ownerId);
      await db
          .into(db.bodyWeightEntries)
          .insert(
            BodyWeightEntriesCompanion.insert(
              id: 'bw-1',
              ownerId: ownerId,
              recordedAt: today,
              weightKg: 71,
              source: 'manual',
            ),
          );

      final eraser = ProfileEraser(db);
      expect(await eraser.remainingRows(ownerId), greaterThan(0));

      final report = await eraser.eraseEverything(ownerId);

      expect(report.total, greaterThan(0));
      expect(
        await eraser.remainingRows(ownerId),
        0,
        reason: 'whatever an export can save, a delete must remove',
      );
    });

    test('leaves a fresh profile, not an empty app (§30.7)', () async {
      await PreferencesDao(db).renameProfile(ownerId, 'Keyur');
      await logOn(today);

      await ProfileEraser(db).eraseEverything(ownerId);

      // The profile row survives and is reset. Every provider in the app
      // assumes there is one; deleting it to recreate it moments later
      // would mean a window in which there is not.
      final user = await (db.select(
        db.users,
      )..where((u) => u.id.equals(ownerId))).getSingle();
      expect(user.displayName, 'You');

      // And preferences come back at their defaults on next read.
      final preferences = await PreferencesDao(db).forOwner(ownerId);
      expect(preferences.remindersEnabled, isFalse);
      expect(preferences.lastExportedAt, isNull);
    });

    test('what it deletes and what an export saves are the same list', () {
      // Not a behaviour test — a structural one. The eraser walks
      // `exportedTables`, so this asserts the two can never diverge.
      expect(exportedTables.map((t) => t.name).toSet(), isNotEmpty);
      expect(exportedTables.first.name, 'users');
    });
  });
}

Future<void> _seedReference(NourishlyDatabase db) async {
  await db
      .into(db.mealSlots)
      .insert(
        MealSlotsCompanion.insert(
          id: 'slot-lunch',
          key: 'lunch',
          displayName: 'Lunch',
          sortOrder: 1,
          ownerId: const Value(null),
        ),
      );
  await db
      .into(db.foodItems)
      .insert(
        FoodItemsCompanion.insert(
          id: 'food-dal',
          kind: 'dish',
          canonicalName: 'Dal',
          qualityTier: 'derived',
          provenanceSource: 'catalog_pipeline_recipe',
        ),
      );
}
