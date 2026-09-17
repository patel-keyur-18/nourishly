import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly/app/app.dart';
import 'package:nourishly/app/providers.dart';
import 'package:nourishly/app/router.dart';
import 'package:nourishly/features/food_catalog/data/food_catalog_providers.dart';
import 'package:nourishly/features/reminders/data/local_notification_scheduler.dart';
import 'package:nourishly/features/reminders/data/reminder_providers.dart';
import 'package:nourishly_data/nourishly_data.dart';
import 'package:nourishly_domain/nourishly_domain.dart';

void main() {
  late NourishlyDatabase db;
  final now = DateTime(2026, 9, 17, 12, 0);

  setUp(() async {
    db = NourishlyDatabase.forTesting();
    final ownerId = await ensureDefaultOwner(db);
    await PreferencesDao(db).update(ownerId, onboardingSeen: true);
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
        .into(db.nutrients)
        .insert(
          NutrientsCompanion.insert(
            id: 'energy',
            groupId: 'macro',
            displayName: 'Energy',
            canonicalUnit: 'kcal',
            displayPrecision: 0,
            defaultCurveType: 'range',
            isLimitNutrient: false,
            sortOrder: 0,
            isCore: true,
            minCoverageForScoring: 0.5,
          ),
        );
    await db
        .into(db.nutrients)
        .insert(
          NutrientsCompanion.insert(
            id: 'protein',
            groupId: 'macro',
            displayName: 'Protein',
            canonicalUnit: 'g',
            displayPrecision: 1,
            defaultCurveType: 'floor',
            isLimitNutrient: false,
            sortOrder: 1,
            isCore: true,
            minCoverageForScoring: 0.5,
          ),
        );
    await db
        .into(db.foodItems)
        .insert(
          FoodItemsCompanion.insert(
            id: 'food-dal',
            kind: 'ingredient',
            canonicalName: 'Dal',
            qualityTier: 'verified',
            provenanceSource: 'usda',
          ),
        );
    await db
        .into(db.servingSizes)
        .insert(
          ServingSizesCompanion.insert(
            id: 'serving-dal',
            foodId: 'food-dal',
            label: '1 katori',
            grams: 200,
          ),
        );
    await db
        .into(db.foodNutrientValues)
        .insert(
          FoodNutrientValuesCompanion.insert(
            id: 'fnv-1',
            foodId: 'food-dal',
            nutrientId: 'energy',
            amountPer100g: 120,
            valueSource: 'measured',
          ),
        );
    // Protein deliberately has no row — AP-4: renders as "—", never 0.
  });

  tearDown(() => db.close());

  Future<void> pumpPortion(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nourishlyDatabaseProvider.overrideWithValue(db),
          catalogReadyProvider.overrideWith((ref) async {}),
          clockProvider.overrideWithValue(FakeClock(now)),
          reminderSchedulerProvider.overrideWithValue(NoopReminderScheduler()),
        ],
        child: const NourishlyApp(),
      ),
    );
    await tester.pump();
    appRouter.go('/log/food/food-dal');
    await tester.pumpAndSettle();
  }

  testWidgets('shows computed energy for the selected serving', (
    tester,
  ) async {
    await pumpPortion(tester);
    // 1 katori (200 g) at 120 kcal/100g = 240 kcal.
    expect(find.textContaining('240'), findsWidgets);
  });

  testWidgets('a nutrient with no data renders as em dash, not zero', (
    tester,
  ) async {
    await pumpPortion(tester);
    expect(find.text('—'), findsWidgets);
    expect(find.text('0 g'), findsNothing);
  });

  testWidgets('the stale Phase 3 sentence is gone', (tester) async {
    await pumpPortion(tester);
    expect(find.textContaining('Phase 3 aggregation'), findsNothing);
  });
}
