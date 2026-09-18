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

/// Item 8 of the 2026-09-12 UX revision: **no message is permanent.**
///
/// "Removed 200 ml" was the reported case — it stayed on screen until
/// something else replaced it. No call site set a duration, nothing cleared
/// the previous message, and Flutter suppresses its own dismiss timer in
/// more cases than is obvious, so the behaviour depended on where you were
/// standing when you tapped.
void main() {
  late NourishlyDatabase db;
  late String ownerId;
  final now = DateTime(2026, 9, 12, 10, 0);

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

  testWidgets('removing water says so, then stops saying so', (tester) async {
    await WaterLogDao(
      db,
    ).logWater(ownerId: ownerId, volumeMl: 200, logDate: DateTime(2026, 9, 12));
    await pumpWater(tester);

    await tester.tap(find.text('Remove').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Removed 200 ml'), findsOneWidget);

    // Five seconds, as asked for — and gone without anything replacing it,
    // which is the part that was broken.
    await tester.pump(nourishlySnackDuration + const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.textContaining('Removed 200 ml'), findsNothing);
  });

  testWidgets('the message can be dismissed by hand before that', (
    tester,
  ) async {
    await WaterLogDao(
      db,
    ).logWater(ownerId: ownerId, volumeMl: 250, logDate: DateTime(2026, 9, 12));
    await pumpWater(tester);

    await tester.tap(find.text('Remove').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Removed 250 ml'), findsOneWidget);

    await tester.drag(find.byType(SnackBar), const Offset(400, 0));
    await tester.pumpAndSettle();
    expect(find.textContaining('Removed 250 ml'), findsNothing);
  });

  testWidgets('two taps do not queue two messages', (tester) async {
    await pumpWater(tester);

    await tester.tap(find.text('+250 ml'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+500 ml'));
    await tester.pumpAndSettle();

    // One at a time: the second replaces the first rather than waiting
    // five seconds behind it.
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('Logged 500 ml'), findsOneWidget);

    await tester.pump(nourishlySnackDuration + const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });
}
