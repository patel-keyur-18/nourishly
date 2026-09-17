import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database.dart';
import 'food_logging_dao.dart';

const _uuid = Uuid();

/// One food a template will log, before it is saved.
class MealTemplateItemInput {
  const MealTemplateItemInput({
    required this.foodId,
    required this.servingSizeId,
    required this.quantity,
  });

  final String foodId;
  final String? servingSizeId;
  final double quantity;
}

/// One food inside a saved template, with the food name and serving label
/// already resolved for display.
class MealTemplateItemDetail {
  const MealTemplateItemDetail({
    required this.foodId,
    required this.foodName,
    required this.servingSizeId,
    required this.servingLabel,
    required this.quantity,
  });

  final String foodId;
  final String foodName;
  final String? servingSizeId;
  final String? servingLabel;
  final double quantity;
}

/// A saved meal template, read back for the templates screen.
class SavedMealTemplate {
  const SavedMealTemplate({
    required this.id,
    required this.name,
    required this.defaultMealSlotId,
    required this.items,
    required this.energyKcal,
    required this.useCount,
    required this.lastUsedAt,
  });

  final String id;
  final String name;
  final String? defaultMealSlotId;
  final List<MealTemplateItemDetail> items;

  /// The sum of `energy` across items whose serving grams and energy value
  /// are both known. Null when none of the items have enough to compute
  /// anything — a household choosing between two templates gets a real
  /// number or nothing, never a total quietly missing part of the meal.
  final double? energyKcal;
  final int useCount;
  final DateTime? lastUsedAt;
}

/// A saved set of foods a profile logs together often (screen 7, "cards
/// with contents" — decisions.md). Applying a template creates independent
/// [FoodLogEntries] rows with their own frozen nutrient snapshots; entries
/// never reference the template back, so editing or deleting one never
/// alters a meal already logged from it (matches [RecipeDao]'s ADR-008
/// stance, restated on the table's own doc comment in
/// `logging_tables.dart`).
class MealTemplateDao {
  MealTemplateDao(this._db);

  final NourishlyDatabase _db;

  /// Every template this profile has saved, newest first.
  Future<List<SavedMealTemplate>> templatesFor(String ownerId) async {
    final templates =
        await (_db.select(_db.mealTemplates)
              ..where((t) => t.ownerId.equals(ownerId) & t.deletedAt.isNull())
              ..orderBy([(t) => OrderingTerm.desc(t.id)]))
            .get();
    return [for (final template in templates) await _hydrate(template)];
  }

  Future<SavedMealTemplate> _hydrate(MealTemplate template) async {
    final items =
        await (_db.select(_db.mealTemplateItems)
              ..where((i) => i.templateId.equals(template.id))
              ..orderBy([(i) => OrderingTerm.asc(i.sortOrder)]))
            .get();

    final foodIds = items.map((i) => i.foodId).toSet().toList();
    final foods = foodIds.isEmpty
        ? <FoodItem>[]
        : await (_db.select(
            _db.foodItems,
          )..where((f) => f.id.isIn(foodIds))).get();
    final names = {for (final f in foods) f.id: f.canonicalName};

    final servingIds = items
        .map((i) => i.servingSizeId)
        .whereType<String>()
        .toSet()
        .toList();
    final servings = servingIds.isEmpty
        ? <ServingSize>[]
        : await (_db.select(
            _db.servingSizes,
          )..where((s) => s.id.isIn(servingIds))).get();
    final servingById = {for (final s in servings) s.id: s};

    final energyValues = foodIds.isEmpty
        ? <FoodNutrientValue>[]
        : await (_db.select(_db.foodNutrientValues)..where(
            (v) => v.foodId.isIn(foodIds) & v.nutrientId.equals('energy'),
          )).get();
    final energyPer100gByFood = {
      for (final v in energyValues) v.foodId: v.amountPer100g,
    };

    double? energyKcal;
    for (final item in items) {
      final grams = item.servingSizeId == null
          ? null
          : servingById[item.servingSizeId]?.grams;
      final energyPer100g = energyPer100gByFood[item.foodId];
      if (grams == null || energyPer100g == null) continue;
      energyKcal = (energyKcal ?? 0) + energyPer100g * grams * item.quantity / 100;
    }

    return SavedMealTemplate(
      id: template.id,
      name: template.name,
      defaultMealSlotId: template.defaultMealSlotId,
      energyKcal: energyKcal,
      useCount: template.useCount,
      lastUsedAt: template.lastUsedAt,
      items: [
        for (final item in items)
          MealTemplateItemDetail(
            foodId: item.foodId,
            foodName: names[item.foodId] ?? 'Unknown food',
            servingSizeId: item.servingSizeId,
            servingLabel: item.servingSizeId == null
                ? null
                : servingById[item.servingSizeId]?.label,
            quantity: item.quantity,
          ),
      ],
    );
  }

  /// Saves [items] as a new template named [name].
  Future<String> createFromEntries({
    required String ownerId,
    required String name,
    required String? defaultMealSlotId,
    required List<MealTemplateItemInput> items,
  }) async {
    if (items.isEmpty) {
      throw ArgumentError.value(
        items,
        'items',
        'A template is its foods — there is nothing to save without at '
            'least one.',
      );
    }

    final id = _uuid.v7();
    await _db.transaction(() async {
      await _db
          .into(_db.mealTemplates)
          .insert(
            MealTemplatesCompanion.insert(
              id: id,
              ownerId: ownerId,
              name: name,
              defaultMealSlotId: Value(defaultMealSlotId),
            ),
          );
      await _db.batch((batch) {
        for (var i = 0; i < items.length; i++) {
          batch.insert(
            _db.mealTemplateItems,
            MealTemplateItemsCompanion.insert(
              id: _uuid.v7(),
              templateId: id,
              foodId: items[i].foodId,
              servingSizeId: Value(items[i].servingSizeId),
              quantity: items[i].quantity,
              sortOrder: Value(i),
            ),
          );
        }
      });
    });
    return id;
  }

  /// Logs every item of [templateId] into [logDate], in [mealSlotId] (or
  /// the template's own default when none is given). Returns how many
  /// items were actually logged — an item whose food has no serving size
  /// recorded is skipped rather than guessed at (AP-4's spirit: no
  /// fabricated portion).
  Future<int> applyTemplate({
    required String templateId,
    required String ownerId,
    required DateTime logDate,
    String? mealSlotId,
  }) async {
    final template = await (_db.select(
      _db.mealTemplates,
    )..where((t) => t.id.equals(templateId))).getSingle();
    final items = await (_db.select(
      _db.mealTemplateItems,
    )..where((i) => i.templateId.equals(templateId))).get();

    final slot = mealSlotId ?? template.defaultMealSlotId;
    if (slot == null) {
      throw StateError(
        'This template has no meal slot — pick one to log it into.',
      );
    }

    final dao = FoodLoggingDao(_db);
    var logged = 0;
    for (final item in items) {
      final servingId =
          item.servingSizeId ?? await _defaultServingFor(item.foodId);
      if (servingId == null) continue;
      await dao.logFood(
        ownerId: ownerId,
        foodId: item.foodId,
        servingId: servingId,
        quantity: item.quantity,
        mealSlotId: slot,
        logDate: logDate,
      );
      logged++;
    }

    await (_db.update(
      _db.mealTemplates,
    )..where((t) => t.id.equals(templateId))).write(
      MealTemplatesCompanion(
        lastUsedAt: Value(DateTime.now()),
        useCount: Value(template.useCount + 1),
      ),
    );
    return logged;
  }

  Future<String?> _defaultServingFor(String foodId) async {
    final rows =
        await (_db.select(_db.servingSizes)
              ..where((s) => s.foodId.equals(foodId))
              ..limit(1))
            .get();
    return rows.isEmpty ? null : rows.first.id;
  }

  /// Soft-deletes the template. Meals already logged from it are untouched
  /// — they never referenced it in the first place.
  Future<void> deleteTemplate(String templateId) async {
    await (_db.update(
      _db.mealTemplates,
    )..where((t) => t.id.equals(templateId))).write(
      MealTemplatesCompanion(deletedAt: Value(DateTime.now())),
    );
  }
}
