import 'dart:convert';

/// A complete export, in memory (§30.6).
///
/// Plain maps and lists on purpose: the archive is handed to a background
/// isolate for encoding (§13.5 — export is one of the few operations that
/// can plausibly jank a frame), and only data that survives `SendPort`
/// without a codec can make that trip.
class ExportArchive {
  const ExportArchive({required this.manifest, required this.tables});

  final ExportManifest manifest;

  /// Table name to rows, each row a column-name/value map. Values are the
  /// JSON primitives: `String`, `num`, `bool`, or null, with every date
  /// already an ISO-8601 string.
  final Map<String, List<Map<String, Object?>>> tables;

  int get rowCount =>
      tables.values.fold(0, (sum, rows) => sum + rows.length);

  Map<String, Object?> toJson() => {
    'manifest': manifest.toJson(),
    'tables': tables,
  };

  static ExportArchive fromJson(Map<String, Object?> json) {
    final rawTables = json['tables'];
    if (rawTables is! Map) {
      throw const ExportFormatException('The file has no "tables" section.');
    }
    final manifest = json['manifest'];
    if (manifest is! Map) {
      throw const ExportFormatException('The file has no manifest.');
    }
    return ExportArchive(
      manifest: ExportManifest.fromJson(manifest.cast<String, Object?>()),
      tables: {
        for (final entry in rawTables.entries)
          entry.key as String: [
            for (final row in entry.value as List)
              (row as Map).cast<String, Object?>(),
          ],
      },
    );
  }
}

/// What an archive needs to carry to stay re-interpretable later (§30.6).
///
/// Without the versions, an export is a pile of numbers whose meaning
/// depends on code that has since changed: the ruleset version says which
/// scoring rules the derived summaries were computed under, and the schema
/// version is what lets a future import know whether it can read the file
/// at all.
class ExportManifest {
  const ExportManifest({
    required this.schemaVersion,
    required this.exportedAt,
    required this.profileId,
    required this.profileName,
    required this.counts,
    this.formatVersion = currentFormatVersion,
    this.rulesetVersion,
    this.catalogVersion,
    this.appVersion,
  });

  /// The archive layout itself, bumped only when the shape of this file
  /// changes in a way an older reader could misread.
  static const currentFormatVersion = 1;

  /// Identifies a Nourishly export at a glance, including to a person
  /// opening the JSON in a text editor.
  static const format = 'nourishly.export';

  final int formatVersion;

  /// [NourishlyDatabase.schemaVersion] at export time.
  final int schemaVersion;
  final String? rulesetVersion;
  final int? catalogVersion;
  final String? appVersion;
  final DateTime exportedAt;
  final String profileId;
  final String profileName;

  /// Rows per table, written at export time and checked after import.
  /// §0.5: "Reconcile per-entity counts before reporting success. An
  /// import that silently drops rows is a data-loss bug wearing a success
  /// message."
  final Map<String, int> counts;

  Map<String, Object?> toJson() => {
    'format': format,
    'formatVersion': formatVersion,
    'schemaVersion': schemaVersion,
    'rulesetVersion': rulesetVersion,
    'catalogVersion': catalogVersion,
    'appVersion': appVersion,
    'exportedAt': exportedAt.toIso8601String(),
    'profile': {'id': profileId, 'displayName': profileName},
    'counts': counts,
  };

  static ExportManifest fromJson(Map<String, Object?> json) {
    if (json['format'] != format) {
      throw const ExportFormatException(
        'This is not a Nourishly export file.',
      );
    }
    final profile = json['profile'];
    final exportedAt = DateTime.tryParse('${json['exportedAt']}');
    if (profile is! Map || exportedAt == null) {
      throw const ExportFormatException('The manifest is incomplete.');
    }
    return ExportManifest(
      formatVersion: (json['formatVersion'] as num?)?.toInt() ?? 1,
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 0,
      rulesetVersion: json['rulesetVersion'] as String?,
      catalogVersion: (json['catalogVersion'] as num?)?.toInt(),
      appVersion: json['appVersion'] as String?,
      exportedAt: exportedAt,
      profileId: '${profile['id']}',
      profileName: '${profile['displayName']}',
      counts: {
        for (final entry in (json['counts'] as Map? ?? {}).entries)
          '${entry.key}': (entry.value as num).toInt(),
      },
    );
  }
}

/// The file is not a Nourishly export, or is one this build cannot read.
class ExportFormatException implements Exception {
  const ExportFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Encodes an archive as JSON (§30.6's re-importable format).
///
/// A top-level function, and takes the archive's plain maps rather than
/// the object, so it can be handed straight to `compute()` — encoding a
/// long history is the CPU-bound half of an export and has no business on
/// the UI isolate.
String encodeArchiveJson(Map<String, Object?> archiveJson) =>
    const JsonEncoder.withIndent('  ').convert(archiveJson);

/// One CSV per entity (§30.6's spreadsheet-friendly format), keyed by file
/// name.
///
/// RFC 4180 quoting, and a header row on every file — a CSV without one is
/// not readable in a spreadsheet, which is the entire point of offering
/// this format alongside the JSON.
Map<String, String> encodeArchiveCsv(Map<String, Object?> archiveJson) {
  final tables = (archiveJson['tables']! as Map).cast<String, Object?>();
  final files = <String, String>{};
  for (final entry in tables.entries) {
    final rows = (entry.value! as List).cast<Map<String, Object?>>();
    if (rows.isEmpty) continue;
    // Union of every row's keys rather than the first row's: a nullable
    // column that is null in row one but set in row two must still get a
    // header, or its values silently shift into the wrong column.
    final columns = <String>{for (final row in rows) ...row.keys}.toList();
    final buffer = StringBuffer()..writeln(columns.map(_csvCell).join(','));
    for (final row in rows) {
      buffer.writeln(columns.map((c) => _csvCell(row[c])).join(','));
    }
    files['${entry.key}.csv'] = buffer.toString();
  }
  return files;
}

String _csvCell(Object? value) {
  if (value == null) return '';
  final text = '$value';
  if (text.contains(RegExp('[",\n\r]'))) {
    return '"${text.replaceAll('"', '""')}"';
  }
  return text;
}
