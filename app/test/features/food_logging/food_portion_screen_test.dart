import 'package:flutter/material.dart';
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
import 'package:nourishly_ui/nourishly_ui.dart' show nourishlySnackDuration;

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

  /// The screen's own list, not the grams box's single-line scrollable.
  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows computed energy for the selected serving', (tester) async {
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

  testWidgets('the entry is stamped with the chosen time, not the wall '
      'clock', (tester) async {
    await pumpPortion(tester);

    // The Time section sits below the serving and meal choices, so scroll
    // it into the lazy ListView rather than asserting on an unbuilt row.
    await scrollTo(tester, find.text('Eaten at'));
    await tester.pumpAndSettle();
    // Defaults to now, which is the common case of logging as you eat.
    expect(find.text('12:00 PM'), findsOneWidget);

    // "Add to log" is also the AppBar title, so aim at the save button.
    await tester.tap(
      find.descendant(
        of: find.byType(FilledButton),
        matching: find.text('Add to log'),
      ),
    );
    await tester.pumpAndSettle();

    final entry = await db.select(db.foodLogEntries).getSingle();
    // The whole point: before this, `loggedAt` came from DateTime.now(),
    // so an evening catch-up stamped every meal with the same late time.
    expect(entry.loggedAt, DateTime(2026, 9, 17, 12, 0));

    // Let the "Added to your log" snack run out its timer.
    await tester.pump(nourishlySnackDuration + const Duration(seconds: 1));
    await tester.pumpAndSettle();
  });

  testWidgets('the chosen time survives a simulated state restoration', (
    tester,
  ) async {
    await pumpPortion(tester);
    await scrollTo(tester, find.text('Eaten at'));
    await tester.pumpAndSettle();
    expect(find.text('12:00 PM'), findsOneWidget);

    await tester.restartAndRestore();
    await tester.pumpAndSettle();

    await scrollTo(tester, find.text('Eaten at'));
    await tester.pumpAndSettle();
    expect(find.text('12:00 PM'), findsOneWidget);
  });

  testWidgets('quantity survives a simulated state restoration', (
    tester,
  ) async {
    await pumpPortion(tester);

    await tester.tap(find.byIcon(Icons.add_circle_outline_rounded));
    await tester.pumpAndSettle();
    // Default 1 → 1.5 after one tap.
    expect(find.text('1.5'), findsOneWidget);

    // Destroys and recreates the whole widget tree from restoration data,
    // the way a real engine restart after the OS reclaims a backgrounded
    // app does — a plain StatefulWidget field resets to its initializer
    // here; only RestorationMixin-registered state survives this.
    await tester.restartAndRestore();
    await tester.pumpAndSettle();

    expect(find.text('1.5'), findsOneWidget);
  });

  testWidgets('a typed weight logs exactly that many grams', (tester) async {
    await pumpPortion(tester);

    // The 200 g katori is the only serving; 150 g is three quarters of it.
    await scrollTo(tester, find.byKey(const Key('portion-grams')));
    await tester.enterText(find.byKey(const Key('portion-grams')), '150');
    await tester.pumpAndSettle();
    expect(find.text('0.75'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(FilledButton),
        matching: find.text('Add to log'),
      ),
    );
    await tester.pumpAndSettle();

    final entry = await db.select(db.foodLogEntries).getSingle();
    expect(entry.gramsConsumed, closeTo(150, 1e-9));
    expect(entry.quantity, closeTo(0.75, 1e-9));
    // 150 g at 120 kcal/100g = 180 kcal.
    final energy = await db.select(db.logEntryNutrients).getSingle();
    expect(energy.amount, closeTo(180, 1e-9));

    await tester.pump(nourishlySnackDuration + const Duration(seconds: 1));
    await tester.pumpAndSettle();
  });

  testWidgets('the stepper rewrites the weight and snaps to half servings', (
    tester,
  ) async {
    await pumpPortion(tester);
    final grams = find.byKey(const Key('portion-grams'));
    await scrollTo(tester, grams);
    expect(tester.widget<TextField>(grams).controller!.text, '200');

    await tester.enterText(grams, '120');
    await tester.pumpAndSettle();
    expect(find.text('0.6'), findsOneWidget);

    // 0.6 steps up to the next half serving, 1, not to 1.1.
    await tester.tap(find.byIcon(Icons.add_circle_outline_rounded));
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);
    expect(tester.widget<TextField>(grams).controller!.text, '200');
  });

  testWidgets('an empty weight cannot be saved', (tester) async {
    await pumpPortion(tester);

    await scrollTo(tester, find.byKey(const Key('portion-grams')));
    await tester.enterText(find.byKey(const Key('portion-grams')), '');
    await tester.pumpAndSettle();

    final save = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(save.onPressed, isNull);
    expect(find.text('Enter a weight above 0 g'), findsOneWidget);
  });
}
