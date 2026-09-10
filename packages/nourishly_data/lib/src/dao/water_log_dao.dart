import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database.dart';

const _uuid = Uuid();

/// Water logging — immutable and additive by design (§17.6, §22.5): an
/// edit is a delete-and-recreate, never an in-place amount change.
class WaterLogDao {
  WaterLogDao(this._db);

  final NourishlyDatabase _db;

  Future<String> logWater({
    required String ownerId,
    required double volumeMl,
    required DateTime logDate,
  }) async {
    final id = _uuid.v7();
    final now = DateTime.now();
    await _db
        .into(_db.waterLogEntries)
        .insert(
          WaterLogEntriesCompanion.insert(
            id: id,
            ownerId: ownerId,
            logDate: logDate,
            loggedAt: now,
            volumeMl: volumeMl,
            source: 'quick_add',
          ),
        );
    return id;
  }

  /// Soft-deletes one entry — the inline-undo path (UX-7, §27.7).
  Future<void> undo(String entryId) {
    return (_db.update(_db.waterLogEntries)..where((e) => e.id.equals(entryId)))
        .write(WaterLogEntriesCompanion(deletedAt: Value(DateTime.now())));
  }

  /// Restores an entry [undo] soft-deleted.
  Future<void> restore(String entryId) {
    return (_db.update(_db.waterLogEntries)..where((e) => e.id.equals(entryId)))
        .write(const WaterLogEntriesCompanion(deletedAt: Value(null)));
  }

  /// Changes a past entry's amount (FR-W-07).
  ///
  /// Delete-and-recreate, never an in-place amount change, per this DAO's
  /// additive-by-design contract above: the original row stays as a
  /// soft-deleted fact and a new one carries the corrected volume. The
  /// original `loggedAt` is kept so the entry does not jump position in
  /// the day's list just because it was corrected.
  Future<String> edit({
    required String entryId,
    required double volumeMl,
  }) async {
    final original = await (_db.select(
      _db.waterLogEntries,
    )..where((e) => e.id.equals(entryId))).getSingle();

    final replacementId = _uuid.v7();
    await _db.batch((batch) {
      batch.update(
        _db.waterLogEntries,
        WaterLogEntriesCompanion(deletedAt: Value(DateTime.now())),
        where: (e) => e.id.equals(entryId),
      );
      batch.insert(
        _db.waterLogEntries,
        WaterLogEntriesCompanion.insert(
          id: replacementId,
          ownerId: original.ownerId,
          logDate: original.logDate,
          loggedAt: original.loggedAt,
          volumeMl: volumeMl,
          source: original.source,
        ),
      );
    });
    return replacementId;
  }

  Stream<List<WaterLogEntry>> watchToday({
    required String ownerId,
    required DateTime logDate,
  }) {
    return (_db.select(_db.waterLogEntries)
          ..where(
            (e) =>
                e.ownerId.equals(ownerId) &
                e.logDate.equals(logDate) &
                e.deletedAt.isNull(),
          )
          ..orderBy([(e) => OrderingTerm.desc(e.loggedAt)]))
        .watch();
  }

  /// Daily water total is always `SUM(volume_ml)` over live rows — never a
  /// stored counter (I-9).
  Stream<double> watchTodayTotal({
    required String ownerId,
    required DateTime logDate,
  }) {
    return watchToday(
      ownerId: ownerId,
      logDate: logDate,
    ).map((entries) => entries.fold(0.0, (sum, e) => sum + e.volumeMl));
  }
}
