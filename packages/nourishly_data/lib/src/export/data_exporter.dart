import 'package:drift/drift.dart';

import '../database.dart';
import 'export_archive.dart';
import 'export_schema.dart';

/// Builds a complete, re-importable archive of one profile's data
/// (FR-U-13, FR-S-03, §30.6).
///
/// Reads through raw SQL rather than the generated row classes on purpose.
/// The archive has to be *complete*, and a hand-written mapper per table
/// is a list somebody eventually forgets to extend — the failure mode is a
/// backup that silently omits whatever was added last. `SELECT *` plus the
/// column metadata drift already holds cannot forget a column, and
/// `export_completeness_test.dart` checks the table list against the live
/// schema for the same reason.
class DataExporter {
  DataExporter(this._db);

  final NourishlyDatabase _db;

  /// Reads every owned row for [ownerId].
  ///
  /// [onProgress] reports tables finished out of tables total, so a long
  /// history shows movement rather than a frozen sheet (§30.6).
  Future<ExportArchive> export({
    required String ownerId,
    String? rulesetVersion,
    String? appVersion,
    void Function(int done, int total)? onProgress,
    DateTime? exportedAt,
  }) async {
    final tables = <String, List<Map<String, Object?>>>{};
    for (var i = 0; i < exportedTables.length; i++) {
      final table = exportedTables[i];
      tables[table.name] = await _readTable(table, ownerId);
      onProgress?.call(i + 1, exportedTables.length);
    }

    final profile = tables['users']!.firstOrNull;
    return ExportArchive(
      manifest: ExportManifest(
        schemaVersion: _db.schemaVersion,
        rulesetVersion: rulesetVersion,
        catalogVersion: await _catalogVersion(),
        appVersion: appVersion,
        exportedAt: exportedAt ?? DateTime.now(),
        profileId: ownerId,
        profileName: '${profile?['display_name'] ?? 'Unknown'}',
        counts: {
          for (final entry in tables.entries) entry.key: entry.value.length,
        },
      ),
      tables: tables,
    );
  }

  Future<List<Map<String, Object?>>> _readTable(
    ExportedTable table,
    String ownerId,
  ) async {
    final dateColumns = dateTimeColumnsOf(_db, table.name);
    final rows = await _db
        .customSelect(
          'SELECT * FROM ${table.name} WHERE ${table.scope}',
          variables: [Variable<String>(ownerId)],
        )
        .get();
    return [for (final row in rows) _rowToJson(row.data, dateColumns)];
  }

  /// SQLite hands back what it stores. Two conversions make the archive
  /// readable rather than merely round-trippable: dates become ISO-8601
  /// strings instead of unix seconds, and booleans become `true`/`false`
  /// instead of 1/0. Both are reversed on import.
  static Map<String, Object?> _rowToJson(
    Map<String, Object?> data,
    Map<String, DriftSqlType> typedColumns,
  ) {
    return {
      for (final entry in data.entries)
        entry.key: switch (typedColumns[entry.key]) {
          DriftSqlType.dateTime when entry.value is int =>
            DateTime.fromMillisecondsSinceEpoch((entry.value! as int) * 1000)
                .toIso8601String(),
          DriftSqlType.bool when entry.value is int => entry.value == 1,
          _ => entry.value,
        },
    };
  }

  Future<int?> _catalogVersion() async {
    final rows = await _db
        .customSelect('SELECT MAX(version) AS v FROM catalog_versions')
        .get();
    return rows.firstOrNull?.data['v'] as int?;
  }
}

/// The date-time and boolean columns of [tableName], read from drift's own
/// metadata so the conversion above cannot drift from the schema.
Map<String, DriftSqlType> dateTimeColumnsOf(
  GeneratedDatabase db,
  String tableName,
) {
  final table = db.allTables.firstWhere((t) => t.actualTableName == tableName);
  return {
    for (final column in table.$columns)
      if (column.type == DriftSqlType.dateTime)
        column.name: DriftSqlType.dateTime
      else if (column.type == DriftSqlType.bool)
        column.name: DriftSqlType.bool,
  };
}
