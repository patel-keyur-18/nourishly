import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:nourishly_data/nourishly_data.dart';
import 'package:path_provider/path_provider.dart';

/// Which of §30.6's two formats the user asked for.
enum ExportFormat {
  /// Complete and re-importable. The one that is a backup.
  json('JSON', 'Complete, and can be imported back.'),

  /// Spreadsheet-friendly, one file per entity, delivered as a folder of
  /// CSVs. Readable anywhere, but not a backup: it cannot be imported.
  csv('CSV', 'One file per table, for a spreadsheet.');

  const ExportFormat(this.label, this.description);

  final String label;
  final String description;
}

/// What an export produced.
class ExportResult {
  const ExportResult({
    required this.files,
    required this.rowCount,
    required this.exportedAt,
  });

  final List<File> files;
  final int rowCount;
  final DateTime exportedAt;

  int get bytes => files.fold(0, (sum, file) => sum + file.lengthSync());
}

/// Writes a complete archive to a file the user can keep (§0.5, §30.6).
///
/// The encoding runs in a background isolate. §13.5 lists data export
/// among the operations that can plausibly jank a frame, and serialising
/// years of entries to indented JSON is exactly that kind of work —
/// megabytes of string building on the isolate that is also trying to
/// animate a progress indicator.
class ExportService {
  ExportService(this._db);

  final NourishlyDatabase _db;

  /// Where generated files live.
  ///
  /// The support directory rather than documents: these are the app's
  /// working copies, not files the user manages. They are excluded from
  /// Android Auto Backup by name (`backup_rules.xml`), and on iOS the
  /// support directory's contents are handed straight to the share sheet
  /// and replaced on the next export rather than accumulating.
  static Future<Directory> exportDirectory() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/exports');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Future<ExportResult> export({
    required String ownerId,
    required ExportFormat format,
    String? rulesetVersion,
    String? appVersion,
    void Function(double fraction)? onProgress,
  }) async {
    final archive = await DataExporter(_db).export(
      ownerId: ownerId,
      rulesetVersion: rulesetVersion,
      appVersion: appVersion,
      // Reading is a little over half the work; the rest is encoding.
      onProgress: (done, total) => onProgress?.call(done / total * 0.6),
    );

    final json = archive.toJson();
    final dir = await exportDirectory();
    // A fresh folder per export, stamped with the date: two exports on
    // different days should not silently overwrite each other, and the
    // name is what the user sees in their file manager a year later.
    final stamp = _stamp(archive.manifest.exportedAt);

    final files = <File>[];
    if (format == ExportFormat.json) {
      final text = await compute(encodeArchiveJson, json);
      onProgress?.call(0.9);
      files.add(
        await File('${dir.path}/nourishly-$stamp.json').writeAsString(text),
      );
    } else {
      final sheets = await compute(encodeArchiveCsv, json);
      onProgress?.call(0.9);
      final folder = Directory('${dir.path}/nourishly-$stamp')
        ..createSync(recursive: true);
      for (final entry in sheets.entries) {
        files.add(
          await File('${folder.path}/${entry.key}').writeAsString(entry.value),
        );
      }
    }

    onProgress?.call(1);
    return ExportResult(
      files: files,
      rowCount: archive.rowCount,
      exportedAt: archive.manifest.exportedAt,
    );
  }

  /// Reads an archive chosen by the user, and merges it (§0.5).
  ///
  /// Decoding runs in a background isolate for the same reason encoding
  /// does. The merge itself does not: it is a long run of small SQLite
  /// writes inside one transaction, and moving a live database connection
  /// across isolates is a much larger change than the frame it would
  /// save.
  Future<ImportReport> import({
    required File file,
    required String ownerId,
    void Function(double fraction)? onProgress,
  }) async {
    final text = await file.readAsString();
    final decoded = await compute(_decodeArchive, text);
    onProgress?.call(0.3);
    return DataImporter(_db).import(
      decoded,
      asOwner: ownerId,
      onProgress: (done, total) => onProgress?.call(0.3 + done / total * 0.7),
    );
  }

  /// Deletes previously generated exports.
  ///
  /// Called after a successful share: the user has their copy wherever
  /// they put it, and leaving a complete unencrypted archive of their food
  /// diary sitting in app storage indefinitely is the sort of thing §30.3
  /// exists to avoid.
  Future<void> clearGenerated() async {
    final dir = await exportDirectory();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }

  static String _stamp(DateTime at) =>
      '${at.year}-${_two(at.month)}-${_two(at.day)}-'
      '${_two(at.hour)}${_two(at.minute)}';

  static String _two(int value) => value.toString().padLeft(2, '0');
}

/// Top-level so it can cross an isolate boundary.
ExportArchive _decodeArchive(String text) {
  final decoded = jsonDecode(text);
  if (decoded is! Map<String, Object?>) {
    throw const ExportFormatException('That file is not a Nourishly export.');
  }
  return ExportArchive.fromJson(decoded);
}
