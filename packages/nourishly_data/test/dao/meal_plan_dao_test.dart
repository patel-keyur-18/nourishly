import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly_data/nourishly_data.dart';

/// The one thing the week planner must never get wrong: a meal you have
/// only *decided on* must not appear anywhere the app reports what you
/// ate. Everything else here is a convenience; this is the invariant.
void main() {
  late NourishlyDatabase db;
  late String ownerId;
  late FoodLoggingDao logging;
  late MealPlanDao plan;

  final monday = DateTime(2026, 9, 21);
  final tuesday = DateTime(2026, 9, 22);

  setUp(() async {
    db = NourishlyDatabase.forTesting();
    ownerId = await ensureDefaultOwner(db);
    logging = FoodLoggingDao(db);
    plan = MealPlanDao(db);

    await db
        .into(db.foodItems)
        .insert(
          FoodItemsCompanion.insert(
            id: 'food-dal',
            kind: 'ingredient',
            canonicalName: 'Dal dhokli',
            qualityTier: 'verified',
            provenanceSource: 'usda',
          ),
        );
    await db
        .into(db.servingSizes)
        .insert(
          ServingSizesCompanion.insert(
            id: 'serving-bowl',
            foodId: 'food-dal',
            label: '1 bowl',
            grams: 100,
          ),
        );
    await db
        .into(db.mealSlots)
        .insert(
          MealSlotsCompanion.insert(
            id: 'slot-lunch',
            key: 'lunch',
            displayName: 'Lunch',
            sortOrder: 1,
          ),
        );
    await db
        .into(db.foodNutrientValues)
        .insert(
          FoodNutrientValuesCompanion.insert(
            id: 'fnv-energy',
            foodId: 'food-dal',
            nutrientId: 'energy',
            amountPer100g: 200,
            valueSource: 'measured',
          ),
        );
  });

  tearDown(() => db.close());

  Future<String> planLunch(DateTime date, {double quantity = 1}) =>
      logging.logFood(
        ownerId: ownerId,
        foodId: 'food-dal',
        servingId: 'serving-bowl',
        quantity: quantity,
        mealSlotId: 'slot-lunch',
        logDate: date,
        status: logStatusPlanned,
        source: 'plan',
      );

  Future<String> eatLunch(DateTime date, {double quantity = 1}) =>
      logging.logFood(
        ownerId: ownerId,
        foodId: 'food-dal',
        servingId: 'serving-bowl',
        quantity: quantity,
        mealSlotId: 'slot-lunch',
        logDate: date,
      );

  Future<DaySummary> summaryOf(DateTime date) =>
      DailySummaryDao(db).summaryFor(ownerId: ownerId, logDate: date);

  group('a plan is not intake', () {
    test('a planned entry contributes nothing to the day summary', () async {
      await planLunch(monday);

      final summary = await summaryOf(monday);
      expect(summary.totalEnergyKcal, 0);
      expect(summary.entryCount, 0);
    });

    test('confirming it is what makes it count', () async {
      final entryId = await planLunch(monday);
      expect((await summaryOf(monday)).totalEnergyKcal, 0);

      await logging.confirmEntry(entryId);

      final summary = await summaryOf(monday);
      expect(summary.totalEnergyKcal, 200);
      expect(summary.entryCount, 1);
    });

    test('a skipped entry counts no more than a planned one', () async {
      final entryId = await planLunch(monday);
      await logging.skipEntry(entryId);

      expect((await summaryOf(monday)).totalEnergyKcal, 0);

      // …and it is kept, not deleted: "planned and not eaten" is the
      // signal that makes the next plan better.
      final row = await (db.select(
        db.foodLogEntries,
      )..where((e) => e.id.equals(entryId))).getSingle();
      expect(row.status, logStatusSkipped);
      expect(row.deletedAt, isNull);
    });

    test('unconfirming takes it back out of the day', () async {
      final entryId = await planLunch(monday);
      await logging.confirmEntry(entryId);
      expect((await summaryOf(monday)).totalEnergyKcal, 200);

      await logging.unconfirmEntry(entryId);
      expect((await summaryOf(monday)).totalEnergyKcal, 0);
    });

    test('confirming does not recompute the frozen snapshot', () async {
      final entryId = await planLunch(monday);

      // The catalog changes between planning the meal and eating it.
      await (db.update(db.foodNutrientValues)
            ..where((v) => v.id.equals('fnv-energy')))
          .write(const FoodNutrientValuesCompanion(amountPer100g: Value(900)));

      await logging.confirmEntry(entryId);

      // ADR-008: the entry keeps the nutrients it was planned with.
      expect((await summaryOf(monday)).totalEnergyKcal, 200);
    });

    test('an edited portion rescales, then confirms', () async {
      final entryId = await planLunch(monday);
      await logging.updateEntry(entryId: entryId, quantity: 2);
      await logging.confirmEntry(entryId);

      expect((await summaryOf(monday)).totalEnergyKcal, 400);
    });
  });

  group('projection', () {
    test('splits a day into what is eaten and what is only planned', () async {
      await eatLunch(monday);
      await planLunch(monday, quantity: 2);

      final projection = await plan.projectionFor(
        ownerId: ownerId,
        logDate: monday,
      );
      final energy = projection['energy']!;
      expect(energy.eaten, 200);
      expect(energy.planned, 400);
      expect(energy.total, 600);
    });

    test('a skipped entry is in neither half', () async {
      await eatLunch(monday);
      final skipped = await planLunch(monday);
      await logging.skipEntry(skipped);

      final energy = (await plan.projectionFor(
        ownerId: ownerId,
        logDate: monday,
      ))['energy']!;
      expect(energy.eaten, 200);
      expect(energy.planned, 0);
    });
  });

  group('copyWeek', () {
    test('copies a week forward as a plan, not as intake', () async {
      await eatLunch(monday);
      await eatLunch(tuesday);

      final written = await plan.copyWeek(
        ownerId: ownerId,
        fromWeekStart: monday,
        toWeekStart: monday.add(const Duration(days: 7)),
      );
      expect(written, 2);

      // The copies land on the same weekdays, one week on.
      final copies = await (db.select(
        db.foodLogEntries,
      )..where((e) => e.status.equals(logStatusPlanned))).get();
      expect(copies, hasLength(2));
      expect(copies.map((e) => e.logDate).toSet(), {
        monday.add(const Duration(days: 7)),
        tuesday.add(const Duration(days: 7)),
      });

      // And they change nothing about what the source week says happened.
      expect((await summaryOf(monday)).totalEnergyKcal, 200);
      // Nor do they count on the target week.
      expect(
        (await summaryOf(monday.add(const Duration(days: 7)))).totalEnergyKcal,
        0,
      );
    });

    test('leaves a day that is already planned alone', () async {
      await eatLunch(monday);
      final nextMonday = monday.add(const Duration(days: 7));
      await planLunch(nextMonday, quantity: 3);

      final written = await plan.copyWeek(
        ownerId: ownerId,
        fromWeekStart: monday,
        toWeekStart: nextMonday,
      );

      expect(
        written,
        0,
        reason:
            'a day already thought about is not '
            'something a convenience should overwrite',
      );
      final onTarget = await (db.select(
        db.foodLogEntries,
      )..where((e) => e.logDate.equals(nextMonday))).get();
      expect(onTarget, hasLength(1));
      expect(onTarget.single.quantity, 3);
    });

    test('skipped entries are not carried forward', () async {
      final skipped = await planLunch(monday);
      await logging.skipEntry(skipped);

      final written = await plan.copyWeek(
        ownerId: ownerId,
        fromWeekStart: monday,
        toWeekStart: monday.add(const Duration(days: 7)),
      );
      expect(written, 0);
    });
  });

  test(
    'watchRange returns the week with names and statuses resolved',
    () async {
      await eatLunch(monday);
      await planLunch(tuesday);

      final week = await plan
          .watchRange(
            ownerId: ownerId,
            from: monday,
            to: monday.add(const Duration(days: 6)),
          )
          .first;

      expect(week, hasLength(2));
      expect(week.first.foodName, 'Dal dhokli');
      expect(week.first.mealSlotName, 'Lunch');
      expect(week.first.servingLabel, '1 bowl');
      expect(week.first.isEaten, isTrue);
      expect(week.last.isPlanned, isTrue);
    },
  );
}
