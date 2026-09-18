import 'dart:io';

import 'catalog_source_entry.dart';

/// Parses a `Food,Also,Serving,g,Composition` CSV into
/// [CatalogSourceEntry] rows — the same five columns the markdown tables
/// use, so everything downstream (composition parsing, row keys, the lock,
/// cuisine tags, the seed build) works on them unchanged.
///
/// CSV is the format the regional catalogs arrive in, and they are the
/// source of truth for the dishes they cover. Converting them to markdown
/// would leave two copies of every row and guarantee the two drift, so the
/// pipeline reads them where they are.
///
/// A CSV has no `## N.` headings, so every row is filed under one section
/// named after the file. Cuisine and course come from the registry in
/// `cuisine_tags.dart` instead.
class CsvSourceParser {
  /// The section name given to every row of [sourceFile], since a CSV has
  /// no headings of its own: `nourishly_kerala_food_catalog.csv` ->
  /// `Kerala food catalog`.
  static String sectionFor(String sourceFile) {
    final stem = sourceFile
        .split('/')
        .last
        .replaceAll(RegExp(r'\.csv$', caseSensitive: false), '')
        .replaceAll(RegExp(r'^nourishly[_-]'), '')
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .trim();
    if (stem.isEmpty) return sourceFile;
    return stem[0].toUpperCase() + stem.substring(1);
  }

  List<CatalogSourceEntry> parseFile(File file) {
    final sourceFile = file.uri.pathSegments.last;
    final section = sectionFor(sourceFile);
    // `utf-8-sig` equivalent: several of these files begin with a BOM,
    // which would otherwise become part of the first header's name.
    final text = file.readAsStringSync().replaceFirst('﻿', '');

    final records = _parseCsv(text);
    if (records.isEmpty) return const [];

    final header = [
      for (final cell in records.first) cell.trim().toLowerCase(),
    ];
    const expected = ['food', 'also', 'serving', 'g', 'composition'];
    if (!_sameColumns(header, expected)) {
      throw FormatException(
        'Expected columns ${expected.join(', ')} in ${file.path}, '
        'got ${header.join(', ')}',
      );
    }

    final entries = <CatalogSourceEntry>[];
    for (var i = 1; i < records.length; i++) {
      final cells = records[i];
      // A trailing newline, or a row someone left blank, is not an error.
      if (cells.every((c) => c.trim().isEmpty)) continue;
      if (cells.length != expected.length) {
        throw FormatException(
          'Expected ${expected.length} columns in ${file.path} row ${i + 1}, '
          'got ${cells.length}: ${cells.join(' | ')}',
        );
      }

      final rawName = cells[0].trim();
      if (rawName.isEmpty) continue;
      final isTier1 = _tier1.hasMatch(rawName);
      final foodName = rawName
          .replaceFirst(_tier1, '')
          .replaceAll('**', '')
          .trim();

      final grams = double.tryParse(cells[3].trim());
      if (grams == null) {
        throw FormatException(
          'Serving weight "${cells[3]}" in ${file.path} row ${i + 1} '
          '($foodName) is not a number. It is the dish\'s cooking yield, '
          'so it cannot be guessed.',
        );
      }

      entries.add(
        CatalogSourceEntry(
          sourceFile: sourceFile,
          section: section,
          isTier1: isTier1,
          foodName: foodName,
          alsoNames: _splitAlso(cells[1]),
          servingLabel: cells[2].trim().isEmpty ? '1 serving' : cells[2].trim(),
          servingAmount: grams,
          weightColumnLabel: 'g',
          rawComposition: cells[4].trim(),
        ),
      );
    }
    return entries;
  }

  static final _tier1 = RegExp(r'^\*\*①\*\*\s*');

  static bool _sameColumns(List<String> a, List<String> b) =>
      a.length == b.length &&
      [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((x) => x);

  static List<String> _splitAlso(String cell) {
    final raw = cell.trim();
    if (raw.isEmpty || raw == '—' || raw == '-') return const [];
    return [
      for (final part in raw.split(RegExp(r'[,/]')))
        if (part.trim().isNotEmpty && part.trim() != '—' && part.trim() != '-')
          part.trim(),
    ];
  }

  /// A minimal RFC 4180 reader: quoted fields, doubled quotes inside them,
  /// and newlines inside quotes.
  ///
  /// Written out rather than taken from a package because it is twenty
  /// lines, the pipeline has no other use for a CSV dependency, and a
  /// composition cell containing a comma inside quotes is the one case
  /// that a naive `split(',')` would silently corrupt.
  static List<List<String>> _parseCsv(String text) {
    final records = <List<String>>[];
    var record = <String>[];
    final field = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (inQuotes) {
        if (ch == '"') {
          if (i + 1 < text.length && text[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          field.write(ch);
        }
        continue;
      }
      switch (ch) {
        case '"':
          inQuotes = true;
        case ',':
          record.add(field.toString());
          field.clear();
        case '\r':
          break;
        case '\n':
          record.add(field.toString());
          field.clear();
          records.add(record);
          record = <String>[];
        default:
          field.write(ch);
      }
    }
    if (field.isNotEmpty || record.isNotEmpty) {
      record.add(field.toString());
      records.add(record);
    }
    return records;
  }
}
