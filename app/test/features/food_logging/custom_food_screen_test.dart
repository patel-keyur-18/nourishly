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

/// Same interruption-prone kitchen scenario as FoodPortionScreen, on a
/// form with seven fields instead of a couple of chip taps — this one is
/// arguably more painful to lose mid-entry.
///
/// Both scenarios below share one testWidgets body: the restoration
/// bucket is keyed by a bare 'custom_food' id (not per-food, since a
/// custom food has no id until it's saved), so two separate testWidgets
/// blocks in this file would leak restoration state from one into the
/// next via the test binding's single RestorationManager.
void main() {
  late NourishlyDatabase db;
  final now = DateTime(2026, 9, 17, 12, 0);

  setUp(() async {
    db = NourishlyDatabase.forTesting();
    final ownerId = await ensureDefaultOwner(db);
    await PreferencesDao(db).update(ownerId, onboardingSeen: true);
  });

  tearDown(() => db.close());

  testWidgets(
    'a route-supplied name prefills, and typed fields survive a '
    'simulated state restoration',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nourishlyDatabaseProvider.overrideWithValue(db),
            catalogReadyProvider.overrideWith((ref) async {}),
            clockProvider.overrideWithValue(FakeClock(now)),
            reminderSchedulerProvider.overrideWithValue(
              NoopReminderScheduler(),
            ),
          ],
          child: const NourishlyApp(),
        ),
      );
      await tester.pump();
      appRouter.go('/log/new?name=Bhinda%20nu%20shaak');
      await tester.pumpAndSettle();

      // The failed-search escape hatch prefills the name from the query.
      expect(find.text('Bhinda nu shaak'), findsOneWidget);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(2), '180');
      await tester.enterText(fields.at(3), '220');
      await tester.pump();
      expect(find.text('180'), findsOneWidget);
      expect(find.text('220'), findsOneWidget);

      // Destroys and recreates the whole widget tree from restoration
      // data — see food_portion_screen_test.dart for why this, not
      // restoreFrom, is the real test of RestorationMixin.
      await tester.restartAndRestore();
      await tester.pumpAndSettle();

      expect(find.text('Bhinda nu shaak'), findsOneWidget);
      expect(find.text('180'), findsOneWidget);
      expect(find.text('220'), findsOneWidget);
    },
  );
}
