import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database.dart';

const _uuid = Uuid();

/// Writes a [FoodLogEntries] row plus its immutable [LogEntryNutrients]
/// snapshot in one transaction (I-1, §20.5) — the snapshot is frozen at
/// log time so a later catalog correction never rewrites history (ADR-008).
class FoodLoggingDao {
  FoodLoggingDao(this._db);

  final NourishlyDatabase _db;

  /// Logs [quantity] servings of [servingId] against [foodId], in
  /// [mealSlotId], on [logDate]. Returns the new entry's id.
  Future<String> logFood({
    required String ownerId,
    required String foodId,
    required String servingId,
    required double quantity,
    required String mealSlotId,
    required DateTime logDate,
  }) async {
    final food = await (_db.select(
      _db.foodItems,
    )..where((f) => f.id.equals(foodId))).getSingle();
    final serving = await (_db.select(
      _db.servingSizes,
    )..where((s) => s.id.equals(servingId))).getSingle();
    final nutrientValues = await (_db.select(
      _db.foodNutrientValues,
    )..where((v) => v.foodId.equals(foodId))).get();

    final gramsConsumed = serving.grams * quantity;
    final entryId = _uuid.v7();
    final now = DateTime.now();

    await _db.batch((batch) {
      batch.insert(
        _db.foodLogEntries,
        FoodLogEntriesCompanion.insert(
          id: entryId,
          ownerId: ownerId,
          logDate: logDate,
          mealSlotId: mealSlotId,
          foodId: foodId,
          foodRevision: food.revision,
          servingSizeId: Value(servingId),
          quantity: quantity,
          gramsConsumed: gramsConsumed,
          loggedAt: now,
          source: 'manual',
        ),
      );

      batch.insertAll(_db.logEntryNutrients, [
        for (final v in nutrientValues)
          LogEntryNutrientsCompanion.insert(
            entryId: entryId,
            nutrientId: v.nutrientId,
            amount: v.amountPer100g * gramsConsumed / 100,
          ),
      ]);
    });

    return entryId;
  }

  /// Today's logged entries for [ownerId], newest first, joined to the
  /// food and meal slot names — what the minimal Today screen (§27.2,
  /// pending the real dashboard in Phase 3) shows to confirm a log
  /// actually saved.
  Stream<List<LoggedFood>> watchToday({
    required String ownerId,
    required DateTime logDate,
  }) {
    final query =
        _db.select(_db.foodLogEntries).join([
            innerJoin(
              _db.foodItems,
              _db.foodItems.id.equalsExp(_db.foodLogEntries.foodId),
            ),
            innerJoin(
              _db.mealSlots,
              _db.mealSlots.id.equalsExp(_db.foodLogEntries.mealSlotId),
            ),
          ])
          ..where(
            _db.foodLogEntries.ownerId.equals(ownerId) &
                _db.foodLogEntries.logDate.equals(logDate) &
                _db.foodLogEntries.deletedAt.isNull(),
          )
          ..orderBy([OrderingTerm.desc(_db.foodLogEntries.loggedAt)]);

    return query.watch().map(
      (rows) => [
        for (final row in rows)
          LoggedFood(
            entry: row.readTable(_db.foodLogEntries),
            foodName: row.readTable(_db.foodItems).canonicalName,
            mealSlotName: row.readTable(_db.mealSlots).displayName,
          ),
      ],
    );
  }
}

/// A [FoodLogEntry] with the food and meal slot names already joined in —
/// what a list screen needs, without an N+1 lookup per row.
class LoggedFood {
  const LoggedFood({
    required this.entry,
    required this.foodName,
    required this.mealSlotName,
  });

  final FoodLogEntry entry;
  final String foodName;
  final String mealSlotName;
}
