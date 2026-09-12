import 'package:drift/drift.dart';

import '../database.dart';
import '../export/export_schema.dart';

/// Deletes everything one profile owns (§30.7, FR-U-12).
///
/// Built on the same [exportedTables] registry the exporter uses, in
/// reverse, and that is the point: **whatever an export can save, a delete
/// can remove.** Two hand-maintained lists would eventually disagree, and
/// the direction they would disagree in is a row that survives a deletion
/// the user was told was complete. One list cannot.
///
/// A hard delete, not a tombstone. Tombstones exist so that a *deletion*
/// travels through an export/import merge (§0.4); "delete everything on
/// this phone" is the user asking for the data to be gone, and leaving it
/// in the file marked deleted would not be that.
class ProfileEraser {
  ProfileEraser(this._db);

  final NourishlyDatabase _db;

  /// Removes every owned row, then puts the profile back to how a fresh
  /// install starts.
  ///
  /// §30.7: "Post-deletion — local data cleared; the app returns to a
  /// fresh guest state rather than an error state." So the `users` row
  /// itself stays and is reset: every provider in the app is built around
  /// there being a profile, and deleting the row to recreate it moments
  /// later would mean a window in which there is not one.
  Future<ErasureReport> eraseEverything(String ownerId) async {
    final removed = <String, int>{};

    await _db.transaction(() async {
      // Children before parents: the reverse of the order an import
      // inserts them in, so nothing is deleted out from under a foreign
      // key that still points at it.
      for (final table in exportedTables.reversed) {
        if (table.name == 'users') continue;
        final count = await _db.customUpdate(
          'DELETE FROM ${table.name} WHERE ${table.scope}',
          variables: [Variable<String>(ownerId)],
        );
        if (count > 0) removed[table.name] = count;
      }

      await (_db.update(_db.users)..where((u) => u.id.equals(ownerId))).write(
        UsersCompanion(
          displayName: const Value('You'),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });

    return ErasureReport(rowsRemoved: removed);
  }

  /// Confirms there is nothing left, by counting rather than by trusting
  /// the deletes — the same rule §0.5 applies to imports, for the same
  /// reason.
  Future<int> remainingRows(String ownerId) async {
    var total = 0;
    for (final table in exportedTables) {
      if (table.name == 'users') continue;
      final row = await _db
          .customSelect(
            'SELECT COUNT(*) AS c FROM ${table.name} WHERE ${table.scope}',
            variables: [Variable<String>(ownerId)],
          )
          .getSingle();
      total += row.data['c']! as int;
    }
    return total;
  }
}

class ErasureReport {
  const ErasureReport({required this.rowsRemoved});

  final Map<String, int> rowsRemoved;

  int get total => rowsRemoved.values.fold(0, (sum, count) => sum + count);
}
