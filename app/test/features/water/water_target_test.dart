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
  late String ownerId;
  final now = DateTime(2026, 9, 17, 10, 0);

  setUp(() async {
    db = NourishlyDatabase.forTesting();
    ownerId = await ensureDefaultOwner(db);
    await PreferencesDao(db).update(ownerId, onboardingSeen: true);
  });

  tearDown(() => db.close());

  Future<void> pumpWater(WidgetTester tester) async {
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
    appRouter.go('/water');
    await tester.pumpAndSettle();
  }

  testWidgets('with a derived target set, the percentage matches the target, '
      'not a hardcoded default', (tester) async {
    const targetSetId = 'target-set-1';
    await db
        .into(db.targetSets)
        .insert(
          TargetSetsCompanion.insert(
            id: targetSetId,
            ownerId: ownerId,
            effectiveFrom: now.subtract(const Duration(days: 1)),
            derivationSource: 'derived',
            rulesetVersion: '2026.09',
          ),
        );
    await db
        .into(db.nutrientTargets)
        .insert(
          NutrientTargetsCompanion.insert(
            id: 'nt-water',
            targetSetId: targetSetId,
            nutrientId: 'water',
            targetAmount: 3000,
            curveType: 'range',
            tolerance: 0.1,
          ),
        );
    await WaterLogDao(db).logWater(
      ownerId: ownerId,
      volumeMl: 1500,
      logDate: DateTime(2026, 9, 17),
    );

    await pumpWater(tester);

    // 1500 / 3000 = 50%, not 1500/2600 ≈ 58%.
    expect(find.textContaining('50%'), findsOneWidget);
    expect(find.textContaining('58%'), findsNothing);
  });

  testWidgets('with no target set, falls back to a stated default', (
    tester,
  ) async {
    await pumpWater(tester);
    expect(find.textContaining('% of default'), findsOneWidget);
  });
}
