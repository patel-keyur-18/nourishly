import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly/app/providers.dart';
import 'package:nourishly/features/food_catalog/data/food_catalog_providers.dart';
import 'package:nourishly/features/meal_plan/presentation/widgets/planned_meal_card.dart';
import 'package:nourishly_data/nourishly_data.dart';
import 'package:nourishly_ui/nourishly_ui.dart';

/// The confirm flow has to be one tap when the plan was right, and it has
/// to say "planned" in a way that survives greyscale — a dashed edge and a
/// coloured chip are not two signals if both are colour.
void main() {
  late NourishlyDatabase db;
  late String ownerId;
  late FoodLoggingDao logging;

  final today = DateTime(2026, 9, 22);

  setUp(() async {
    db = NourishlyDatabase.forTesting();
    ownerId = await ensureDefaultOwner(db);
    logging = FoodLoggingDao(db);

    await db
        .into(db.foodItems)
        .insert(
          FoodItemsCompanion.insert(
            id: 'food-dhokli',
            kind: 'recipe',
            canonicalName: 'Dal dhokli',
            qualityTier: 'derived',
            provenanceSource: 'catalog_pipeline_recipe',
          ),
        );
    await db
        .into(db.servingSizes)
        .insert(
          ServingSizesCompanion.insert(
            id: 'serving-bowl',
            foodId: 'food-dhokli',
            label: '1 bowl',
            grams: 320,
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
            foodId: 'food-dhokli',
            nutrientId: 'energy',
            amountPer100g: 130,
            valueSource: 'measured',
          ),
        );
  });

  tearDown(() => db.close());

  Future<String> planLunch() => logging.logFood(
    ownerId: ownerId,
    foodId: 'food-dhokli',
    servingId: 'serving-bowl',
    quantity: 1,
    mealSlotId: 'slot-lunch',
    logDate: today,
    status: logStatusPlanned,
    source: 'plan',
  );

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nourishlyDatabaseProvider.overrideWithValue(db),
          todayProvider.overrideWithValue(today),
        ],
        child: MaterialApp(
          theme: NourishlyTheme.light(),
          home: const Scaffold(body: PlannedMealsSection()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a planned meal says so in words, not only in colour', (
    tester,
  ) async {
    await planLunch();
    await pump(tester);

    expect(find.text('Dal dhokli'), findsOneWidget);
    expect(find.text('Planned'), findsOneWidget);
    // A plain chip, never StatusChip's reserved nutrient palette.
    expect(find.byType(NourishlyChip), findsOneWidget);
    expect(find.byType(StatusChip), findsNothing);
    expect(find.textContaining('not counted yet'), findsOneWidget);
    expect(find.text('Ate it'), findsOneWidget);
  });

  testWidgets('nothing planned means nothing on screen', (tester) async {
    await pump(tester);
    expect(find.byType(NourishlyChip), findsNothing);
  });

  testWidgets('one tap confirms it and the card goes', (tester) async {
    await planLunch();
    await pump(tester);

    await tester.tap(find.text('Ate it'));
    await tester.pumpAndSettle();

    final entry = await db.select(db.foodLogEntries).getSingle();
    expect(entry.status, logStatusLogged);
    expect(find.text('Ate it'), findsNothing);

    await tester.pump(nourishlySnackDuration + const Duration(seconds: 1));
  });

  testWidgets('skip keeps the row rather than deleting it', (tester) async {
    await planLunch();
    await pump(tester);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    final entry = await db.select(db.foodLogEntries).getSingle();
    expect(entry.status, logStatusSkipped);
    expect(entry.deletedAt, isNull);

    await tester.pump(nourishlySnackDuration + const Duration(seconds: 1));
  });
}
