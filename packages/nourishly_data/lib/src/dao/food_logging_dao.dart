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

  /// Soft-deletes one entry — the inline-undo path (UX-7, FR-M-05). The
  /// row and its nutrient snapshot stay put so [restore] can bring the
  /// entry back without recomputing anything.
  Future<void> deleteEntry(String entryId) {
    return (_db.update(
      _db.foodLogEntries,
    )..where((e) => e.id.equals(entryId))).write(
      FoodLogEntriesCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Undoes [deleteEntry].
  Future<void> restore(String entryId) {
    return (_db.update(_db.foodLogEntries)..where((e) => e.id.equals(entryId)))
        .write(const FoodLogEntriesCompanion(deletedAt: Value(null)));
  }

  /// Edits an entry's portion and/or meal slot (FR-M-05).
  ///
  /// The nutrient snapshot is replaced wholesale, as [LogEntryNutrients]
  /// requires — but by rescaling the *frozen* amounts to the new gram
  /// weight, not by re-reading the catalog. A correction to the portion
  /// you ate must not quietly pull in catalog edits made since you logged
  /// it; that is what ADR-008's immutable history protects.
  Future<void> updateEntry({
    required String entryId,
    double? quantity,
    String? servingId,
    String? mealSlotId,
  }) async {
    final entry = await (_db.select(
      _db.foodLogEntries,
    )..where((e) => e.id.equals(entryId))).getSingle();

    final newServingId = servingId ?? entry.servingSizeId;
    final newQuantity = quantity ?? entry.quantity;

    var newGrams = entry.gramsConsumed;
    if (newServingId != null) {
      final serving = await (_db.select(
        _db.servingSizes,
      )..where((s) => s.id.equals(newServingId))).getSingle();
      newGrams = serving.grams * newQuantity;
    } else if (entry.quantity != 0) {
      // No serving to measure against (a grams-only entry): scale by the
      // change in quantity alone.
      newGrams = entry.gramsConsumed / entry.quantity * newQuantity;
    }

    final snapshot = await (_db.select(
      _db.logEntryNutrients,
    )..where((n) => n.entryId.equals(entryId))).get();
    final scale = entry.gramsConsumed == 0
        ? 0.0
        : newGrams / entry.gramsConsumed;

    await _db.batch((batch) {
      batch.update(
        _db.foodLogEntries,
        FoodLogEntriesCompanion(
          quantity: Value(newQuantity),
          gramsConsumed: Value(newGrams),
          servingSizeId: Value(newServingId),
          mealSlotId: mealSlotId == null
              ? const Value.absent()
              : Value(mealSlotId),
          updatedAt: Value(DateTime.now()),
        ),
        where: (e) => e.id.equals(entryId),
      );

      batch.deleteWhere(
        _db.logEntryNutrients,
        (n) => n.entryId.equals(entryId),
      );
      batch.insertAll(_db.logEntryNutrients, [
        for (final n in snapshot)
          LogEntryNutrientsCompanion.insert(
            entryId: entryId,
            nutrientId: n.nutrientId,
            amount: n.amount * scale,
          ),
      ]);
    });
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
