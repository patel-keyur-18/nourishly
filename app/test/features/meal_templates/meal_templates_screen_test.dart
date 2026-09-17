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
import 'package:nourishly_ui/nourishly_ui.dart';

void main() {
  late NourishlyDatabase db;
  late String ownerId;
  final now = DateTime(2026, 9, 17, 12, 0);

  setUp(() async {
    db = NourishlyDatabase.forTesting();
    ownerId = await ensureDefaultOwner(db);
    await PreferencesDao(db).update(ownerId, onboardingSeen: true);
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
            grams: 150,
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
    await MealTemplateDao(db).createFromEntries(
      ownerId: ownerId,
      name: 'Usual lunch',
      defaultMealSlotId: 'slot-lunch',
      items: const [
        MealTemplateItemInput(
          foodId: 'food-dal',
          servingSizeId: 'serving-dal',
          quantity: 2,
        ),
      ],
    );
  });

  tearDown(() => db.close());

  Future<void> pumpTemplates(WidgetTester tester) async {
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
    appRouter.go('/templates');
    await tester.pumpAndSettle();
  }

  testWidgets('shows the saved template with its contents', (tester) async {
    await pumpTemplates(tester);
    expect(find.text('Usual lunch'), findsOneWidget);
    expect(find.textContaining('Dal'), findsOneWidget);
    expect(find.text('Lunch'), findsOneWidget);
  });

  testWidgets('Log this meal creates a food log entry for today', (
    tester,
  ) async {
    await pumpTemplates(tester);
    await tester.tap(find.text('Log this meal'));
    await tester.pumpAndSettle();

    final entries = await db.select(db.foodLogEntries).get();
    expect(entries, hasLength(1));
    expect(entries.single.foodId, 'food-dal');
    expect(entries.single.mealSlotId, 'slot-lunch');
    expect(find.textContaining('Logged 1 item'), findsOneWidget);

    // Flush the snackbar's auto-dismiss timer so it isn't still pending
    // when the test ends (matches water_message_test.dart's pattern).
    await tester.pump(nourishlySnackDuration + const Duration(seconds: 1));
    await tester.pumpAndSettle();
  });

  testWidgets('deleting a template removes its card', (tester) async {
    await pumpTemplates(tester);
    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(find.text('Usual lunch'), findsNothing);
    expect(find.textContaining('Nothing here yet'), findsOneWidget);
  });
}
