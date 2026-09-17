import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly/app/app.dart';
import 'package:nourishly/app/router.dart';
import 'package:nourishly/features/reminders/data/local_notification_scheduler.dart';
import 'package:nourishly/features/reminders/data/reminder_providers.dart';
import 'package:nourishly/features/food_catalog/data/food_catalog_providers.dart';
import 'package:nourishly_data/nourishly_data.dart';
import 'package:nourishly_ui/nourishly_ui.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

void main() {
  late NourishlyDatabase db;
  late FoodLoggingDao dao;
  late String ownerId;
  late String breakfastId;
  late String lunchId;

  Future<String> seedFood(String name, {double kcalPer100g = 150}) async {
    final foodId = _uuid.v7();
    await db
        .into(db.foodItems)
        .insert(
          FoodItemsCompanion.insert(
            id: foodId,
            kind: 'ingredient',
            canonicalName: name,
            qualityTier: 'verified',
            provenanceSource: 'test',
          ),
        );
    final servingId = _uuid.v7();
    await db
        .into(db.servingSizes)
        .insert(
          ServingSizesCompanion.insert(
            id: servingId,
            foodId: foodId,
            label: '1 serving',
            grams: 100,
          ),
        );
    await db
        .into(db.foodNutrientValues)
        .insert(
          FoodNutrientValuesCompanion.insert(
            id: _uuid.v7(),
            foodId: foodId,
            nutrientId: 'energy',
            amountPer100g: kcalPer100g,
            valueSource: 'test',
          ),
        );
    return servingId;
  }

  setUp(() async {
    db = NourishlyDatabase.forTesting();
    dao = FoodLoggingDao(db);
    ownerId = await ensureDefaultOwner(db);
    await PreferencesDao(db).update(ownerId, onboardingSeen: true);

    breakfastId = _uuid.v7();
    lunchId = _uuid.v7();
    await db
        .into(db.mealSlots)
        .insert(
          MealSlotsCompanion.insert(
            id: breakfastId,
            key: 'breakfast',
            displayName: 'Breakfast',
            sortOrder: 0,
          ),
        );
    await db
        .into(db.mealSlots)
        .insert(
          MealSlotsCompanion.insert(
            id: lunchId,
            key: 'lunch',
            displayName: 'Lunch',
            sortOrder: 1,
          ),
        );
  });
  tearDown(() => db.close());

  Future<void> pumpToDayLog(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nourishlyDatabaseProvider.overrideWithValue(db),
          catalogReadyProvider.overrideWith((ref) async {}),
          reminderSchedulerProvider.overrideWithValue(NoopReminderScheduler()),
        ],
        child: const NourishlyApp(),
      ),
    );
    await tester.pumpAndSettle();
    appRouter.go('/today/log');
    await tester.pumpAndSettle();
  }

  testWidgets('lists today\'s entries earliest-first with their kcal', (
    tester,
  ) async {
    final oatsServing = await seedFood('Oats', kcalPer100g: 380);
    final wrapServing = await seedFood('Paneer wrap', kcalPer100g: 250);
    final today = DateTime.now();
    final logDate = DateTime(today.year, today.month, today.day);

    final oatsEntryId = await dao.logFood(
      ownerId: ownerId,
      foodId: (await (db.select(
        db.servingSizes,
      )..where((s) => s.id.equals(oatsServing))).getSingle()).foodId,
      servingId: oatsServing,
      quantity: 1,
      mealSlotId: breakfastId,
      logDate: logDate,
    );
    await dao.logFood(
      ownerId: ownerId,
      foodId: (await (db.select(
        db.servingSizes,
      )..where((s) => s.id.equals(wrapServing))).getSingle()).foodId,
      servingId: wrapServing,
      quantity: 1,
      mealSlotId: lunchId,
      logDate: logDate,
    );
    // logFood stamps `loggedAt` with DateTime.now() internally, so both
    // entries land within the same millisecond in a fast test run — push
    // the oats entry earlier so timeline order is actually under test.
    await (db.update(db.foodLogEntries)
      ..where((e) => e.id.equals(oatsEntryId))).write(
      FoodLogEntriesCompanion(
        loggedAt: Value(DateTime.now().subtract(const Duration(hours: 4))),
      ),
    );

    await pumpToDayLog(tester);

    expect(find.text('Oats'), findsOneWidget);
    expect(find.text('Paneer wrap'), findsOneWidget);
    expect(find.text('380 kcal'), findsOneWidget);
    expect(find.text('250 kcal'), findsOneWidget);

    final oatsPosition = tester.getTopLeft(find.text('Oats'));
    final wrapPosition = tester.getTopLeft(find.text('Paneer wrap'));
    expect(
      oatsPosition.dy,
      lessThan(wrapPosition.dy),
      reason: 'the earlier-logged entry should render above the later one',
    );

    // "By meal" groups the same entries under their slot headers.
    await tester.tap(find.text('By meal'));
    await tester.pumpAndSettle();
    // NourishlySectionHeader upper-cases its label.
    expect(find.text('BREAKFAST'), findsOneWidget);
    expect(find.text('LUNCH'), findsOneWidget);
    expect(find.text('Oats'), findsOneWidget);
    expect(find.text('Paneer wrap'), findsOneWidget);

    // Deleting an entry removes it and offers an undo that brings it back.
    await tester.tap(find.text('Oats'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete entry'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Oats'), findsNothing);
    expect(find.text('Undo'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Oats'), findsOneWidget);
  });

  testWidgets(
    'editing a portion updates the entry everywhere, not just grams',
    (tester) async {
      final foodId = _uuid.v7();
      await db
          .into(db.foodItems)
          .insert(
            FoodItemsCompanion.insert(
              id: foodId,
              kind: 'ingredient',
              canonicalName: 'Oats',
              qualityTier: 'verified',
              provenanceSource: 'test',
            ),
          );
      final smallServing = _uuid.v7();
      await db
          .into(db.servingSizes)
          .insert(
            ServingSizesCompanion.insert(
              id: smallServing,
              foodId: foodId,
              label: '1 bowl',
              grams: 100,
              sortOrder: const Value(0),
            ),
          );
      final largeServing = _uuid.v7();
      await db
          .into(db.servingSizes)
          .insert(
            ServingSizesCompanion.insert(
              id: largeServing,
              foodId: foodId,
              label: '2 bowls',
              grams: 200,
              sortOrder: const Value(1),
            ),
          );
      await db
          .into(db.foodNutrientValues)
          .insert(
            FoodNutrientValuesCompanion.insert(
              id: _uuid.v7(),
              foodId: foodId,
              nutrientId: 'energy',
              amountPer100g: 380,
              valueSource: 'test',
            ),
          );
      final today = DateTime.now();
      await dao.logFood(
        ownerId: ownerId,
        foodId: foodId,
        servingId: smallServing,
        quantity: 1,
        mealSlotId: breakfastId,
        logDate: DateTime(today.year, today.month, today.day),
      );

      await pumpToDayLog(tester);
      expect(find.text('380 kcal'), findsOneWidget);

      // The day log's edit action is the same portion screen used to add
      // food, not a bare grams prompt.
      await tester.tap(find.text('Oats'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit portion'));
      await tester.pumpAndSettle();
      expect(find.text('Edit entry'), findsOneWidget);
      // Prefilled from the existing entry.
      expect(find.text('× 1 bowl · 100 g'), findsOneWidget);

      await tester.tap(find.text('2 bowls · 200 g'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      // Lets the "Changes saved." snackbar's own timer fire rather than
      // leaving it pending when the test ends.
      await tester.pump(nourishlySnackDuration + const Duration(seconds: 1));

      // Back on the day log, the change is already there.
      expect(find.text('200 g'), findsOneWidget);
      expect(find.text('760 kcal'), findsOneWidget);

      // And on the dashboard, which reads a materialised summary through a
      // different provider entirely — proving the edit isn't only visible
      // to the screen that made it.
      appRouter.go('/today');
      await tester.pumpAndSettle();
      expect(find.text('760 kcal'), findsOneWidget);
    },
  );
}
