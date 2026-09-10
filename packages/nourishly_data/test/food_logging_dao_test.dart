import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly_data/nourishly_data.dart';

void main() {
  late NourishlyDatabase db;
  late FoodLoggingDao dao;
  late String ownerId;
  late String mealSlotId;

  setUp(() async {
    db = NourishlyDatabase.forTesting();
    final seed = jsonDecode(
      File('../../app/assets/catalog/seed_v1.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    await CatalogImporter(db).importIfNeeded(seed);
    ownerId = await ensureDefaultOwner(db);
    mealSlotId = (await db.select(db.mealSlots).get()).first.id;
    dao = FoodLoggingDao(db);
  });
  tearDown(() => db.close());

  Future<(String foodId, String servingId)> rice() async {
    final food = await (db.select(
      db.foodItems,
    )..where((f) => f.canonicalName.equals('Rice, white, cooked'))).getSingle();
    final serving = await (db.select(
      db.servingSizes,
    )..where((s) => s.foodId.equals(food.id))).getSingle();
    return (food.id, serving.id);
  }

  test('logs an entry and snapshots its nutrients at 1x the serving', () async {
    final (foodId, servingId) = await rice();
    final logDate = DateTime(2026, 1, 1);

    final entryId = await dao.logFood(
      ownerId: ownerId,
      foodId: foodId,
      servingId: servingId,
      quantity: 1,
      mealSlotId: mealSlotId,
      logDate: logDate,
    );

    final entry = await (db.select(
      db.foodLogEntries,
    )..where((e) => e.id.equals(entryId))).getSingle();
    final serving = await (db.select(
      db.servingSizes,
    )..where((s) => s.id.equals(servingId))).getSingle();
    expect(entry.gramsConsumed, serving.grams);

    final snapshot = await (db.select(
      db.logEntryNutrients,
    )..where((n) => n.entryId.equals(entryId))).get();
    final rawValues = await (db.select(
      db.foodNutrientValues,
    )..where((v) => v.foodId.equals(foodId))).get();
    expect(snapshot, hasLength(rawValues.length));

    final energy = snapshot.firstWhere((n) => n.nutrientId == 'energy');
    final rawEnergy = rawValues.firstWhere((v) => v.nutrientId == 'energy');
    expect(
      energy.amount,
      closeTo(rawEnergy.amountPer100g * serving.grams / 100, 0.001),
    );
  });

  test('quantity scales the snapshot linearly', () async {
    final (foodId, servingId) = await rice();

    final entryId = await dao.logFood(
      ownerId: ownerId,
      foodId: foodId,
      servingId: servingId,
      quantity: 2,
      mealSlotId: mealSlotId,
      logDate: DateTime(2026, 1, 1),
    );

    final entry = await (db.select(
      db.foodLogEntries,
    )..where((e) => e.id.equals(entryId))).getSingle();
    final serving = await (db.select(
      db.servingSizes,
    )..where((s) => s.id.equals(servingId))).getSingle();
    expect(entry.gramsConsumed, serving.grams * 2);
  });

  test(
    'watchToday emits the entry for the log date and nothing for another day',
    () async {
      final (foodId, servingId) = await rice();
      await dao.logFood(
        ownerId: ownerId,
        foodId: foodId,
        servingId: servingId,
        quantity: 1,
        mealSlotId: mealSlotId,
        logDate: DateTime(2026, 1, 1),
      );

      final today = await dao
          .watchToday(ownerId: ownerId, logDate: DateTime(2026, 1, 1))
          .first;
      final otherDay = await dao
          .watchToday(ownerId: ownerId, logDate: DateTime(2026, 1, 2))
          .first;

      expect(today, hasLength(1));
      expect(today.single.foodName, 'Rice, white, cooked');
      expect(otherDay, isEmpty);
    },
  );
}
