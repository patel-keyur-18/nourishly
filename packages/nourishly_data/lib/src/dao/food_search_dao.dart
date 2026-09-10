import 'package:drift/drift.dart';
import 'package:drift/extensions/fts5.dart';

import '../database.dart';

/// Full-text search over food names (§27.4, NFR-P-03: offline, p95 <
/// 120ms).
///
/// This is the first DAO in `nourishly_data` (§13.3's Data layer arrives
/// with the feature that needs it — search is that feature). It wraps
/// the `food_search_index` FTS5 table from `tables/search.drift`; callers
/// never touch that table directly.
class FoodSearchDao {
  FoodSearchDao(this._db);

  final NourishlyDatabase _db;

  /// Indexes [canonicalName] and every entry in [altNames] against
  /// [foodId] — one row per name variant, so "panir", "paneer" and
  /// "पनीर" each match independently (§22.5 `FoodAltName`, §22.7).
  ///
  /// Call [removeFromIndex] first if re-indexing an existing food, since
  /// this is a standalone index rather than one kept in sync by SQLite
  /// triggers (see `search.drift`'s header comment for why).
  Future<void> indexFood({
    required String foodId,
    required String canonicalName,
    required Iterable<String> altNames,
  }) {
    return _db.batch((batch) {
      batch.insert(
        _db.foodSearchIndex,
        FoodSearchIndexCompanion.insert(foodId: foodId, name: canonicalName),
      );
      for (final name in altNames) {
        batch.insert(
          _db.foodSearchIndex,
          FoodSearchIndexCompanion.insert(foodId: foodId, name: name),
        );
      }
    });
  }

  /// Removes every indexed name variant for [foodId]. A no-op if it was
  /// never indexed.
  Future<void> removeFromIndex(String foodId) {
    return (_db.delete(
      _db.foodSearchIndex,
    )..where((t) => t.foodId.equals(foodId))).go();
  }

  /// Food ids matching [query], best match first, deduplicated across a
  /// food's multiple indexed name variants. At most [limit] results.
  ///
  /// [query] uses fts5 query syntax directly (§22.7) — the search screen
  /// is responsible for treating raw user input as a single term rather
  /// than passing it through unescaped once it needs prefix/boolean
  /// query support (Phase 2 follow-up).
  Future<List<String>> matchingFoodIds(String query, {int limit = 20}) async {
    if (query.trim().isEmpty) return const [];

    final rows =
        await (_db.select(_db.foodSearchIndex)
              ..where((t) => t.match(query))
              ..orderBy([(t) => OrderingTerm(expression: t.rank)]))
            .get();

    final seen = <String>{};
    final ids = <String>[];
    for (final row in rows) {
      if (ids.length >= limit) break;
      if (seen.add(row.foodId)) {
        ids.add(row.foodId);
      }
    }
    return ids;
  }

  /// [matchingFoodIds], hydrated to live (non-deleted) [FoodItem] rows and
  /// still in relevance order — what the search screen (§27.4) renders.
  Future<List<FoodItem>> search(String query, {int limit = 20}) async {
    final ids = await matchingFoodIds(query, limit: limit);
    if (ids.isEmpty) return const [];

    final rows = await (_db.select(
      _db.foodItems,
    )..where((f) => f.id.isIn(ids) & f.deletedAt.isNull())).get();

    final byId = {for (final row in rows) row.id: row};
    return [for (final id in ids) ?byId[id]];
  }
}
