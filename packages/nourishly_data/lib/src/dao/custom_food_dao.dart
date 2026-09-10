import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database.dart';
import 'food_search_dao.dart';

const _uuid = Uuid();

/// Creates the user's own foods (T4 in the catalog tiers, §22.5) — the
/// escape hatch that guarantees nothing is unloggable (UX-6).
///
/// A custom food is an ordinary [FoodItems] row with `ownerId` set, so
/// every consumer — search, logging, the nutrient snapshot — works on it
/// identically to a catalog food. It is `qualityTier: 'user'` and its
/// nutrient values are `valueSource: 'estimated'`, so an entered figure is
/// never mistaken for a measured one (§19.11).
class CustomFoodDao {
  CustomFoodDao(this._db);

  final NourishlyDatabase _db;

  /// Creates a custom food owned by [ownerId] with one serving, and
  /// indexes it for search. Returns the new food's id.
  ///
  /// [nutrientsPerServing] is keyed by nutrient id (`energy`, `protein`,
  /// …) in each nutrient's canonical unit. Only what the user actually
  /// entered should be passed: a nutrient absent from the map is stored as
  /// absent, never as zero (AP-4).
  Future<String> createCustomFood({
    required String ownerId,
    required String name,
    required String servingLabel,
    required double servingGrams,
    required Map<String, double> nutrientsPerServing,
  }) async {
    if (servingGrams <= 0) {
      throw ArgumentError.value(
        servingGrams,
        'servingGrams',
        'A serving must weigh something — every serving resolves to grams.',
      );
    }

    final foodId = _uuid.v7();
    final servingId = _uuid.v7();

    await _db.batch((batch) {
      batch.insert(
        _db.foodItems,
        FoodItemsCompanion.insert(
          id: foodId,
          ownerId: Value(ownerId),
          kind: 'user_custom',
          canonicalName: name,
          qualityTier: 'user',
          provenanceSource: 'user',
          defaultServingId: Value(servingId),
        ),
      );

      batch.insert(
        _db.servingSizes,
        ServingSizesCompanion.insert(
          id: servingId,
          foodId: foodId,
          label: servingLabel,
          grams: servingGrams,
          isHouseholdMeasure: const Value(true),
          isDefault: const Value(true),
        ),
      );

      batch.insertAll(_db.foodNutrientValues, [
        for (final entry in nutrientsPerServing.entries)
          FoodNutrientValuesCompanion.insert(
            id: _uuid.v7(),
            foodId: foodId,
            nutrientId: entry.key,
            // Stored per 100 g, like every other food, so logging maths
            // needs no special case for custom foods.
            amountPer100g: entry.value * 100 / servingGrams,
            valueSource: 'estimated',
          ),
      ]);
    });

    await FoodSearchDao(_db).indexFood(
      foodId: foodId,
      canonicalName: name,
      altNames: const [],
    );

    return foodId;
  }
}
