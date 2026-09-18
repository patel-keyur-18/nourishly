// Finding every catalog row, from every source, and settling which one
// wins when two sources describe the same food.
//
// There are two sources now. `docs/catalog/*.md` is the older, hand-written
// catalog and holds every **ingredient** row. `app/assets/regional_food/
// *.csv` holds the regional **dish** catalogs and is the source of truth
// for the dishes it covers. More CSVs are expected; dropping one in is
// supposed to be the whole job, so files are discovered by glob and
// nothing here is enumerated by hand.
import 'dart:io';

import 'catalog_index.dart';
import 'catalog_source_entry.dart';
import 'catalog_source_parser.dart';
import 'composition.dart';
import 'csv_source_parser.dart';

/// One food that two or more sources described, and which one won.
class SupersededRow {
  const SupersededRow({required this.winner, required this.loser});

  final CatalogRow winner;
  final CatalogRow loser;

  @override
  String toString() =>
      '"${loser.entry.foodName}" from ${loser.entry.sourceFile} '
      'superseded by ${winner.entry.sourceFile}';
}

/// Every row the catalog is built from, after de-duplication.
class CatalogSources {
  const CatalogSources({required this.rows, required this.superseded});

  /// One row per food, in source order.
  final List<CatalogRow> rows;

  /// What lost, and to whom. Reported by `--check` so a collapse is
  /// visible rather than silent.
  final List<SupersededRow> superseded;
}

/// Where dish CSVs live. A glob, so the next regional catalog is added by
/// putting the file here.
const csvSourceDirectory = 'app/assets/regional_food';

/// Where the markdown catalog lives.
const markdownSourceDirectory = 'docs/catalog';

/// Source files in **precedence order**, highest first.
///
/// Precedence decides which row survives when two sources name the same
/// food, and it is declared rather than inferred because "whichever the
/// filesystem listed first" is not a decision anyone made.
///
/// The order is:
///
/// 1. the CSVs named in [_csvPrecedence], in that order;
/// 2. every other CSV, alphabetically;
/// 3. the markdown catalog, alphabetically.
///
/// **CSV always beats markdown.** The regional catalogs are the source of
/// truth for the dishes they cover; the markdown keeps the ingredient rows
/// and whatever dishes no CSV describes.
///
/// The four named CSVs are ahead of the rest because they are the files
/// that describe each dish once, on its own terms. The per-state files
/// reuse one composition across several different dishes — `Gajar halwa`
/// and `Rice kheer` are given the same line — so where both describe a
/// dish, the file that distinguishes them wins.
const _csvPrecedence = <String>[
  'nourishly_indian_food_catalog.csv',
  'nourishly_karnataka_tamilnadu_gujarat_food_catalog.csv',
  'nourishly_karnataka_tamilnadu_gujarat_additions_only.csv',
  'nourishly_common_international_food_catalog.csv',
];

/// The source files, in precedence order.
List<File> discoverSourceFiles({
  String csvDirectory = csvSourceDirectory,
  String markdownDirectory = markdownSourceDirectory,
}) {
  final csvDir = Directory(csvDirectory);
  final csvs = csvDir.existsSync()
      ? (csvDir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.toLowerCase().endsWith('.csv'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path)))
      : <File>[];

  int rank(File f) {
    final name = f.uri.pathSegments.last;
    final index = _csvPrecedence.indexOf(name);
    return index == -1 ? _csvPrecedence.length : index;
  }

  csvs.sort((a, b) {
    final byRank = rank(a).compareTo(rank(b));
    return byRank != 0 ? byRank : a.path.compareTo(b.path);
  });

  final mdDir = Directory(markdownDirectory);
  final markdown = mdDir.existsSync()
      ? (mdDir
            .listSync()
            .whereType<File>()
            .where(
              (f) => f.path.endsWith('.md') && !f.path.endsWith('README.md'),
            )
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path)))
      : <File>[];

  return [...csvs, ...markdown];
}

/// Parses every source file and collapses duplicate foods.
///
/// **One row per food, across everything.** A food is identified by its
/// name, normalized the way [catalogKey] normalizes any name, so
/// `Coconut rice` is one food however many files describe it. The first
/// row to claim a name wins, and because [discoverSourceFiles] returns
/// files in precedence order, "first" means "from the source that ought to
/// win".
///
/// Ingredient rows and dish rows share the namespace deliberately: if a
/// CSV ever describes a dish that the markdown carries as an ingredient,
/// one of them is wrong and the collapse makes that visible in `--check`
/// rather than shipping both.
CatalogSources loadCatalogSources({
  String csvDirectory = csvSourceDirectory,
  String markdownDirectory = markdownSourceDirectory,
}) {
  final markdownParser = CatalogSourceParser();
  final csvParser = CsvSourceParser();
  final compositionParser = CompositionParser();

  final rows = <CatalogRow>[];
  final superseded = <SupersededRow>[];
  final byName = <String, CatalogRow>{};

  for (final file in discoverSourceFiles(
    csvDirectory: csvDirectory,
    markdownDirectory: markdownDirectory,
  )) {
    final entries = file.path.toLowerCase().endsWith('.csv')
        ? csvParser.parseFile(file)
        : markdownParser.parseFile(file);

    for (final entry in entries) {
      final row = CatalogRow(
        entry,
        compositionParser.parse(entry.rawComposition),
      );
      final name = catalogKey(entry.foodName);
      final existing = byName[name];
      if (existing != null) {
        // One exception to file precedence: an **ingredient** row is never
        // displaced by a dish row of the same name.
        //
        // An ingredient row is infrastructure — other recipes resolve
        // through it — so losing one silently breaks every dish that used
        // it, and sometimes the dish that displaced it. `Coconut water` is
        // exactly that case: a CSV row whose only ingredient is coconut
        // water, which would have displaced the very row it needs.
        //
        // Nothing is lost by this. The food is still in the catalog and
        // still loggable; it is simply the ingredient row that represents
        // it, which for a one-ingredient "recipe" is the same food anyway.
        if (row.composition is UsdaLookup &&
            existing.composition is! UsdaLookup) {
          final index = rows.indexOf(existing);
          rows[index] = row;
          byName[name] = row;
          superseded.add(SupersededRow(winner: row, loser: existing));
          continue;
        }
        superseded.add(SupersededRow(winner: existing, loser: row));
        continue;
      }
      byName[name] = row;
      rows.add(row);
    }
  }

  return CatalogSources(rows: rows, superseded: superseded);
}

/// Every [CatalogSourceEntry] the sources hold, de-duplicated — for
/// callers that want the entries rather than the parsed rows.
List<CatalogSourceEntry> loadCatalogEntries({
  String csvDirectory = csvSourceDirectory,
  String markdownDirectory = markdownSourceDirectory,
}) => [
  for (final row in loadCatalogSources(
    csvDirectory: csvDirectory,
    markdownDirectory: markdownDirectory,
  ).rows)
    row.entry,
];
