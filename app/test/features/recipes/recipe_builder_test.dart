import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly/app/app.dart';
import 'package:nourishly/app/router.dart';
import 'package:nourishly/features/reminders/data/local_notification_scheduler.dart';
import 'package:nourishly/features/reminders/data/reminder_providers.dart';
import 'package:nourishly/features/food_catalog/data/food_catalog_providers.dart';
import 'package:nourishly_data/nourishly_data.dart';
import 'package:nourishly_ui/nourishly_ui.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

void main() {
  late NourishlyDatabase db;
  late String ownerId;

  setUp(() async {
    db = NourishlyDatabase.forTesting();
    ownerId = await ensureDefaultOwner(db);
    await PreferencesDao(db).update(ownerId, onboardingSeen: true);
    await db.batch((batch) {
      batch.insert(
        db.nutrientGroups,
        NutrientGroupsCompanion.insert(
          id: 'macronutrients',
          name: 'Macronutrients',
          sortOrder: 0,
        ),
      );
      var order = 0;
      for (final (id, name, unit) in const [
        ('energy', 'Energy', 'kcal'),
        ('protein', 'Protein', 'g'),
      ]) {
        batch.insert(
          db.nutrients,
          NutrientsCompanion.insert(
            id: id,
            groupId: 'macronutrients',
            displayName: name,
            canonicalUnit: unit,
            displayPrecision: 0,
            defaultCurveType: 'floor',
            isLimitNutrient: false,
            sortOrder: order++,
            isCore: true,
            minCoverageForScoring: 0.6,
          ),
        );
      }
    });
  });

  tearDown(() => db.close());

  Future<String> seedIngredient(
    String name,
    Map<String, double> per100g,
  ) async {
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
            dietClass: const Value('vegan'),
          ),
        );
    await db.batch((batch) {
      for (final entry in per100g.entries) {
        batch.insert(
          db.foodNutrientValues,
          FoodNutrientValuesCompanion.insert(
            id: _uuid.v7(),
            foodId: id,
            nutrientId: entry.key,
            amountPer100g: entry.value,
            valueSource: 'analytical',
          ),
        );
      }
    });
    await FoodSearchDao(db)
        .indexFood(foodId: id, canonicalName: name, altNames: const []);
    return id;
  }

  /// [size] defaults to a deliberately tall window so the whole form is on
  /// screen at once: a `ListView` builds its children lazily, so on a
  /// phone-sized view the serving fields and the preview are simply not in
  /// the tree and nothing can be typed into them. Pass a real phone size to
  /// test what a phone actually shows.
  Future<void> pumpTo(
    WidgetTester tester,
    String location, {
    Size size = const Size(390, 1800),
    double keyboardInset = 0,
  }) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    tester.view.viewInsets = FakeViewPadding(bottom: keyboardInset * 3);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nourishlyDatabaseProvider.overrideWithValue(db),
          catalogReadyProvider.overrideWith((ref) async {}),
          // No notification plugin answers a widget test, and a screen
          // that needs one is a screen that cannot be tested (§29.3's
          // port exists for exactly this).
          reminderSchedulerProvider.overrideWithValue(NoopReminderScheduler()),
        ],
        child: const NourishlyApp(),
      ),
    );
    await tester.pumpAndSettle();
    // appRouter is a module-level singleton, so its location carries over
    // between tests in this file.
    appRouter.go(location);
    await tester.pumpAndSettle();
  }

  testWidgets('an empty recipe list explains what a recipe is', (tester) async {
    await pumpTo(tester, '/recipes');

    expect(find.text('Nothing here yet.'), findsOneWidget);
    expect(find.text('New recipe'), findsOneWidget);
  });

  testWidgets('building a recipe end to end saves a loggable food', (
    tester,
  ) async {
    await seedIngredient('Toor dal', {'energy': 343, 'protein': 22});

    await pumpTo(tester, '/recipes/new');

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Everyday dal',
    );

    // Add the dal. The section header's action and the dialog's confirm
    // button are both called "Add", so the header one is found through it.
    await tester.tap(
      find.descendant(
        of: find.byType(NourishlySectionHeader),
        matching: find.text('Add'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('ingredient-search')), 'toor');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Toor dal').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Raw weight'), '200');
    // The dialog's Add button stays disabled until the weight is a real
    // number, so the frame that enables it has to happen before the tap.
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    // What came out, and what a serving is.
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Cooked weight (g)'),
      '500',
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Weighs (g)'),
      '150',
    );
    await tester.pumpAndSettle();

    // The preview does the §19.10 arithmetic before anything is saved:
    // 200 g of dal at 343 kcal/100 g is 686 kcal, in 500 g of dal, so a
    // 150 g katori is 206 kcal.
    expect(find.textContaining('200 g in, 500 g out'), findsOneWidget);
    expect(find.text('206 kcal'), findsOneWidget);

    await tester.tap(find.text('Save recipe'));
    await tester.pumpAndSettle();
    // The confirmation message is a real timer; pump past it so the test
    // does not end with one pending.
    await tester.pump(nourishlySnackDuration + const Duration(seconds: 1));
    await tester.pumpAndSettle();

    final saved = (await RecipeDao(db).recipesFor(ownerId)).single;
    expect(saved.name, 'Everyday dal');
    expect(saved.yieldFactor, closeTo(2.5, 1e-9));

    // And it is a food like any other: searchable, with a serving.
    final found = await FoodSearchDao(db).search('everyday');
    expect(found.single.id, saved.foodId);
    expect(found.single.kind, 'recipe');
  });

  /// The conditions the ingredient picker was reported broken under, which
  /// nothing else in this file covers: the other tests use a deliberately
  /// tall 390 × 1800 window so the whole form is reachable, and the sheet
  /// asked for a flat `0.7 × screenHeight` plus the keyboard inset on top
  /// of that — a size that takes no account of what is left. Its search
  /// field is autofocused, so the keyboard is always up.
  testWidgets('the ingredient picker fits a small screen with the keyboard '
      'up', (tester) async {
    await seedIngredient('Toor dal', {'energy': 343, 'protein': 22});

    // A small phone, and the space a keyboard takes on one.
    await pumpTo(
      tester,
      '/recipes/new',
      size: const Size(360, 640),
      keyboardInset: 336,
    );
    await tester.tap(
      find.descendant(
        of: find.byType(NourishlySectionHeader),
        matching: find.text('Add'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ingredient-search')), findsOneWidget);
    expect(
      tester.takeException(),
      isNull,
      reason: 'the ingredient sheet overflows with the keyboard up',
    );

    // Above the keyboard, not behind it: the search field is the control
    // the sheet autofocuses, so if it is under the keyboard the sheet is
    // unusable however it was sized.
    final field = tester.getRect(find.byKey(const Key('ingredient-search')));
    expect(
      field.bottom,
      lessThanOrEqualTo(640 - 336),
      reason: 'the search field is behind the keyboard',
    );

    // And it is still usable at that size, not merely non-overflowing.
    await tester.enterText(find.byKey(const Key('ingredient-search')), 'toor');
    await tester.pumpAndSettle();
    expect(find.text('Toor dal'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a recipe with no ingredients is refused, with a reason', (
    tester,
  ) async {
    await pumpTo(tester, '/recipes/new');

    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Air');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Weighs (g)'),
      '150',
    );
    await tester.tap(find.text('Save recipe'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Add at least one ingredient'), findsOneWidget);
    expect(await RecipeDao(db).recipesFor(ownerId), isEmpty);

    await tester.pump(nourishlySnackDuration + const Duration(seconds: 1));
    await tester.pumpAndSettle();
  });
}
