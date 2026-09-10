import 'dart:io';

import 'catalog_source_entry.dart';

final _sectionHeading = RegExp(r'^##\s+(?:\d+\.\s*)?(.+?)\s*$');

// The four catalog tables all share the same five columns, though the
// weight column's header text varies (`g`, `ml`, `g/ml` — §catalog/01
// line 67 etc.), so it isn't matched literally.
final _tableHeader = RegExp(
  r'^\|\s*Food\s*\|\s*Also\s*\|\s*Serving\s*\|\s*([^|]+?)\s*\|\s*Composition\s*\|\s*$',
);
final _tableDivider = RegExp(
  r'^\|[\s:-]+\|[\s:-]+\|[\s:-]+\|[\s:-]+\|[\s:-]+\|\s*$',
);
final _tableRow = RegExp(r'^\|(.*)\|\s*$');

final _tier1Marker = RegExp(r'^\*\*①\*\*\s*');

/// Parses every `Food | Also | Serving | g | Composition` table in a
/// `docs/catalog/*.md` file into [CatalogSourceEntry] rows.
///
/// This only understands the shape those four files actually use — it is
/// deliberately not a general Markdown table parser. A row it can't make
/// sense of is a bug in this parser or a change to the source format, not
/// something to guess past.
class CatalogSourceParser {
  List<CatalogSourceEntry> parseFile(File file) {
    final entries = <CatalogSourceEntry>[];
    final lines = file.readAsLinesSync();
    var section = '(none)';
    var inTable = false;
    var weightColumnLabel = 'g';

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];

      final heading = _sectionHeading.firstMatch(line);
      if (heading != null) {
        section = heading.group(1)!;
        inTable = false;
        continue;
      }

      final header = _tableHeader.firstMatch(line);
      if (header != null) {
        weightColumnLabel = header.group(1)!;
        inTable = false; // wait for the divider row before reading data
        continue;
      }

      if (_tableDivider.hasMatch(line)) {
        inTable = true;
        continue;
      }

      if (!inTable) continue;

      final row = _tableRow.firstMatch(line);
      if (row == null) {
        // A blank line or prose ends the table.
        inTable = false;
        continue;
      }

      final cells = _splitRow(row.group(1)!);
      if (cells.length != 5) {
        throw FormatException(
          'Expected 5 columns (Food | Also | Serving | $weightColumnLabel | '
          'Composition), got ${cells.length} in ${file.path}:${i + 1}: $line',
        );
      }

      entries.add(
        _parseRow(
          sourceFile: file.uri.pathSegments.last,
          section: section,
          weightColumnLabel: weightColumnLabel,
          cells: cells,
          lineNumber: i + 1,
          path: file.path,
        ),
      );
    }

    return entries;
  }

  CatalogSourceEntry _parseRow({
    required String sourceFile,
    required String section,
    required String weightColumnLabel,
    required List<String> cells,
    required int lineNumber,
    required String path,
  }) {
    final rawFood = cells[0];
    final isTier1 = _tier1Marker.hasMatch(rawFood);
    final foodName = rawFood.replaceFirst(_tier1Marker, '').trim();

    final alsoRaw = cells[1];
    final alsoNames = alsoRaw == '—' || alsoRaw.isEmpty
        ? const <String>[]
        : alsoRaw
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList(growable: false);

    final amountText = cells[3].trim();
    final amount = double.tryParse(amountText);
    if (amount == null) {
      throw FormatException(
        'Non-numeric weight "$amountText" for "$foodName" at $path:$lineNumber',
      );
    }

    return CatalogSourceEntry(
      sourceFile: sourceFile,
      section: section,
      isTier1: isTier1,
      foodName: foodName,
      alsoNames: alsoNames,
      servingLabel: cells[2].trim(),
      servingAmount: amount,
      weightColumnLabel: weightColumnLabel,
      rawComposition: cells[4].trim(),
    );
  }

  /// Splits a table row on unescaped `|`, trimming each cell. Markdown
  /// table cells in these files never contain a literal `\|`, so a plain
  /// split is sufficient.
  List<String> _splitRow(String row) =>
      row.split('|').map((c) => c.trim()).toList(growable: false);
}
