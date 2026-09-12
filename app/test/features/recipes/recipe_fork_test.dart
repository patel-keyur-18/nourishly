import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly/app/app.dart';
import 'package:nourishly/app/router.dart';
import 'package:nourishly/features/food_catalog/data/food_catalog_providers.dart';
import 'package:nourishly/features/reminders/data/local_notification_scheduler.dart';
import 'package:nourishly/features/reminders/data/reminder_providers.dart';
import 'package:nourishly_data/nourishly_data.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// "Make this our version": forking a catalog recipe into one of your own,
/// which is how a household that cooks in less oil records that without
/// anyone inventing a number.
///
/// The catalog row is an estimate of how a dish is generally made. A fork
/// is recomputed from its own ingredients by the same arithmetic, so the
/// household's version is as traceable as the original — and the original
/// is left exactly as it was.
void main() {
  late NourishlyDatabase db;
  late String ownerId;
  late String catalogRecipeId;

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
      batch.insert(
        db.nutrients,
        NutrientsCompanion.insert(
          id: 'energy',
          groupId: 'macronutrients',
          displayName: 'Energy',
          canonicalUnit: 'kcal',
          displayPrecision: 0,
          defaultCurveType: 'floor',
          isLimitNutrient: false,
          sortOrder: 0,
          isCore: true,
          minCoverageForScoring: 0.6,
        ),
      );
    });

    Future<String> ingredient(String name, double kcalPer100g) async {
      final id = _uuid.v7();
      await db
          .into(db.foodItems)
          .insert(
            FoodItemsCompanion.insert(
              id: id,
              kind: 'ingredient',
              canonicalName: name,
              qualityTier: 'verified',
              provenanceSource: 'usda_fdc',
              dietClass: const Value('vegan'),
            ),
          );
      await db
          .into(db.foodNutrientValues)
          .insert(
            FoodNutrientValuesCompanion.insert(
              id: _uuid.v7(),
              foodId: id,
              nutrientId: 'energy',
              amountPer100g: kcalPer100g,
              valueSource: 'measured',
            ),
          );
      return id;
    }

    final potato = await ingredient('Potato', 77);
    final oil = await ingredient('Groundnut oil', 884);

    // A catalog recipe: ownerId null is what makes it the bundled
    // catalog's rather than this profile's (§22.5).
    catalogRecipeId = _uuid.v7();
    await db
        .into(db.foodItems)
        .insert(
          FoodItemsCompanion.insert(
            id: catalogRecipeId,
            kind: 'recipe',
            canonicalName: 'Bataka nu shaak',
            qualityTier: 'derived',
            provenanceSource: 'catalog_pipeline_recipe',
            yieldFactor: const Value(1.11),
            dietClass: const Value('vegan'),
          ),
        );
    final servingId = _uuid.v7();
    await db
        .into(db.servingSizes)
        .insert(
          ServingSizesCompanion.insert(
            id: servingId,
            foodId: catalogRecipeId,
            label: '1 katori',
            grams: 120,
            isDefault: const Value(true),
          ),
        );
    await db.batch((batch) {
      batch.insert(
        db.recipeComponents,
        RecipeComponentsCompanion.insert(
          id: _uuid.v7(),
          recipeFoodItemId: catalogRecipeId,
          ingredientFoodItemId: potato,
          quantityGrams: 100,
          sortOrder: const Value(0),
        ),
      );
      batch.insert(
        db.recipeComponents,
        RecipeComponentsCompanion.insert(
          id: _uuid.v7(),
          recipeFoodItemId: catalogRecipeId,
          ingredientFoodItemId: oil,
          quantityGrams: 8,
          sortOrder: const Value(1),
        ),
      );
    });
  });

  tearDown(() => db.close());

  /// `pumpAndSettle` cannot be used anywhere in this file: the builder's
  /// text fields blink a cursor forever once focused, so "settled" never
  /// arrives. Pumping a fixed span is the standard substitute.
  Future<void> settle(WidgetTester tester, {int frames = 20}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> openLighterSheet(WidgetTester tester) async {
    await tester.tap(find.text('Use less oil'));
    await settle(tester);
  }

  Future<void> pumpTo(
    WidgetTester tester,
    String location, {
    Size size = const Size(390, 1800),
  }) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nourishlyDatabaseProvider.overrideWithValue(db),
          catalogReadyProvider.overrideWith((ref) async {}),
          reminderSchedulerProvider.overrideWithValue(NoopReminderScheduler()),
        ],
        child: const NourishlyApp(),
      ),
    );
    // Not `pumpAndSettle`: `appRouter` is a module-level singleton, so the
    // first frame of a later test in this file rebuilds whatever screen the
    // previous one left, focused text field and all — and a blinking cursor
    // means "settled" never arrives.
    await settle(tester);
    appRouter.go(location);
    await settle(tester);
  }

  testWidgets('a fork opens pre-filled from the catalog dish', (tester) async {
    await pumpTo(tester, '/recipes/new?from=$catalogRecipeId');

    expect(find.text('Your version'), findsOneWidget);
    // Named so it is not mistaken for the catalog row in a search.
    expect(find.text('Bataka nu shaak (our version)'), findsOneWidget);
    // Every ingredient copied, with its grams — the point is to change one
    // number, not to start again.
    expect(find.text('Potato'), findsOneWidget);
    expect(find.text('Groundnut oil'), findsOneWidget);
  });

  testWidgets('"use less oil" halves the fat and leaves the food alone', (
    tester,
  ) async {
    await pumpTo(tester, '/recipes/new?from=$catalogRecipeId');

    await openLighterSheet(tester);

    // One line per cooking fat; the potato is the dish, not the pan.
    expect(find.byType(CheckboxListTile), findsOneWidget);
    expect(find.text('8 g  →  4 g'), findsOneWidget);
    expect(find.text('4 g less fat in the pot.'), findsOneWidget);

    await tester.tap(find.text('Apply'));
    await settle(tester);

    // The oil is halved in the form; the potato is untouched. The grams
    // field renders the number with a separate 'g' suffix, so these match
    // the number alone.
    expect(find.widgetWithText(TextField, '4'), findsOneWidget);
    expect(find.widgetWithText(TextField, '100'), findsOneWidget);
  });

  testWidgets('unticking a fat leaves that one alone', (tester) async {
    // The reason the sheet asks per line: absorbed frying oil is not a
    // dial the cook turns, and a stored recipe cannot tell it from pan oil.
    await pumpTo(tester, '/recipes/new?from=$catalogRecipeId');

    await openLighterSheet(tester);
    await tester.tap(find.byType(CheckboxListTile).first);
    await settle(tester);

    expect(find.text('Nothing selected.'), findsOneWidget);
  });

  testWidgets('saving a fork leaves the catalog row untouched', (tester) async {
    await pumpTo(tester, '/recipes/new?from=$catalogRecipeId');
    await tester.tap(find.text('Save recipe'));
    // Long enough for the "Recipe saved" snack to expire as well: a
    // SnackBar holds a timer, and a timer still pending when the tree is
    // torn down fails the test.
    await settle(tester, frames: 80);

    final catalogRow = await (db.select(
      db.foodItems,
    )..where((f) => f.id.equals(catalogRecipeId))).getSingle();
    expect(catalogRow.canonicalName, 'Bataka nu shaak');
    expect(catalogRow.ownerId, isNull, reason: 'still the catalog\'s');
    expect(catalogRow.revision, 1, reason: 'never rewritten');

    // And the fork is a separate food this profile owns.
    final mine = await RecipeDao(db).recipesFor(ownerId);
    expect(mine, hasLength(1));
    expect(mine.single.name, 'Bataka nu shaak (our version)');
    expect(mine.single.foodId, isNot(catalogRecipeId));
    expect(mine.single.ingredients, hasLength(2));
  });
}
