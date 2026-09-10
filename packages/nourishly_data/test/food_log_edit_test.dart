import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly_data/nourishly_data.dart';

void main() {
  late NourishlyDatabase db;
  late FoodLoggingDao dao;
  late String ownerId;
  late String mealSlotId;
  late DateTime logDate;

  setUp(() async {
    db = NourishlyDatabase.forTesting();
    final seed = jsonDecode(
      File('../../app/assets/catalog/seed_v1.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    await CatalogImporter(db).importIfNeeded(seed);
    ownerId = await ensureDefaultOwner(db);
    mealSlotId = (await db.select(db.mealSlots).get()).first.id;
    dao = FoodLoggingDao(db);
    logDate = DateTime(2026, 1, 1);
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

  Future<String> logRice({double quantity = 1}) async {
    final (foodId, servingId) = await rice();
    return dao.logFood(
      ownerId: ownerId,
      foodId: foodId,
      servingId: servingId,
      quantity: quantity,
      mealSlotId: mealSlotId,
      logDate: logDate,
    );
  }

  Future<List<LogEntryNutrient>> snapshotOf(String entryId) {
    return (db.select(
      db.logEntryNutrients,
    )..where((n) => n.entryId.equals(entryId))).get();
  }

  group('deleteEntry (FR-M-05)', () {
    test('a deleted entry disappears from the day', () async {
      final entryId = await logRice();
      expect(
        await dao.watchToday(ownerId: ownerId, logDate: logDate).first,
        hasLength(1),
      );

      await dao.deleteEntry(entryId);

      expect(
        await dao.watchToday(ownerId: ownerId, logDate: logDate).first,
        isEmpty,
      );
    });

    test('the delete is soft, so undo restores it intact (UX-7)', () async {
      final entryId = await logRice();
      final before = await snapshotOf(entryId);

      await dao.deleteEntry(entryId);
      await dao.restore(entryId);

      final today = await dao
          .watchToday(ownerId: ownerId, logDate: logDate)
          .first;
      expect(today, hasLength(1));
      expect(today.single.entry.id, entryId);
      expect(await snapshotOf(entryId), hasLength(before.length));
    });
  });

  group('updateEntry (FR-M-05)', () {
    test('changing quantity rescales grams and the nutrient snapshot', () async {
      final entryId = await logRice();
      final original = await snapshotOf(entryId);
      final originalEntry = await (db.select(
        db.foodLogEntries,
      )..where((e) => e.id.equals(entryId))).getSingle();

      await dao.updateEntry(entryId: entryId, quantity: 2);

      final updated = await (db.select(
        db.foodLogEntries,
      )..where((e) => e.id.equals(entryId))).getSingle();
      expect(updated.quantity, 2);
      expect(updated.gramsConsumed, originalEntry.gramsConsumed * 2);

      final rescaled = await snapshotOf(entryId);
      expect(rescaled, hasLength(original.length));
      for (final before in original) {
        final after = rescaled.firstWhere(
          (n) => n.nutrientId == before.nutrientId,
        );
        expect(after.amount, closeTo(before.amount * 2, 0.0001));
      }
    });

    test('halving the quantity halves the snapshot too', () async {
      final entryId = await logRice(quantity: 2);
      final original = await snapshotOf(entryId);

      await dao.updateEntry(entryId: entryId, quantity: 1);

      final rescaled = await snapshotOf(entryId);
      for (final before in original) {
        final after = rescaled.firstWhere(
          (n) => n.nutrientId == before.nutrientId,
        );
        expect(after.amount, closeTo(before.amount / 2, 0.0001));
      }
    });

    test('the meal slot can be moved without touching the portion', () async {
      final entryId = await logRice();
      final before = await snapshotOf(entryId);
      final otherSlot = (await db.select(
        db.mealSlots,
      ).get()).firstWhere((s) => s.id != mealSlotId);

      await dao.updateEntry(entryId: entryId, mealSlotId: otherSlot.id);

      final today = await dao
          .watchToday(ownerId: ownerId, logDate: logDate)
          .first;
      expect(today.single.mealSlotName, otherSlot.displayName);
      final after = await snapshotOf(entryId);
      for (final b in before) {
        expect(
          after.firstWhere((n) => n.nutrientId == b.nutrientId).amount,
          closeTo(b.amount, 0.0001),
        );
      }
    });

    test(
      'an edit rescales the frozen snapshot rather than re-reading the '
      'catalog, so a later catalog correction cannot leak into history '
      '(ADR-008)',
      () async {
        final entryId = await logRice();
        final (foodId, _) = await rice();
        final energyBefore = (await snapshotOf(
          entryId,
        )).firstWhere((n) => n.nutrientId == 'energy').amount;

        // The catalog is corrected after the fact — doubling the food's
        // energy density.
        await (db.update(db.foodNutrientValues)..where(
              (v) => v.foodId.equals(foodId) & v.nutrientId.equals('energy'),
            ))
            .write(const FoodNutrientValuesCompanion(amountPer100g: Value(999)));

        await dao.updateEntry(entryId: entryId, quantity: 2);

        final energyAfter = (await snapshotOf(
          entryId,
        )).firstWhere((n) => n.nutrientId == 'energy').amount;
        expect(energyAfter, closeTo(energyBefore * 2, 0.0001));
      },
    );
  });
}
