import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly/app/app.dart';
import 'package:nourishly/app/router.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: NourishlyApp()));
    await tester.pumpAndSettle();
  }

  testWidgets('starts on the Today dashboard', (tester) async {
    await pumpApp(tester);

    expect(find.text('Today'), findsWidgets); // app bar title + nav label
    expect(find.text('Insights'), findsOneWidget); // nav label only
  });

  testWidgets(
    'the bottom nav has all four destinations and the centre action',
    (tester) async {
      await pumpApp(tester);

      expect(find.text('Today'), findsWidgets);
      expect(find.text('Insights'), findsOneWidget);
      expect(find.text('Water'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    },
  );

  testWidgets(
    'tapping Water switches tabs and preserves the Today tab underneath',
    (tester) async {
      await pumpApp(tester);

      await tester.tap(find.text('Water'));
      await tester.pumpAndSettle();
      expect(
        find.text('Hydration tracking lands here alongside food logging.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Today').last);
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Your daily dashboard lands here once logging and targets exist.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'the centre action opens the log flow modally over the current tab',
    (tester) async {
      await pumpApp(tester);

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Log food or water'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // Dismisses back to the tab the user was on, not a detached screen.
      expect(
        find.text(
          'Your daily dashboard lands here once logging and targets exist.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('Profile tab shows its Goals entry point', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(FilledButton, 'Goals & targets'),
      findsOneWidget,
    );
  });

  testWidgets('/profile/goals resolves to the nested Goals screen (§28.5)', (
    tester,
  ) async {
    await pumpApp(tester);

    appRouter.go('/profile/goals');
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Derived targets and per-nutrient overrides land here in Phase 3.',
      ),
      findsOneWidget,
    );
  });
}
