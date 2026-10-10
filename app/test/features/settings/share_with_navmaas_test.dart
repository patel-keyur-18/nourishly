import 'package:flutter/material.dart';
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

/// Settings → Your data → Share with Navmaas (ADR-012): off by default,
/// one tap on, one tap off, and it says plainly what is shared.
void main() {
  late NourishlyDatabase db;
  late String ownerId;

  setUp(() async {
    db = NourishlyDatabase.forTesting();
    ownerId = await ensureDefaultOwner(db);
    await PreferencesDao(db).update(ownerId, onboardingSeen: true);
  });

  tearDown(() => db.close());

  Future<void> pumpSettings(WidgetTester tester) async {
    // Tall enough that the Your data group is built (a lazy ListView).
    tester.view.physicalSize = const Size(390, 2600) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nourishlyDatabaseProvider.overrideWithValue(db),
          catalogReadyProvider.overrideWith((ref) async {}),
          clockProvider.overrideWithValue(FakeClock(DateTime(2026, 10, 10))),
          reminderSchedulerProvider.overrideWithValue(NoopReminderScheduler()),
        ],
        child: const NourishlyApp(),
      ),
    );
    await tester.pump();
    appRouter.go('/profile');
    await tester.pumpAndSettle();
  }

  Future<bool> sharing() async =>
      (await PreferencesDao(db).forOwner(ownerId)).shareWithNavmaas;

  testWidgets('off by default; on and off again with a tap', (tester) async {
    await pumpSettings(tester);
    expect(find.text('Share with Navmaas'), findsOneWidget);
    expect(find.text('Off'), findsWidgets);
    expect(find.textContaining('Navmaas, on this phone only'), findsNothing);

    await tester.tap(find.text('Share with Navmaas'));
    await tester.pumpAndSettle();
    expect(
      find.text('On · meals and six day totals, last 90 days'),
      findsOneWidget,
    );
    expect(find.textContaining('Navmaas, on this phone only'), findsOneWidget);
    expect(await tester.runAsync(sharing), isTrue);

    await tester.tap(find.text('Share with Navmaas'));
    await tester.pumpAndSettle();
    expect(await tester.runAsync(sharing), isFalse);
    expect(find.textContaining('Navmaas, on this phone only'), findsNothing);
  });
}
