import 'package:drift/drift.dart';

import '../cuisine_tags.dart';
import '../database.dart';

/// One cuisine and how much of it there is.
class CuisineCount {
  const CuisineCount(this.cuisine, this.count);

  final String cuisine;
  final int count;
}

/// Reading the catalog and the log by cuisine (§0.8 of the catalog spec).
///
/// Two jobs, both of which only start to matter now that the catalog has
/// grown past the size anyone can hold in their head:
///
/// * **Browsing.** At 441 foods across seven cuisines, "search for a food"
///   assumes you already know what is in there. A list of cuisines is the
///   other half of that.
/// * **Ranking.** A household that eats Gujarati food and types "dal"
///   means Gujarati dal, not dal makhani. What they have logged before is
///   the only evidence of that worth having, and it needs no settings
///   screen and no configuration.
///
/// Tags are stored as a JSON list in one column, so these match with
/// `LIKE` over the exact prefixed tag. That is a table scan; at catalog
/// scale (hundreds of rows, not millions) it costs well under the search
/// budget in §7.4, and the alternative — a join table — would be real
/// schema for a query that runs when a screen opens.
class CuisineDao {
  CuisineDao(this._db);

  final NourishlyDatabase _db;

  /// Matches one exact tag inside the JSON list, quotes included, so
  /// `cuisine:tamil` cannot also match a hypothetical `cuisine:tamilnadu`.
  static String _tagPattern(String tag) => '%"$tag"%';

  /// Every cuisine present in the catalog, most foods first.
  ///
  /// Empty is a normal answer, not a failure: a seed built before tags
  /// existed carries none, and a screen that offers browsing must simply
  /// not offer it rather than showing an empty shelf.
  Future<List<CuisineCount>> cuisinesInCatalog() async {
    final rows = await _db
        .customSelect(
          '''
          SELECT cuisine_tags AS tags, COUNT(*) AS n
          FROM food_items
          WHERE deleted_at IS NULL
            AND cuisine_tags LIKE ?
            AND provenance_source != 'usda_fdc_component'
          GROUP BY cuisine_tags
          ''',
          variables: [Variable.withString('%"$cuisineTagPrefix%')],
          readsFrom: {_db.foodItems},
        )
        .get();

    // The group is by the whole tag list, so ["cuisine:tamil","course:rice"]
    // and ["cuisine:tamil","course:sweet"] arrive separately and are added
    // together here.
    final counts = <String, int>{};
    for (final row in rows) {
      final cuisine = _cuisineOf(row.read<String>('tags'));
      if (cuisine == null) continue;
      counts[cuisine] = (counts[cuisine] ?? 0) + row.read<int>('n');
    }

    final ordered = counts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });
    return [for (final entry in ordered) CuisineCount(entry.key, entry.value)];
  }

  /// The foods tagged [cuisine], by name.
  ///
  /// Component-only rows are excluded for the same reason they are kept
  /// out of the search index: a raw USDA description with no serving size
  /// is a provenance trail, not something anyone browses to.
  Future<List<FoodItem>> foodsInCuisine(String cuisine, {int limit = 200}) {
    return (_db.select(_db.foodItems)
          ..where(
            (f) =>
                f.deletedAt.isNull() &
                f.cuisineTags.like(_tagPattern('$cuisineTagPrefix$cuisine')) &
                f.provenanceSource.equals('usda_fdc_component').not(),
          )
          ..orderBy([(f) => OrderingTerm.asc(f.canonicalName)])
          ..limit(limit))
        .get();
  }

  /// The cuisines this profile actually logs, most-logged first.
  ///
  /// [days] bounds it to recent eating so the ranking follows a household
  /// that changes what it cooks, rather than being fixed by whatever was
  /// logged in the first month.
  ///
  /// [minEntries] is the honesty gate, and it is the whole reason this is
  /// not just "order by count": one logged pasta is not evidence that this
  /// is a pasta household, and letting it reorder every search would make
  /// the app feel arbitrary rather than observant.
  Future<List<String>> frequentCuisines(
    String ownerId, {
    required DateTime now,
    int days = 60,
    int minEntries = 3,
  }) async {
    final since = now.subtract(Duration(days: days));
    final rows = await _db
        .customSelect(
          '''
          SELECT f.cuisine_tags AS tags, COUNT(*) AS n
          FROM food_log_entries e
          JOIN food_items f ON f.id = e.food_id
          WHERE e.owner_id = ?
            AND e.deleted_at IS NULL
            AND e.log_date >= ?
            AND f.cuisine_tags LIKE ?
          GROUP BY f.cuisine_tags
          ''',
          variables: [
            Variable.withString(ownerId),
            Variable.withDateTime(since),
            Variable.withString('%"$cuisineTagPrefix%'),
          ],
          readsFrom: {_db.foodLogEntries, _db.foodItems},
        )
        .get();

    final counts = <String, int>{};
    for (final row in rows) {
      final cuisine = _cuisineOf(row.read<String>('tags'));
      if (cuisine == null) continue;
      counts[cuisine] = (counts[cuisine] ?? 0) + row.read<int>('n');
    }

    final ordered = counts.entries.where((e) => e.value >= minEntries).toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });
    return [for (final entry in ordered) entry.key];
  }

  /// How the log divides by cuisine over a date range — what this
  /// household actually ate, rather than what it meant to.
  ///
  /// Entries whose food carries no cuisine are left out of the counts
  /// entirely rather than bucketed as "other": a share is only meaningful
  /// against a known total, and [totalEntries] reports that separately so
  /// a caller can say how much of the period the mix covers.
  Future<({List<CuisineCount> byCuisine, int totalEntries})> cuisineMix(
    String ownerId, {
    required DateTime from,
    required DateTime to,
  }) async {
    final rows = await _db
        .customSelect(
          '''
          SELECT f.cuisine_tags AS tags, COUNT(*) AS n
          FROM food_log_entries e
          JOIN food_items f ON f.id = e.food_id
          WHERE e.owner_id = ?
            AND e.deleted_at IS NULL
            AND e.log_date >= ?
            AND e.log_date <= ?
          GROUP BY f.cuisine_tags
          ''',
          variables: [
            Variable.withString(ownerId),
            Variable.withDateTime(from),
            Variable.withDateTime(to),
          ],
          readsFrom: {_db.foodLogEntries, _db.foodItems},
        )
        .get();

    final counts = <String, int>{};
    var total = 0;
    for (final row in rows) {
      final n = row.read<int>('n');
      total += n;
      final cuisine = _cuisineOf(row.read<String>('tags'));
      if (cuisine == null) continue;
      counts[cuisine] = (counts[cuisine] ?? 0) + n;
    }

    final ordered = counts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });
    return (
      byCuisine: [
        for (final entry in ordered) CuisineCount(entry.key, entry.value),
      ],
      totalEntries: total,
    );
  }

  /// The cuisine inside a raw `cuisine_tags` value, without building a
  /// [FoodItem] for it.
  static String? _cuisineOf(String tags) {
    final match = RegExp('"$cuisineTagPrefix([^"]+)"').firstMatch(tags);
    return match?.group(1);
  }
}
