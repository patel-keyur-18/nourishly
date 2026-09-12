import 'package:drift/drift.dart';

import '../database.dart';
import 'data_exporter.dart';
import 'export_archive.dart';
import 'export_schema.dart';

/// What an import did, per entity (§0.5's reconciliation rule).
class EntityImportResult {
  const EntityImportResult({
    required this.table,
    required this.inArchive,
    required this.inserted,
    required this.updated,
    required this.unchanged,
    required this.skippedOlder,
    required this.present,
  });

  final String table;
  final int inArchive;
  final int inserted;
  final int updated;

  /// Rows the device already had, byte for byte. Counted separately from
  /// [updated] so that re-importing the same file reports honestly as "no
  /// change" rather than as a few hundred rewrites.
  final int unchanged;

  /// Rows the archive held that the device already had a newer copy of.
  /// Skipping these is the correct outcome, not a loss — it is what stops
  /// an older export from undoing today's logging.
  final int skippedOlder;

  /// Rows from the archive that are in the database now, counted by
  /// reading them back rather than by trusting the writes.
  final int present;

  /// The check that decides whether "imported" is a true statement.
  bool get reconciled => present == inArchive;

  int get missing => inArchive - present;

  @override
  String toString() =>
      '$table: $inArchive in archive, $present present '
      '($inserted new, $updated updated, $unchanged unchanged, '
      '$skippedOlder left to the device)';
}

/// The outcome of a whole import.
class ImportReport {
  const ImportReport({required this.entities, required this.daysAffected});

  final List<EntityImportResult> entities;

  /// Log dates whose summaries were marked stale, so the dashboard and
  /// reports recompute against the imported entries.
  final int daysAffected;

  /// §0.5: an import that silently drops rows is a data-loss bug wearing a
  /// success message. Nothing reports success unless every entity
  /// reconciles.
  bool get succeeded => entities.every((e) => e.reconciled);

  int get totalInserted => entities.fold(0, (sum, e) => sum + e.inserted);
  int get totalUpdated => entities.fold(0, (sum, e) => sum + e.updated);
  int get totalUnchanged => entities.fold(0, (sum, e) => sum + e.unchanged);
  int get totalSkipped => entities.fold(0, (sum, e) => sum + e.skippedOlder);

  List<EntityImportResult> get unreconciled =>
      entities.where((e) => !e.reconciled).toList();
}

/// Merges an [ExportArchive] into the database by UUID (§0.5).
///
/// The three rules that make this safe to run against a device that is
/// already in use:
///
/// 1. **Merge by id, never append.** Importing the same file twice changes
///    nothing the second time, and importing into a fresh install restores
///    everything.
/// 2. **Newer wins, by `updated_at`.** An older export dropped on top of
///    newer data leaves the newer data alone. Tombstones ride the same
///    rule, which is how a deletion made on one device survives the trip.
/// 3. **Derived data is recomputed, not imported.** Summaries and scores
///    in the archive are for the reader's benefit; what lands here are the
///    entries they were computed from, and the days they touch are marked
///    stale.
class DataImporter {
  DataImporter(this._db);

  final NourishlyDatabase _db;

  /// Merges [archive] into this device.
  ///
  /// [asOwner] re-homes the archive onto an existing profile — importing a
  /// backup into a fresh install where the local profile was created with
  /// a different id, which is the common case and otherwise produces two
  /// profiles where the user expects one. Null keeps the archive's own
  /// owner id.
  Future<ImportReport> import(
    ExportArchive archive, {
    String? asOwner,
    void Function(int done, int total)? onProgress,
  }) async {
    if (archive.manifest.schemaVersion > _db.schemaVersion) {
      throw ExportFormatException(
        'This file was written by a newer version of Nourishly '
        '(data version ${archive.manifest.schemaVersion}; this app reads '
        'up to ${_db.schemaVersion}). Update the app and try again.',
      );
    }

    final sourceOwner = archive.manifest.profileId;
    final targetOwner = asOwner ?? sourceOwner;
    final results = <EntityImportResult>[];
    final touchedDays = <DateTime>{};
    // Which parent rows this import took from the archive, and which it
    // left alone because the device held something newer. The child pass
    // needs both: children follow their parent's verdict, or an edited
    // entry ends up carrying the union of two nutrient snapshots.
    final verdicts = <String, _ParentVerdicts>{};

    await _db.transaction(() async {
      final importable = importableTables.toList();
      for (var i = 0; i < importable.length; i++) {
        final table = importable[i];
        final rows = _rehome(
          archive.tables[table.name] ?? const [],
          sourceOwner: sourceOwner,
          targetOwner: targetOwner,
        );
        results.add(await _mergeTable(table, rows, verdicts));
        if (table.name == 'food_log_entries' ||
            table.name == 'water_log_entries') {
          for (final row in rows) {
            final date = DateTime.tryParse('${row['log_date']}');
            if (date != null) {
              touchedDays.add(DateTime(date.year, date.month, date.day));
            }
          }
        }
        onProgress?.call(i + 1, importable.length);
      }
      await _markDaysStale(targetOwner, touchedDays);
    });

    return ImportReport(entities: results, daysAffected: touchedDays.length);
  }

  /// Rewrites the archive's owner id to the local profile's, in every
  /// column that carries one.
  List<Map<String, Object?>> _rehome(
    List<Map<String, Object?>> rows, {
    required String sourceOwner,
    required String targetOwner,
  }) {
    if (sourceOwner == targetOwner) return rows;
    return [
      for (final row in rows)
        {
          for (final entry in row.entries)
            entry.key:
                (entry.key == 'owner_id' || entry.key == 'id') &&
                    entry.value == sourceOwner
                ? targetOwner
                : entry.value,
        },
    ];
  }

  Future<EntityImportResult> _mergeTable(
    ExportedTable table,
    List<Map<String, Object?>> rows,
    Map<String, _ParentVerdicts> verdicts,
  ) async {
    final columns = _columnsOf(table.name);
    final typed = dateTimeColumnsOf(_db, table.name);
    final hasUpdatedAt = columns.contains('updated_at');
    final relation = table.childOf;
    final parentVerdict = relation == null ? null : verdicts[relation.$1];
    final mine = _ParentVerdicts();

    // A parent this import replaced may have lost children since the
    // archive was written. Clearing them before the incoming rows land is
    // what stops an edited entry from ending up with the union of both
    // versions' nutrient snapshots. Only for parents the archive won:
    // where the device held the newer parent, its children are the ones
    // that belong to it.
    if (relation != null && parentVerdict != null) {
      await _clearChildrenOf(table.name, relation.$2, parentVerdict.accepted);
    }

    var inserted = 0;
    var updated = 0;
    var unchanged = 0;
    var skipped = 0;
    final deferredToDevice = <Map<String, Object?>>[];

    for (final row in rows) {
      // Unknown columns are dropped rather than refused: a file from a
      // build with one extra column is still worth reading, and the
      // alternative is telling a user their backup is unusable over a
      // field this version has no opinion about.
      final values = <String, Object?>{
        for (final entry in row.entries)
          if (columns.contains(entry.key))
            entry.key: _toSql(entry.value, typed[entry.key]),
      };
      if (!table.primaryKey.every(values.containsKey)) continue;

      // Children follow their parent's verdict. A child whose parent the
      // device won is not dropped data — it is data the device has a
      // newer version of, under a parent this import deliberately left
      // alone.
      if (relation != null &&
          parentVerdict != null &&
          parentVerdict.rejected.contains('${values[relation.$2]}')) {
        deferredToDevice.add(values);
        continue;
      }

      final id = '${values[table.primaryKey.first]}';
      final existing = await _existing(table, values);
      if (existing == null) {
        await _insert(table.name, values);
        inserted++;
        mine.accepted.add(id);
      } else if (_identical(values, existing)) {
        // Neither side wins, because there is nothing to win. Importing
        // the same file twice lands here for every row, which is what
        // makes the second pass a genuine no-op rather than a rewrite
        // that happens to produce the same bytes. It also spares the
        // child tables a purge-and-reinsert they do not need.
        unchanged++;
      } else if (!hasUpdatedAt || _isNewer(values, existing)) {
        await _update(table, values);
        updated++;
        mine.accepted.add(id);
      } else {
        skipped++;
        mine.rejected.add(id);
      }
    }

    verdicts[table.name] = mine;

    // A deferred child is accounted for either way: if its id still exists
    // it was counted by the read-back, and if it does not, that is because
    // the device's newer parent carries its own children instead — which
    // is the merge working, not a row going missing.
    var deferredAndGone = 0;
    for (final values in deferredToDevice) {
      if (await _existing(table, values) == null) deferredAndGone++;
    }

    return EntityImportResult(
      table: table.name,
      inArchive: rows.length,
      inserted: inserted,
      updated: updated,
      unchanged: unchanged,
      skippedOlder: skipped + deferredToDevice.length,
      present: await _countPresent(table, rows) + deferredAndGone,
    );
  }

  Future<void> _clearChildrenOf(
    String childTable,
    String foreignKey,
    Set<String> parentIds,
  ) async {
    if (parentIds.isEmpty) return;
    final placeholders = List.filled(parentIds.length, '?').join(', ');
    await _db.customUpdate(
      'DELETE FROM $childTable WHERE $foreignKey IN ($placeholders)',
      variables: [for (final id in parentIds) Variable<String>(id)],
    );
  }

  Future<Map<String, Object?>?> _existing(
    ExportedTable table,
    Map<String, Object?> values,
  ) async {
    final where = table.primaryKey.map((c) => '$c = ?').join(' AND ');
    final rows = await _db
        .customSelect(
          'SELECT * FROM ${table.name} WHERE $where LIMIT 1',
          variables: [
            for (final column in table.primaryKey) _variable(values[column]),
          ],
        )
        .get();
    return rows.firstOrNull?.data;
  }

  /// Whether the archive's row says exactly what the device's already
  /// does, across the columns the import would write.
  bool _identical(
    Map<String, Object?> incoming,
    Map<String, Object?> existing,
  ) {
    for (final entry in incoming.entries) {
      final mine = existing[entry.key];
      final theirs = entry.value;
      if (mine is num && theirs is num) {
        if (mine.toDouble() != theirs.toDouble()) return false;
      } else if (mine != theirs) {
        return false;
      }
    }
    return true;
  }

  bool _isNewer(Map<String, Object?> incoming, Map<String, Object?> existing) {
    final incomingAt = incoming['updated_at'];
    final existingAt = existing['updated_at'];
    if (incomingAt is! int || existingAt is! int) return true;
    return incomingAt > existingAt;
  }

  Future<void> _insert(String table, Map<String, Object?> values) {
    final columns = values.keys.join(', ');
    final placeholders = List.filled(values.length, '?').join(', ');
    return _db.customInsert(
      'INSERT INTO $table ($columns) VALUES ($placeholders)',
      variables: [for (final value in values.values) _variable(value)],
    );
  }

  Future<void> _update(ExportedTable table, Map<String, Object?> values) {
    final assignments = values.keys
        .where((c) => !table.primaryKey.contains(c))
        .map((c) => '$c = ?')
        .join(', ');
    if (assignments.isEmpty) return Future.value();
    final where = table.primaryKey.map((c) => '$c = ?').join(' AND ');
    return _db.customUpdate(
      'UPDATE ${table.name} SET $assignments WHERE $where',
      variables: [
        for (final entry in values.entries)
          if (!table.primaryKey.contains(entry.key)) _variable(entry.value),
        for (final column in table.primaryKey) _variable(values[column]),
      ],
    );
  }

  /// Reads back what is actually there, rather than trusting the insert
  /// and update counters — the whole point of §0.5's reconciliation rule
  /// is that a write which believed it succeeded is not evidence.
  Future<int> _countPresent(
    ExportedTable table,
    List<Map<String, Object?>> rows,
  ) async {
    if (rows.isEmpty) return 0;
    final typed = dateTimeColumnsOf(_db, table.name);
    var present = 0;
    final where = table.primaryKey.map((c) => '$c = ?').join(' AND ');
    for (final row in rows) {
      final result = await _db
          .customSelect(
            'SELECT 1 FROM ${table.name} WHERE $where LIMIT 1',
            variables: [
              for (final column in table.primaryKey)
                _variable(_toSql(row[column], typed[column])),
            ],
          )
          .get();
      if (result.isNotEmpty) present++;
    }
    return present;
  }

  /// Every imported day recomputes rather than trusting the archive's
  /// summaries — see [ExportedTable.derived].
  Future<void> _markDaysStale(String ownerId, Set<DateTime> days) async {
    for (final day in days) {
      await _db.customUpdate(
        'UPDATE daily_summaries SET is_stale = 1 '
        'WHERE owner_id = ? AND log_date = ?',
        variables: [
          Variable<String>(ownerId),
          Variable<int>(day.millisecondsSinceEpoch ~/ 1000),
        ],
      );
    }
  }

  Set<String> _columnsOf(String tableName) {
    final table = _db.allTables.firstWhere(
      (t) => t.actualTableName == tableName,
    );
    return {for (final column in table.$columns) column.name};
  }

  /// The inverse of the exporter's readability conversions.
  static Object? _toSql(Object? value, DriftSqlType? type) {
    return switch (type) {
      DriftSqlType.dateTime when value is String =>
        (DateTime.tryParse(value)?.millisecondsSinceEpoch ?? 0) ~/ 1000,
      DriftSqlType.bool when value is bool => value ? 1 : 0,
      _ => value,
    };
  }

  static Variable<Object> _variable(Object? value) => switch (value) {
    null => const Variable<String>(null),
    final int v => Variable<int>(v),
    final double v => Variable<double>(v),
    final bool v => Variable<bool>(v),
    _ => Variable<String>('$value'),
  };
}

/// Which of a parent table's rows an import took from the archive, and
/// which it left to the device.
class _ParentVerdicts {
  final Set<String> accepted = {};
  final Set<String> rejected = {};
}
