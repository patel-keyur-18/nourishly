import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly/app/app.dart';
import 'package:nourishly/app/router.dart';
import 'package:nourishly/features/food_catalog/data/food_catalog_providers.dart';
import 'package:nourishly_data/nourishly_data.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

Future<String> _seedFood(
  NourishlyDatabase db,
  FoodSearchDao dao, {
  required String name,
  List<String> altNames = const [],
}) async {
  final id = _uuid.v7();
  await db
      .into(db.foodItems)
      .insert(
        FoodItemsCompanion.insert(
          id: id,
          kind: 'ingredient',
          canonicalName: name,
          qualityTier: 'verified',
          provenanceSource: 'test',
        ),
      );
  await dao.indexFood(foodId: id, canonicalName: name, altNames: altNames);
  return id;
}

void main() {
  late NourishlyDatabase db;
  late FoodSearchDao dao;

  setUp(() {
    db = NourishlyDatabase.forTesting();
    dao = FoodSearchDao(db);
  });
  tearDown(() => db.close());

  Future<void> pumpToLogScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [nourishlyDatabaseProvider.overrideWithValue(db)],
        child: const NourishlyApp(),
      ),
    );
    await tester.pumpAndSettle();
    // Navigate directly rather than tapping the FAB: appRouter is a
    // module-level singleton, so its location otherwise carries over
    // between tests in this file (each gets a fresh widget tree, but not
    // a fresh router).
    appRouter.go('/log');
    await tester.pumpAndSettle();
  }

  testWidgets(
    'shows a prompt, not results or an error, before any query is typed',
    (tester) async {
      await _seedFood(db, dao, name: 'Paneer');
      await pumpToLogScreen(tester);

      expect(find.text('Search for a food to log.'), findsOneWidget);
    },
  );

  testWidgets('typing debounces before showing matching results', (
    tester,
  ) async {
    await _seedFood(db, dao, name: 'Paneer', altNames: ['panir']);
    await _seedFood(db, dao, name: 'Rice, white, cooked');
    await pumpToLogScreen(tester);

    await tester.enterText(find.byType(TextField), 'panir');
    // Still within the debounce window — the query hasn't been committed yet.
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.text('Search for a food to log.'), findsOneWidget);

    // Past the ~120ms debounce (§14.7).
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pumpAndSettle();

    expect(find.text('Paneer'), findsOneWidget);
    expect(find.text('Rice, white, cooked'), findsNothing);
  });

  testWidgets('an alt-name query finds the food by its canonical name', (
    tester,
  ) async {
    await _seedFood(
      db,
      dao,
      name: 'Paneer',
      altNames: ['panir', 'cottage cheese'],
    );
    await pumpToLogScreen(tester);

    await tester.enterText(find.byType(TextField), 'cottage cheese');
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();

    expect(find.text('Paneer'), findsOneWidget);
  });

  testWidgets('zero results still pins "Create as a custom food" (UX-6)', (
    tester,
  ) async {
    await _seedFood(db, dao, name: 'Paneer');
    await pumpToLogScreen(tester);

    await tester.enterText(find.byType(TextField), 'nonexistent xyz');
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();

    expect(find.text('Paneer'), findsNothing);
    expect(
      find.text('Create "nonexistent xyz" as a custom food'),
      findsOneWidget,
    );
  });

  testWidgets('the quality tier badge renders on a result', (tester) async {
    await _seedFood(db, dao, name: 'Paneer');
    await pumpToLogScreen(tester);

    await tester.enterText(find.byType(TextField), 'paneer');
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();

    expect(find.text('verified'), findsOneWidget);
  });
}
