import 'package:drift/drift.dart';

import 'database.dart';

/// What a food is compatible with (FR-U-16).
///
/// Ordered from most restrictive to least: a food that is [vegan] suits
/// every preference, one that is [nonVegetarian] suits only a diet with no
/// restriction. That ordering is what makes ranking a comparison rather
/// than a table of special cases.
enum DietClass {
  vegan('vegan', 0),
  vegetarian('vegetarian', 1),
  eggetarian('eggetarian', 2),
  nonVegetarian('non_vegetarian', 3);

  const DietClass(this.id, this.restrictiveness);

  final String id;
  final int restrictiveness;

  static DietClass? fromId(String? id) =>
      id == null ? null : values.where((c) => c.id == id).firstOrNull;
}

/// A stated dietary preference, and what it will eat (FR-U-16).
enum DietaryPreference {
  vegan('vegan', 'Vegan', DietClass.vegan),
  jain('jain', 'Jain', DietClass.vegetarian),
  vegetarian('vegetarian', 'Vegetarian', DietClass.vegetarian),
  eggetarian('eggetarian', 'Eggetarian', DietClass.eggetarian),
  halal('halal', 'Halal', DietClass.nonVegetarian),
  none('none', 'No preference', DietClass.nonVegetarian);

  const DietaryPreference(this.id, this.label, this.accepts);

  final String id;
  final String label;

  /// The most permissive class this preference eats.
  ///
  /// Jain practice also excludes root vegetables, which this catalog does
  /// not record — so Jain ranks as vegetarian and the difference is left
  /// visible rather than half-implemented. Halal is about slaughter
  /// method, which is likewise not in the data, so it does not reorder
  /// anything on its own.
  final DietClass accepts;

  static DietaryPreference? fromId(String? id) =>
      id == null ? null : values.where((p) => p.id == id).firstOrNull;
}

/// The root foods everything else is classified from.
///
/// Deliberately a short, readable list of catalog row names rather than a
/// keyword match: "Kori gassi" and "Meen kuzhambu" contain no word that
/// says chicken or fish, and a substring rule that tried would also catch
/// "Butter" in "Buttermilk". Everything else is derived by walking
/// `recipe_components`.
const _nonVegetarianRoots = {
  'Chicken, curry cut, raw',
  'Mutton, raw',
  'Fish, pomfret',
  'Fish, sardine',
  'Fish, seer / kingfish',
  'Prawns',
};

const _eggRoots = {'Egg, boiled'};

const _dairyRoots = {
  'Milk, buffalo, whole',
  'Milk, cow, whole',
  'Milk, toned',
  'Milk, double-toned / skimmed',
  'Curd, plain',
  'Curd, low-fat',
  'Hung curd',
  'Paneer',
  'Ghee',
  'Butter',
  'Malai / fresh cream',
  'Khoya / Mawa',
  'Cheese, processed',
  'Honey',
};

/// Computes and stores [FoodItems.dietClass] for every food.
///
/// Runs after a catalog import: the classification depends only on rows
/// already in the database, so it needs no pipeline change and no
/// regenerated seed.
///
/// A food whose components cannot be resolved stays null. Null is treated
/// everywhere as "unknown", never as "safe" — telling a vegetarian that an
/// unclassified dish is fine is the one mistake this feature must not
/// make.
class DietClassifier {
  DietClassifier(this._db);

  final NourishlyDatabase _db;

  /// Classifies every food that has no class yet.
  ///
  /// Cheap to call on every launch, and it has to be: a device upgrading
  /// from schema v1 has the column but no values, and its catalog import
  /// short-circuits on the version it already has, so there is no import
  /// to hang this off.
  Future<void> classifyMissing() async {
    final unclassified =
        await (_db.select(_db.foodItems)
              ..where((f) => f.dietClass.isNull())
              ..limit(1))
            .get();
    if (unclassified.isEmpty) return;
    await classifyAll();
  }

  Future<void> classifyAll() async {
    final foods = await _db.select(_db.foodItems).get();
    if (foods.isEmpty) return;

    final components = await _db.select(_db.recipeComponents).get();
    final childrenOf = <String, List<String>>{};
    for (final component in components) {
      (childrenOf[component.recipeFoodItemId] ??= []).add(
        component.ingredientFoodItemId,
      );
    }

    final nameById = {for (final f in foods) f.id: f.canonicalName};
    final resolved = <String, DietClass?>{};

    DietClass? classify(String id, Set<String> visiting) {
      if (resolved.containsKey(id)) return resolved[id];
      // A cycle is a curation bug, not a diet question; bail rather than
      // loop, and leave the food unknown.
      if (!visiting.add(id)) return null;

      final name = nameById[id];
      DietClass? own;
      if (name != null) {
        if (_nonVegetarianRoots.contains(name)) {
          own = DietClass.nonVegetarian;
        } else if (_eggRoots.contains(name)) {
          own = DietClass.eggetarian;
        } else if (_dairyRoots.contains(name)) {
          own = DietClass.vegetarian;
        }
      }

      final children = childrenOf[id];
      if (children == null || children.isEmpty) {
        // A leaf with no rule is a plant ingredient as far as this catalog
        // goes — every animal-derived leaf is named in the sets above.
        final result = own ?? DietClass.vegan;
        visiting.remove(id);
        return resolved[id] = result;
      }

      var worst = own ?? DietClass.vegan;
      for (final child in children) {
        final childClass = classify(child, visiting);
        if (childClass == null) {
          visiting.remove(id);
          return resolved[id] = null;
        }
        if (childClass.restrictiveness > worst.restrictiveness) {
          worst = childClass;
        }
      }
      visiting.remove(id);
      return resolved[id] = worst;
    }

    for (final food in foods) {
      classify(food.id, <String>{});
    }

    await _db.batch((batch) {
      for (final food in foods) {
        final dietClass = resolved[food.id];
        if (dietClass?.id == food.dietClass) continue;
        batch.update(
          _db.foodItems,
          FoodItemsCompanion(dietClass: Value(dietClass?.id)),
          where: (f) => f.id.equals(food.id),
        );
      }
    });
  }
}

/// Whether [preference] would eat a food of [dietClass].
///
/// Unknown ([dietClass] null) is not "yes": it sorts below a known match
/// but is never hidden, because §27.4 forbids a dead end and a household
/// may well log a food for a guest.
bool suitsPreference(DietaryPreference preference, DietClass? dietClass) {
  if (dietClass == null) return false;
  return dietClass.restrictiveness <= preference.accepts.restrictiveness;
}
