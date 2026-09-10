import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly/app/app.dart';
import 'package:nourishly/app/router.dart';
import 'package:nourishly/features/food_catalog/data/food_catalog_providers.dart';
import 'package:nourishly_data/nourishly_data.dart';

/// Navigation is verified through each screen's [AppBar] title, which
/// renders synchronously and doesn't depend on any database-backed
/// provider resolving — unlike screen bodies (today's log, water total),
/// which do and are exercised by their own feature tests instead.
void main() {
  late NourishlyDatabase db;

  setUp(() => db = NourishlyDatabase.forTesting());
  // Runs even when the test body throws — required so a failed assertion
  // doesn't leak a database into the next test.
  tearDown(() => db.close());

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nourishlyDatabaseProvider.overrideWithValue(db),
          catalogReadyProvider.overrideWith((ref) async {}),
        ],
        child: const NourishlyApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder appBarTitle(String text) =>
      find.descendant(of: find.byType(AppBar), matching: find.text(text));

  testWidgets('starts on Today with all four tabs and the centre action', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(appBarTitle('Today'), findsOneWidget);
    expect(find.text('Insights'), findsOneWidget); // nav label
    expect(find.text('Water'), findsOneWidget); // nav label
    expect(find.text('Profile'), findsOneWidget); // nav label
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
  });

  testWidgets('tapping a nav destination switches the visible tab', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('Water'));
    await tester.pumpAndSettle();
    expect(appBarTitle('Water'), findsOneWidget);

    await tester.tap(find.text('Insights'));
    await tester.pumpAndSettle();
    expect(appBarTitle('Insights'), findsOneWidget);

    await tester.tap(find.text('Today').last);
    await tester.pumpAndSettle();
    expect(appBarTitle('Today'), findsOneWidget);
  });

  testWidgets(
    'the centre action opens the log flow modally and dismisses back',
    (tester) async {
      await pumpApp(tester);

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      expect(appBarTitle('Log food or water'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(appBarTitle('Log food or water'), findsNothing);
      expect(appBarTitle('Today'), findsOneWidget);
    },
  );

  testWidgets('Profile tab pushes to the nested Goals screen', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();
    expect(appBarTitle('Profile'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Goals & targets'),
      findsOneWidget,
    );

    appRouter.go('/profile/goals');
    await tester.pumpAndSettle();
    expect(appBarTitle('Goals & targets'), findsOneWidget);
  });
}
