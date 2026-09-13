import 'package:drift/drift.dart';

import '../database.dart';

/// What one household recipe saves against the catalog recipe it was
/// forked from, per 100 g of finished dish.
class ForkSaving {
  const ForkSaving({
    required this.foodId,
    required this.name,
    required this.parentName,
    required this.energyPer100g,
    required this.fatPer100g,
    required this.servingGrams,
  });

  final String foodId;
  final String name;
  final String parentName;

  /// Positive means the household version has less. Negative is a real
  /// answer too — a fork is whatever the cook changed, and sometimes that
  /// is more ghee.
  final double energyPer100g;
  final double fatPer100g;

  /// The fork's own serving, so a saving can be stated per katori rather
  /// than per 100 g, which is not how anyone eats.
  final double servingGrams;

  double get energyPerServing => energyPer100g * servingGrams / 100;
  double get fatPerServing => fatPer100g * servingGrams / 100;

  bool get isLighter => energyPer100g > 0 || fatPer100g > 0;
}

/// The same, totalled over meals actually logged in a period.
class PeriodSavings {
  const PeriodSavings({
    required this.energy,
    required this.fat,
    required this.entryCount,
    required this.dishCount,
  });

  static const none = PeriodSavings(
    energy: 0,
    fat: 0,
    entryCount: 0,
    dishCount: 0,
  );

  /// kcal not eaten across the period.
  final double energy;

  /// Grams of fat not eaten.
  final double fat;

  /// How many logged meals this is drawn from, and how many distinct
  /// dishes. Both are reported so a card can say what the number rests
  /// on instead of asserting it bare.
  final int entryCount;
  final int dishCount;

  bool get isEmpty => entryCount == 0;
}

/// Comparing a household's own version of a dish with the catalog recipe
/// it came from.
///
/// This is the reason the forking feature is worth having rather than
/// merely tolerated. A katori of sabzi cooked with 4 g of oil instead of
/// 8 is about 36 kcal lighter; eaten three or four times a week that is a
/// real number, and it is one no public nutrition app can tell this
/// household, because it does not know how they cook.
///
/// Every figure here is a **difference between two recipes that were each
/// summed from their own ingredients** (§0.2). Nothing is modelled,
/// estimated or assumed: if the catalog row says 8 g of groundnut oil and
/// hers says 4, the difference is what 4 g of groundnut oil contains.
class ForkSavingsDao {
  ForkSavingsDao(this._db);

  final NourishlyDatabase _db;

  /// Per-100g differences for one forked recipe, or null when the food is
  /// not a fork, its parent is gone, or either side is missing the
  /// nutrients to compare.
  ///
  /// Null rather than zero, deliberately: "no saving" and "we cannot tell"
  /// are different claims, and AP-4 forbids showing the second as the
  /// first.
  Future<ForkSaving?> savingFor(String foodId) async {
    final food =
        await (_db.select(_db.foodItems)
              ..where((f) => f.id.equals(foodId) & f.deletedAt.isNull()))
            .getSingleOrNull();
    final parentId = food?.forkedFromFoodId;
    if (food == null || parentId == null) return null;

    final parent = await (_db.select(
      _db.foodItems,
    )..where((f) => f.id.equals(parentId))).getSingleOrNull();
    if (parent == null) return null;

    final mine = await _per100g(food.id);
    final theirs = await _per100g(parent.id);
    final energy = _difference(theirs['energy'], mine['energy']);
    final fat = _difference(theirs['fat'], mine['fat']);
    if (energy == null && fat == null) return null;

    final serving = await (_db.select(
      _db.servingSizes,
    )..where((s) => s.foodId.equals(food.id))).getSingleOrNull();

    return ForkSaving(
      foodId: food.id,
      name: food.canonicalName,
      parentName: parent.canonicalName,
      energyPer100g: energy ?? 0,
      fatPer100g: fat ?? 0,
      servingGrams: serving?.grams ?? 0,
    );
  }

  /// Every fork this profile owns that is lighter than its parent,
  /// biggest saving per serving first.
  Future<List<ForkSaving>> savingsForOwner(String ownerId) async {
    final forks =
        await (_db.select(_db.foodItems)..where(
              (f) =>
                  f.ownerId.equals(ownerId) &
                  f.forkedFromFoodId.isNotNull() &
                  f.deletedAt.isNull(),
            ))
            .get();

    final savings = <ForkSaving>[];
    for (final fork in forks) {
      final saving = await savingFor(fork.id);
      if (saving != null && saving.isLighter) savings.add(saving);
    }
    savings.sort((a, b) => b.energyPerServing.compareTo(a.energyPerServing));
    return savings;
  }

  /// What the household's own versions saved over a period of real meals.
  ///
  /// Counted from `gramsConsumed` on each entry, so a bigger helping saves
  /// proportionally more — which is the truth of it.
  ///
  /// Only entries logged against a fork count, and only where the fork is
  /// actually lighter. A fork that came out heavier is left out rather
  /// than netted off: this answers "what did cooking lighter save", and
  /// quietly subtracting the ghee somebody added would answer a different
  /// question while looking like this one.
  Future<PeriodSavings> savingsOver(
    String ownerId, {
    required DateTime from,
    required DateTime to,
  }) async {
    final rows = await _db
        .customSelect(
          '''
          SELECT e.food_id AS food_id, SUM(e.grams_consumed) AS grams,
                 COUNT(*) AS n
          FROM food_log_entries e
          JOIN food_items f ON f.id = e.food_id
          WHERE e.owner_id = ?
            AND e.deleted_at IS NULL
            AND e.log_date >= ?
            AND e.log_date <= ?
            AND f.forked_from_food_id IS NOT NULL
          GROUP BY e.food_id
          ''',
          variables: [
            Variable.withString(ownerId),
            Variable.withDateTime(from),
            Variable.withDateTime(to),
          ],
          readsFrom: {_db.foodLogEntries, _db.foodItems},
        )
        .get();
    if (rows.isEmpty) return PeriodSavings.none;

    var energy = 0.0;
    var fat = 0.0;
    var entries = 0;
    var dishes = 0;
    for (final row in rows) {
      final saving = await savingFor(row.read<String>('food_id'));
      if (saving == null || !saving.isLighter) continue;
      final grams = row.read<double>('grams');
      energy += saving.energyPer100g * grams / 100;
      fat += saving.fatPer100g * grams / 100;
      entries += row.read<int>('n');
      dishes++;
    }
    return PeriodSavings(
      energy: energy,
      fat: fat,
      entryCount: entries,
      dishCount: dishes,
    );
  }

  Future<Map<String, double>> _per100g(String foodId) async {
    final values =
        await (_db.select(_db.foodNutrientValues)..where(
              (v) =>
                  v.foodId.equals(foodId) &
                  v.nutrientId.isIn(const ['energy', 'fat']),
            ))
            .get();
    return {for (final value in values) value.nutrientId: value.amountPer100g};
  }

  /// Null when either side does not report the nutrient.
  ///
  /// A recipe drops a nutrient it could only compute from a minority of
  /// its mass ([RecipeDao.minComponentCoverage]), so a missing value here
  /// means "not known for this dish" — never zero (AP-4).
  static double? _difference(double? parent, double? mine) {
    if (parent == null || mine == null) return null;
    return parent - mine;
  }
}
