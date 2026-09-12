import 'package:drift/drift.dart';
import 'package:drift/extensions/fts5.dart';
import 'package:meta/meta.dart';

import '../cuisine_tags.dart';
import '../database.dart';
import '../diet_classifier.dart';

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
  /// [query] is raw user input, not fts5 syntax — see [matchExpression].
  Future<List<String>> matchingFoodIds(String query, {int limit = 20}) async {
    final ranked = await _matchingNames(query, limit: limit);
    return [for (final row in ranked) row.foodId];
  }

  /// The fts5 MATCH expression for raw user input, or null if there is
  /// nothing to search for.
  ///
  /// Two things happen here, and both are the difference between a search
  /// that works while you type and one that does not:
  ///
  /// * Every token gets a trailing `*`, so "pan" finds paneer (FR-F-01 asks
  ///   for prefix matching, and §27.4 asks for live results as the user
  ///   types — a whole-word-only match makes both impossible).
  /// * Every token is quoted. Splitting on non-alphanumerics means a token
  ///   can only ever be letters and digits, so quoting is enough to stop
  ///   `-`, `:`, `*`, `(` or a bare `OR` in what someone typed being read
  ///   as fts5 operators — which would otherwise throw mid-keystroke.
  ///
  /// fts5 ANDs adjacent terms, so "pan but" finds "paneer butter masala"
  /// and typing more words narrows rather than widens.
  @visibleForTesting
  static String? matchExpression(String query) {
    final tokens = query
        .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
        .where((token) => token.isNotEmpty);
    if (tokens.isEmpty) return null;
    return tokens.map((token) => '"$token"*').join(' ');
  }

  /// Matched index rows, best first and one per food.
  ///
  /// Ordering is bm25 (fts5's own relevance) re-ranked by how the name
  /// meets the query: an exact name wins, then a name that starts with
  /// what was typed, then a name with a word starting with it, then the
  /// rest. Without this "pan" puts "Bread, pan-fried" wherever bm25
  /// happens to leave it, above paneer.
  Future<List<_MatchedName>> _matchingNames(
    String query, {
    required int limit,
  }) async {
    final expression = matchExpression(query);
    if (expression == null) return const [];

    // Prefix matching on a short query can match a large slice of the
    // catalog, so the scan is bounded before it reaches Dart. The cap is
    // generous relative to [limit] because the re-rank below needs more
    // than [limit] rows to have anything to choose between, and because
    // one food can occupy several rows through its alt names.
    final rows =
        await (_db.select(_db.foodSearchIndex)
              ..where((t) => t.match(expression))
              ..orderBy([(t) => OrderingTerm(expression: t.rank)])
              ..limit(limit * 20))
            .get();

    final needle = query.trim().toLowerCase();
    final matches = <_MatchedName>[];
    for (var i = 0; i < rows.length; i++) {
      final name = rows[i].name.toLowerCase();
      final tier = switch (name) {
        _ when name == needle => 0,
        _ when name.startsWith(needle) => 1,
        _ when _hasWordStartingWith(name, needle) => 2,
        _ => 3,
      };
      matches.add(
        _MatchedName(foodId: rows[i].foodId, tier: tier, bm25Order: i),
      );
    }

    // Stable on bm25 order within a tier.
    matches.sort((a, b) {
      final byTier = a.tier.compareTo(b.tier);
      return byTier != 0 ? byTier : a.bm25Order.compareTo(b.bm25Order);
    });

    final seen = <String>{};
    final best = <_MatchedName>[];
    for (final match in matches) {
      if (best.length >= limit) break;
      if (seen.add(match.foodId)) best.add(match);
    }
    return best;
  }

  static bool _hasWordStartingWith(String name, String needle) {
    for (final word in name.split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))) {
      if (word.startsWith(needle)) return true;
    }
    return false;
  }

  /// [matchingFoodIds], hydrated to live (non-deleted) [FoodItem] rows and
  /// still in relevance order — what the search screen (§27.4) renders.
  ///
  /// [preference] reorders, it never filters (FR-U-16, §27.4): foods the
  /// stated preference eats come first, the rest keep their relevance
  /// order below them. Hiding a food would be the wrong call twice over —
  /// a household cooks for guests, and a search that silently omits what
  /// you typed is the dead end §27.4 rules out.
  ///
  /// [preferredCuisines] does the same for what this household actually
  /// eats: typing "dal" in a Gujarati kitchen should reach Gujarati dal
  /// before dal makhani. It comes from the log itself
  /// ([CuisineDao.frequentCuisines]), so it needs no settings screen and
  /// gets better with use. Empty — a new profile, or a seed built before
  /// cuisine tags existed — leaves the order exactly as it was.
  ///
  /// A food this profile owns outranks both. If she has recorded her own
  /// version of a dish, that is the one she cooks, and making her scroll
  /// past the catalog's estimate of it every time would be the app
  /// ignoring what it already knows.
  ///
  /// All three are **stable partitions, applied weakest first**, never
  /// sorts: relevance stays the ordering underneath, and two foods a rule
  /// treats alike must not swap places because of it.
  Future<List<FoodItem>> search(
    String query, {
    int limit = 20,
    DietaryPreference? preference,
    Set<String> preferredCuisines = const {},
  }) async {
    final ids = await matchingFoodIds(query, limit: limit);
    if (ids.isEmpty) return const [];

    final rows = await (_db.select(
      _db.foodItems,
    )..where((f) => f.id.isIn(ids) & f.deletedAt.isNull())).get();

    final byId = {for (final row in rows) row.id: row};
    var ordered = [for (final id in ids) ?byId[id]];

    if (preferredCuisines.isNotEmpty) {
      ordered = _promote(
        ordered,
        (food) => preferredCuisines.contains(food.cuisine),
      );
    }

    ordered = _promote(ordered, (food) => food.ownerId != null);

    if (preference != null && preference != DietaryPreference.none) {
      ordered = _promote(
        ordered,
        (food) => suitsPreference(preference, DietClass.fromId(food.dietClass)),
      );
    }

    return ordered;
  }

  /// Moves everything [wanted] accepts to the front, keeping the relative
  /// order of both groups.
  ///
  /// Applying several of these weakest-first leaves the strongest rule
  /// outermost, so diet preference still decides before cuisine does.
  static List<FoodItem> _promote(
    List<FoodItem> foods,
    bool Function(FoodItem) wanted,
  ) {
    final yes = <FoodItem>[];
    final no = <FoodItem>[];
    for (final food in foods) {
      (wanted(food) ? yes : no).add(food);
    }
    return [...yes, ...no];
  }
}

/// One matched index row, kept only long enough to re-rank it.
class _MatchedName {
  const _MatchedName({
    required this.foodId,
    required this.tier,
    required this.bm25Order,
  });

  final String foodId;

  /// 0 exact name, 1 name starts with the query, 2 a word in the name
  /// does, 3 matched only on a prefix inside the name.
  final int tier;

  /// Position in fts5's own relevance order, so the re-rank stays stable
  /// within a tier.
  final int bm25Order;
}
