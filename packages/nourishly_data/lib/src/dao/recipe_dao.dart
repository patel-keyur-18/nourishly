import 'package:drift/drift.dart';
import 'package:nutrition_core/nutrition_core.dart';
import 'package:uuid/uuid.dart';

import '../database.dart';
import '../diet_classifier.dart';
import 'food_search_dao.dart';

const _uuid = Uuid();

/// One ingredient of a recipe, as the builder screen holds it.
class RecipeIngredient {
  const RecipeIngredient({
    required this.foodId,
    required this.name,
    required this.grams,
  });

  final String foodId;
  final String name;

  /// Raw weight going into the pot.
  final double grams;
}

/// A saved recipe, read back for editing or for its detail screen.
class SavedRecipe {
  const SavedRecipe({
    required this.foodId,
    required this.name,
    required this.ingredients,
    required this.servingGrams,
    required this.servingLabel,
    required this.cookedGrams,
    required this.yieldFactor,
    required this.dietClass,
  });

  final String foodId;
  final String name;
  final List<RecipeIngredient> ingredients;
  final double servingGrams;
  final String servingLabel;
  final double cookedGrams;
  final double yieldFactor;
  final DietClass? dietClass;

  double get rawGrams => ingredients.fold<double>(0, (a, i) => a + i.grams);

  /// How many servings the batch makes, to one decimal.
  double get servings => servingGrams <= 0 ? 0 : cookedGrams / servingGrams;
}

/// The user's own recipes (§19.10).
///
/// A recipe is a [FoodItems] row like any other, with its nutrients stored
/// as ordinary [FoodNutrientValues] — which is the whole design: it is
/// loggable, searchable, favouritable and template-able with no special
/// handling anywhere else in the app. The component list is kept in
/// [RecipeComponents] so the recipe can be reopened and edited.
///
/// Editing a recipe never touches a meal already logged from it. Entries
/// snapshot their nutrients at log time (§20.5, ADR-008), so yesterday's
/// dal keeps the numbers it was measured with — [saveRecipe] bumps
/// `revision` rather than rewriting history.
class RecipeDao {
  RecipeDao(this._db);

  final NourishlyDatabase _db;

  /// A nutrient reported by less than this share of a recipe's raw weight
  /// is dropped rather than stored.
  ///
  /// [ASSUMPTION] Not in the spec. The reasoning: a dish's iron computed
  /// from 97% of its mass (everything but the spices) is worth having and
  /// AP-4 is satisfied by saying so; one computed from 30% of its mass is
  /// not a low figure, it is a wrong one, and once stored it looks exactly
  /// like a real value to every screen downstream. Half is the point where
  /// "most of the dish" stops being true.
  static const double minComponentCoverage = 0.5;

  /// Creates or updates a recipe and returns its food id.
  ///
  /// Pass [foodId] to edit an existing one. [cookedGrams] is the weighed
  /// finished dish and is what §19.10 wants whenever the cook has a scale;
  /// without it [method]'s fallback factor applies.
  Future<String> saveRecipe({
    required String ownerId,
    required String name,
    required List<RecipeIngredient> ingredients,
    required double servingGrams,
    String servingLabel = '1 serving',
    double? cookedGrams,
    CookingMethod method = CookingMethod.none,
    String? foodId,
  }) async {
    if (ingredients.isEmpty) {
      throw ArgumentError.value(
        ingredients,
        'ingredients',
        'A recipe is its ingredients — there is nothing to compute without '
            'at least one.',
      );
    }
    if (servingGrams <= 0) {
      throw ArgumentError.value(
        servingGrams,
        'servingGrams',
        'A serving must weigh something — every serving resolves to grams.',
      );
    }

    final nutrition = await computeFor(
      ingredients: ingredients,
      cookedGrams: cookedGrams,
      method: method,
    );

    final id = foodId ?? _uuid.v7();
    final isNew = foodId == null;
    final servingId = isNew ? _uuid.v7() : await _servingIdFor(id);
    final dietClass = await _dietClassOf(ingredients);

    await _db.transaction(() async {
      if (isNew) {
        await _db
            .into(_db.foodItems)
            .insert(
              FoodItemsCompanion.insert(
                id: id,
                ownerId: Value(ownerId),
                kind: 'recipe',
                canonicalName: name,
                // A recipe is only as good as its ingredients, and it is
                // the user's own arithmetic on top of them (§19.11).
                qualityTier: 'user',
                provenanceSource: 'user',
                yieldFactor: Value(nutrition.yieldFactor),
                defaultServingId: Value(servingId),
                dietClass: Value(dietClass?.id),
              ),
            );
      } else {
        await (_db.update(_db.foodItems)..where((f) => f.id.equals(id))).write(
          FoodItemsCompanion(
            canonicalName: Value(name),
            yieldFactor: Value(nutrition.yieldFactor),
            dietClass: Value(dietClass?.id),
            // The bump is what makes an edit visible without rewriting
            // anything: entries record the revision they were logged
            // against (ADR-008).
            revision: Value(await _revisionOf(id) + 1),
          ),
        );
      }

      await _db
          .into(_db.servingSizes)
          .insertOnConflictUpdate(
            ServingSizesCompanion.insert(
              id: servingId,
              foodId: id,
              label: servingLabel,
              grams: servingGrams,
              isHouseholdMeasure: const Value(true),
              isDefault: const Value(true),
            ),
          );

      // Both lists are replaced rather than merged: an ingredient removed
      // from a recipe has to leave, and a nutrient that no longer clears
      // the coverage bar has to stop being reported.
      await (_db.delete(
        _db.recipeComponents,
      )..where((c) => c.recipeFoodItemId.equals(id))).go();
      await (_db.delete(
        _db.foodNutrientValues,
      )..where((v) => v.foodId.equals(id))).go();

      await _db.batch((batch) {
        for (var i = 0; i < ingredients.length; i++) {
          batch.insert(
            _db.recipeComponents,
            RecipeComponentsCompanion.insert(
              id: _uuid.v7(),
              recipeFoodItemId: id,
              ingredientFoodItemId: ingredients[i].foodId,
              quantityGrams: ingredients[i].grams,
              sortOrder: Value(i),
            ),
          );
        }
        for (final entry in nutrition.per100g.entries) {
          if (nutrition.coverageOf(entry.key) < minComponentCoverage) continue;
          batch.insert(
            _db.foodNutrientValues,
            FoodNutrientValuesCompanion.insert(
              id: _uuid.v7(),
              foodId: id,
              nutrientId: entry.key,
              amountPer100g: entry.value,
              // Computed from other rows, not measured on this dish.
              valueSource: 'calculated',
            ),
          );
        }
      });
    });

    final search = FoodSearchDao(_db);
    if (!isNew) await search.removeFromIndex(id);
    await search.indexFood(foodId: id, canonicalName: name, altNames: const []);

    return id;
  }

  /// The recipe's nutrition as the builder previews it, before saving.
  Future<RecipeNutrition> computeFor({
    required List<RecipeIngredient> ingredients,
    double? cookedGrams,
    CookingMethod method = CookingMethod.none,
  }) async {
    final foodIds = ingredients.map((i) => i.foodId).toSet().toList();
    final values = foodIds.isEmpty
        ? <FoodNutrientValue>[]
        : await (_db.select(
            _db.foodNutrientValues,
          )..where((v) => v.foodId.isIn(foodIds))).get();

    final byFood = <String, Map<String, double>>{};
    for (final value in values) {
      (byFood[value.foodId] ??= {})[value.nutrientId] = value.amountPer100g;
    }

    return computeRecipeNutrition(
      components: [
        for (final ingredient in ingredients)
          RecipeComponentInput(
            foodId: ingredient.foodId,
            grams: ingredient.grams,
            nutrientsPer100g: byFood[ingredient.foodId] ?? const {},
          ),
      ],
      cookedGrams: cookedGrams,
      method: method,
    );
  }

  /// Every recipe this profile has written, newest first.
  Future<List<SavedRecipe>> recipesFor(String ownerId) async {
    final foods =
        await (_db.select(_db.foodItems)
              ..where(
                (f) =>
                    f.ownerId.equals(ownerId) &
                    f.kind.equals('recipe') &
                    f.deletedAt.isNull(),
              )
              // UUIDv7 is time-ordered, so the id is the creation order
              // and FoodItems carries no created_at of its own.
              ..orderBy([(f) => OrderingTerm.desc(f.id)]))
            .get();

    return [for (final food in foods) ?await _hydrate(food)];
  }

  /// One recipe, or null if it is not a recipe or has been deleted.
  Future<SavedRecipe?> recipe(String foodId) async {
    final rows =
        await (_db.select(_db.foodItems)
              ..where((f) => f.id.equals(foodId) & f.deletedAt.isNull())
              ..limit(1))
            .get();
    if (rows.isEmpty || rows.first.kind != 'recipe') return null;
    return _hydrate(rows.first);
  }

  /// Soft-deletes the recipe and takes it out of search.
  ///
  /// A tombstone rather than a delete (ADR-008): meals logged from this
  /// recipe reference it, and their frozen snapshots have to keep
  /// resolving to a name.
  Future<void> deleteRecipe(String foodId) async {
    await (_db.update(_db.foodItems)..where((f) => f.id.equals(foodId))).write(
      FoodItemsCompanion(deletedAt: Value(DateTime.now())),
    );
    await FoodSearchDao(_db).removeFromIndex(foodId);
  }

  Future<SavedRecipe?> _hydrate(FoodItem food) async {
    final components =
        await (_db.select(_db.recipeComponents)
              ..where((c) => c.recipeFoodItemId.equals(food.id))
              ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
            .get();

    final ingredientIds = components
        .map((c) => c.ingredientFoodItemId)
        .toSet()
        .toList();
    final ingredientFoods = ingredientIds.isEmpty
        ? <FoodItem>[]
        : await (_db.select(
            _db.foodItems,
          )..where((f) => f.id.isIn(ingredientIds))).get();
    final names = {for (final f in ingredientFoods) f.id: f.canonicalName};

    final servings = await (_db.select(
      _db.servingSizes,
    )..where((s) => s.foodId.equals(food.id))).get();
    final serving = servings.isEmpty ? null : servings.first;

    final ingredients = [
      for (final component in components)
        RecipeIngredient(
          foodId: component.ingredientFoodItemId,
          name: names[component.ingredientFoodItemId] ?? 'Unknown ingredient',
          grams: component.quantityGrams,
        ),
    ];
    final rawGrams = ingredients.fold<double>(0, (a, i) => a + i.grams);
    final yieldFactor = food.yieldFactor ?? 1;

    return SavedRecipe(
      foodId: food.id,
      name: food.canonicalName,
      ingredients: ingredients,
      servingGrams: serving?.grams ?? 0,
      servingLabel: serving?.label ?? '1 serving',
      cookedGrams: rawGrams * yieldFactor,
      yieldFactor: yieldFactor,
      dietClass: DietClass.fromId(food.dietClass),
    );
  }

  /// The most restrictive class among the ingredients — a recipe with
  /// chicken in it is non-vegetarian however it is named (FR-U-16).
  ///
  /// An ingredient whose own class is unknown makes the recipe's unknown
  /// too: null is a real answer here, and "don't rank on this" is the only
  /// safe reading of it.
  Future<DietClass?> _dietClassOf(List<RecipeIngredient> ingredients) async {
    final ids = ingredients.map((i) => i.foodId).toSet().toList();
    if (ids.isEmpty) return null;
    final foods = await (_db.select(
      _db.foodItems,
    )..where((f) => f.id.isIn(ids))).get();

    DietClass? worst;
    for (final food in foods) {
      final own = DietClass.fromId(food.dietClass);
      if (own == null) return null;
      if (worst == null || own.restrictiveness > worst.restrictiveness) {
        worst = own;
      }
    }
    return worst;
  }

  Future<String> _servingIdFor(String foodId) async {
    final rows =
        await (_db.select(_db.servingSizes)
              ..where((s) => s.foodId.equals(foodId))
              ..limit(1))
            .get();
    return rows.isEmpty ? _uuid.v7() : rows.first.id;
  }

  Future<int> _revisionOf(String foodId) async {
    final rows = await (_db.select(
      _db.foodItems,
    )..where((f) => f.id.equals(foodId))).get();
    return rows.isEmpty ? 1 : rows.first.revision;
  }
}
