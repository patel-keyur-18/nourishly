import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly_data/nourishly_data.dart';

void main() {
  late NourishlyDatabase db;
  late String ownerId;

  setUp(() async {
    db = NourishlyDatabase.forTesting();
    ownerId = await ensureDefaultOwner(db);
    await db
        .into(db.foodItems)
        .insert(
          FoodItemsCompanion.insert(
            id: 'food-dal',
            kind: 'ingredient',
            canonicalName: 'Dal',
            qualityTier: 'verified',
            provenanceSource: 'usda',
          ),
        );
    await db
        .into(db.servingSizes)
        .insert(
          ServingSizesCompanion.insert(
            id: 'serving-dal-katori',
            foodId: 'food-dal',
            label: '1 katori',
            grams: 150,
          ),
        );
    await db
        .into(db.mealSlots)
        .insert(
          MealSlotsCompanion.insert(
            id: 'slot-lunch',
            key: 'lunch',
            displayName: 'Lunch',
            sortOrder: 1,
          ),
        );
    await db
        .into(db.foodNutrientValues)
        .insert(
          FoodNutrientValuesCompanion.insert(
            id: 'fnv-dal-energy',
            foodId: 'food-dal',
            nutrientId: 'energy',
            amountPer100g: 150,
            valueSource: 'measured',
          ),
        );
  });

  tearDown(() => db.close());

  test(
    'creates a template and reads it back with resolved food names',
    () async {
      final dao = MealTemplateDao(db);
      final id = await dao.createFromEntries(
        ownerId: ownerId,
        name: 'Usual lunch',
        defaultMealSlotId: 'slot-lunch',
        items: const [
          MealTemplateItemInput(
            foodId: 'food-dal',
            servingSizeId: 'serving-dal-katori',
            quantity: 2,
          ),
        ],
      );

      final templates = await dao.templatesFor(ownerId);
      expect(templates, hasLength(1));
      expect(templates.single.id, id);
      expect(templates.single.name, 'Usual lunch');
      expect(templates.single.defaultMealSlotId, 'slot-lunch');
      expect(templates.single.items.single.foodName, 'Dal');
      expect(templates.single.items.single.quantity, 2);
      // 2 x 150 g at 150 kcal/100g = 450 kcal.
      expect(templates.single.energyKcal, 450);
      expect(templates.single.useCount, 0);
      expect(templates.single.lastUsedAt, isNull);
    },
  );

  test('an item missing a serving contributes no energy, but does not '
      'zero the rest — the total simply omits it', () async {
    await db
        .into(db.foodItems)
        .insert(
          FoodItemsCompanion.insert(
            id: 'food-mystery',
            kind: 'ingredient',
            canonicalName: 'Mystery side',
            qualityTier: 'user',
            provenanceSource: 'user',
          ),
        );
    final dao = MealTemplateDao(db);
    await dao.createFromEntries(
      ownerId: ownerId,
      name: 'Lunch plus a guess',
      defaultMealSlotId: 'slot-lunch',
      items: const [
        MealTemplateItemInput(
          foodId: 'food-dal',
          servingSizeId: 'serving-dal-katori',
          quantity: 1,
        ),
        MealTemplateItemInput(
          foodId: 'food-mystery',
          servingSizeId: null,
          quantity: 1,
        ),
      ],
    );

    final templates = await dao.templatesFor(ownerId);
    // 1 x 150 g at 150 kcal/100g = 225 kcal from the dal alone.
    expect(templates.single.energyKcal, 225);
  });

  test(
    'a template with no computable energy anywhere reports null, not 0',
    () async {
      await db
          .into(db.foodItems)
          .insert(
            FoodItemsCompanion.insert(
              id: 'food-mystery',
              kind: 'ingredient',
              canonicalName: 'Mystery side',
              qualityTier: 'user',
              provenanceSource: 'user',
            ),
          );
      final dao = MealTemplateDao(db);
      await dao.createFromEntries(
        ownerId: ownerId,
        name: 'All unknown',
        defaultMealSlotId: 'slot-lunch',
        items: const [
          MealTemplateItemInput(
            foodId: 'food-mystery',
            servingSizeId: null,
            quantity: 1,
          ),
        ],
      );

      final templates = await dao.templatesFor(ownerId);
      expect(templates.single.energyKcal, isNull);
    },
  );

  test('rejects a template with no items', () async {
    final dao = MealTemplateDao(db);
    expect(
      () => dao.createFromEntries(
        ownerId: ownerId,
        name: 'Empty',
        defaultMealSlotId: null,
        items: const [],
      ),
      throwsArgumentError,
    );
  });

  test(
    'applying a template logs one entry per item and bumps useCount',
    () async {
      final dao = MealTemplateDao(db);
      final id = await dao.createFromEntries(
        ownerId: ownerId,
        name: 'Usual lunch',
        defaultMealSlotId: 'slot-lunch',
        items: const [
          MealTemplateItemInput(
            foodId: 'food-dal',
            servingSizeId: 'serving-dal-katori',
            quantity: 2,
          ),
        ],
      );

      final logged = await dao.applyTemplate(
        templateId: id,
        ownerId: ownerId,
        logDate: DateTime(2026, 9, 17),
      );
      expect(logged, 1);

      final entries = await db.select(db.foodLogEntries).get();
      expect(entries, hasLength(1));
      expect(entries.single.foodId, 'food-dal');
      expect(entries.single.mealSlotId, 'slot-lunch');
      expect(entries.single.quantity, 2);
      expect(entries.single.gramsConsumed, 300);
      expect(entries.single.source, 'manual');

      final updated = await (db.select(
        db.mealTemplates,
      )..where((t) => t.id.equals(id))).getSingle();
      expect(updated.useCount, 1);
      expect(updated.lastUsedAt, isNotNull);
    },
  );

  test('applying with an explicit meal slot overrides the default', () async {
    final dao = MealTemplateDao(db);
    await db
        .into(db.mealSlots)
        .insert(
          MealSlotsCompanion.insert(
            id: 'slot-breakfast',
            key: 'breakfast',
            displayName: 'Breakfast',
            sortOrder: 0,
          ),
        );
    final id = await dao.createFromEntries(
      ownerId: ownerId,
      name: 'Usual lunch',
      defaultMealSlotId: 'slot-lunch',
      items: const [
        MealTemplateItemInput(
          foodId: 'food-dal',
          servingSizeId: 'serving-dal-katori',
          quantity: 1,
        ),
      ],
    );

    await dao.applyTemplate(
      templateId: id,
      ownerId: ownerId,
      logDate: DateTime(2026, 9, 17),
      mealSlotId: 'slot-breakfast',
    );

    final entry = await db.select(db.foodLogEntries).getSingle();
    expect(entry.mealSlotId, 'slot-breakfast');
  });

  test('deleteTemplate soft-deletes; it drops out of templatesFor', () async {
    final dao = MealTemplateDao(db);
    final id = await dao.createFromEntries(
      ownerId: ownerId,
      name: 'Usual lunch',
      defaultMealSlotId: 'slot-lunch',
      items: const [
        MealTemplateItemInput(
          foodId: 'food-dal',
          servingSizeId: 'serving-dal-katori',
          quantity: 1,
        ),
      ],
    );
    await dao.deleteTemplate(id);
    expect(await dao.templatesFor(ownerId), isEmpty);
  });
}
