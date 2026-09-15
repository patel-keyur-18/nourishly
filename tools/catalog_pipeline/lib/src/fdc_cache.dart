// An on-disk cache of the FoodData Central responses the catalog seed is
// built from, committed to the repository alongside the catalog itself.
//
// The obvious benefit is speed: adding a handful of rows costs a handful
// of lookups instead of re-fetching the whole catalog. The benefit that
// actually matters is reproducibility. Without this, the seed is not
// reproducible from the repository — it is reproducible from the
// repository *plus whatever FDC's search ranks today*. FDC re-ranks, and
// a rebuild a year from now can silently resolve "Toor dal" to a
// different food with nobody the wiser. A cached search result freezes
// that match as a decision somebody reviewed, and a `--refresh-all` run
// turns a USDA-side change into a diff you accept rather than one that
// happens to you.
//
// Redistributing the responses is fine: FDC is US Government public
// domain, the same basis the scope doc §0.7 already relies on to make
// this repository public.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'fdc_models.dart';
import 'fdc_source.dart';

/// How a [CachingFdcSource] is allowed to reach the network.
enum FdcCacheMode {
  /// Never touch the network. A miss throws [FdcCacheMiss] naming the
  /// query, so a gap is reported rather than mistaken for "no match".
  /// The default for CI and for any environment without an API key.
  cacheOnly,

  /// Serve hits from disk, fetch only what is missing. The normal run
  /// after adding rows.
  refreshMissing,

  /// Re-fetch everything and overwrite the cache. A deliberate USDA data
  /// refresh; the diff is the review.
  refreshAll,
}

/// Thrown when [FdcCacheMode.cacheOnly] needs something the cache has not
/// One search hit: the id, and the description FDC returned with it.
///
/// The description is the whole point — it is what lets the caller decide
/// whether a candidate is even the right food before spending a details
/// call on it.
class FdcCandidate {
  const FdcCandidate({required this.fdcId, required this.description});

  final int fdcId;
  final String description;
}

/// got. Carries the human description of the request so the operator
/// knows exactly what a `--refresh-missing` run would fetch.
class FdcCacheMiss implements Exception {
  FdcCacheMiss(this.what);

  final String what;

  @override
  String toString() =>
      'FdcCacheMiss: $what is not in the FDC cache. Re-run with '
      '--refresh-missing (needs FDC_API_KEY) to fetch it.';
}

/// The committed cache directory, laid out as:
///
/// ```
/// fdc_cache/
///   index.json          query -> fdcId, for review without opening files
///   search/<sha1>.json  the id list one search returned
///   food/<fdcId>.json   the trimmed detail record
/// ```
///
/// `index.json` exists so a reviewer can see what resolved to what in one
/// file rather than opening two hundred. It is written sorted, so its diff
/// is stable between runs.
class FdcCache {
  FdcCache(this.directory);

  /// The cache rooted at this package's own `fdc_cache/`, resolved
  /// relative to the repository root the CLI entry points run from.
  factory FdcCache.defaultLocation() =>
      FdcCache(Directory('tools/catalog_pipeline/fdc_cache'));

  final Directory directory;

  Directory get _searchDir => Directory('${directory.path}/search');
  Directory get _foodDir => Directory('${directory.path}/food');
  File get _indexFile => File('${directory.path}/index.json');

  /// The cache key for one search.
  ///
  /// Built from the query parameters that affect the result and **never
  /// from the request URL**, because the URL carries `api_key`. A key must
  /// not be able to reach a filename, an index entry or a commit.
  ///
  /// [dataType] is required rather than defaulted: a default here would
  /// have to agree with [CachingFdcSource.search]'s own default forever,
  /// and when they drift the only symptom is a cache that silently never
  /// hits.
  static String searchKey(
    String query, {
    required int pageSize,
    required String? dataType,
  }) {
    final canonical = jsonEncode({
      'query': query.toLowerCase().trim(),
      'pageSize': pageSize,
      'dataType': dataType ?? '*',
    });
    return sha1.convert(utf8.encode(canonical)).toString();
  }

  /// A one-line, human-readable label for the same request, used in
  /// `index.json` and in [FdcCacheMiss] messages.
  static String searchLabel(String query, {required String? dataType}) =>
      '${query.toLowerCase().trim()} [${dataType ?? '*'}]';

  /// Every candidate a search returned, id and description, in FDC's own
  /// ranking order. Null when the search is not cached.
  ///
  /// Descriptions are stored because the caller sieves on them
  /// ([describesSameFood]) before deciding which candidate is worth a
  /// details call. They arrive free in the search response, so keeping
  /// them costs one line of JSON and saves the run from being stuck with
  /// whatever FDC ranked first.
  ///
  /// An entry written before descriptions were kept holds ids only, and
  /// is read through the food records instead — the older format always
  /// detailed the one candidate it stored, so its description is already
  /// on disk. That keeps a committed cache of several hundred searches
  /// valid across the format change rather than re-asking FDC every
  /// question it has already answered.
  List<FdcCandidate>? readSearch(String key) {
    final file = File('${_searchDir.path}/$key.json');
    if (!file.existsSync()) return null;
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

    if (json['candidates'] case final List candidates) {
      return [
        for (final c in candidates.cast<Map<String, dynamic>>())
          FdcCandidate(
            fdcId: c['fdcId'] as int,
            description: c['description'] as String,
          ),
      ];
    }

    final legacyIds = (json['fdcIds'] as List?)?.cast<int>();
    if (legacyIds == null) return null;
    final recovered = <FdcCandidate>[];
    for (final id in legacyIds) {
      final food = readFood(id);
      // Its food record is the only place the description survives. Gone
      // means the entry cannot be sieved, and a miss is the honest answer.
      if (food == null) return null;
      recovered.add(FdcCandidate(fdcId: id, description: food.description));
    }
    return recovered;
  }

  void writeSearch(
    String key, {
    required String label,
    required List<FdcCandidate> candidates,
  }) {
    _searchDir.createSync(recursive: true);
    File('${_searchDir.path}/$key.json').writeAsStringSync(
      _encode({
        'query': label,
        'candidates': [
          for (final c in candidates)
            {'fdcId': c.fdcId, 'description': c.description},
        ],
      }),
    );
  }

  FdcFood? readFood(int fdcId) {
    final file = File('${_foodDir.path}/$fdcId.json');
    if (!file.existsSync()) return null;
    return FdcFood.fromJson(
      jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
    );
  }

  void writeFood(FdcFood food) {
    _foodDir.createSync(recursive: true);
    File('${_foodDir.path}/${food.fdcId}.json')
        .writeAsStringSync(_encode(food.toJson()));
  }

  /// Rewrites `index.json` from [resolutions] (label -> fdcId + its FDC
  /// description), sorted by label so the diff is stable.
  void writeIndex(Map<String, ({int fdcId, String description})> resolutions) {
    directory.createSync(recursive: true);
    final keys = resolutions.keys.toList()..sort();
    _indexFile.writeAsStringSync(
      _encode({
        'note':
            'Generated by fetch_catalog.dart. One line per FDC search this '
            'catalog depends on, so a reviewer can see what resolved to '
            'what without opening the per-food records.',
        'searches': {
          for (final key in keys)
            key: {
              'fdcId': resolutions[key]!.fdcId,
              'description': resolutions[key]!.description,
            },
        },
      }),
    );
  }

  static String _encode(Object? value) =>
      '${const JsonEncoder.withIndent('  ').convert(value)}\n';
}

/// An [FdcSource] that reads the committed cache first and, depending on
/// [mode], falls back to [live] for what it has not got.
///
/// Every response it fetches is written back, so one full run populates
/// the cache for every run after it — including runs with no network and
/// no API key at all, which is what lets the catalog be edited and
/// validated offline.
class CachingFdcSource implements FdcSource {
  CachingFdcSource({required this.cache, required this.mode, this.live})
    : assert(
        mode == FdcCacheMode.cacheOnly || live != null,
        'A mode that may fetch needs a live client to fetch with.',
      );

  final FdcCache cache;
  final FdcCacheMode mode;
  final FdcSource? live;

  /// label -> what it resolved to, accumulated so `index.json` can be
  /// rewritten at the end of a run. Only searches that produced a hit are
  /// recorded; an empty result is not a resolution.
  final resolutions = <String, ({int fdcId, String description})>{};

  /// Spacing between consecutive **live** requests, to stay well inside
  /// FoodData Central's rate limit.
  ///
  /// It lives here rather than in the caller because only this class
  /// knows whether a call reached the network. `fetch_catalog` used to
  /// sleep after every ingredient it resolved, cached or not, which on a
  /// warm run was 8,879 sleeps for zero requests — around twenty minutes
  /// of a twenty-five minute run spent waiting on nothing.
  static const _spacing = Duration(milliseconds: 150);

  DateTime? _lastRequest;

  Future<void> _throttle() async {
    final last = _lastRequest;
    if (last != null) {
      final since = DateTime.now().difference(last);
      if (since < _spacing) await Future<void>.delayed(_spacing - since);
    }
    _lastRequest = DateTime.now();
  }

  int _hits = 0;
  int _fetches = 0;

  int get hits => _hits;
  int get fetches => _fetches;

  @override
  Future<List<FdcFood>> search(
    String query, {
    int pageSize = 5,
    String? dataType = FdcClientDataTypes.preferred,
  }) async {
    final key = FdcCache.searchKey(
      query,
      pageSize: pageSize,
      dataType: dataType,
    );
    final label = FdcCache.searchLabel(query, dataType: dataType);

    if (mode != FdcCacheMode.refreshAll) {
      final cached = cache.readSearch(key);
      if (cached != null) {
        _hits++;
        // The ids are the cached answer; their details are cached under
        // their own ids. A search hit whose food records are missing is a
        // corrupt cache, not a miss to paper over.
        final foods = [
          for (final c in cached)
            cache.readFood(c.fdcId) ??
                FdcFood(
                  fdcId: c.fdcId,
                  description: c.description,
                  dataType: 'unknown',
                  nutrients: const [],
                ),
        ];
        _record(label, foods);
        return foods;
      }
    }

    if (mode == FdcCacheMode.cacheOnly) {
      throw FdcCacheMiss('search "$label"');
    }

    await _throttle();
    _fetches++;
    final foods = await live!.search(
      query,
      pageSize: pageSize,
      dataType: dataType,
    );
    if (foods.isEmpty) {
      // A search that found nothing is still an answer, and caching it is
      // what stops every later run re-asking FDC the same dead question.
      cache.writeSearch(key, label: label, candidates: const []);
      return const [];
    }

    // Every candidate is kept; none is detailed here.
    //
    // This used to materialise `foods.first` and discard the rest, on the
    // reasoning that `fetch_catalog` took the first hit anyway. It no
    // longer does: a candidate that names a different food, or carries no
    // proximates, is refused and the next one is tried. Storing only the
    // winner left the run unable to see past whatever FDC happened to
    // rank first — which is how `Oil, peanut` (90 nutrients, no macros)
    // became the household's cooking fat.
    //
    // The cost of keeping them is a line of JSON each. Descriptions come
    // back with the search, and the details call still happens exactly
    // once, for the candidate the caller actually accepts.
    cache.writeSearch(
      key,
      label: label,
      candidates: [
        for (final f in foods)
          FdcCandidate(fdcId: f.fdcId, description: f.description),
      ],
    );
    _record(label, foods);
    return foods;
  }

  @override
  Future<FdcFood> getDetails(int fdcId) async {
    if (mode != FdcCacheMode.refreshAll) {
      final cached = cache.readFood(fdcId);
      if (cached != null) {
        _hits++;
        return cached;
      }
    }

    if (mode == FdcCacheMode.cacheOnly) {
      throw FdcCacheMiss('food details for fdcId $fdcId');
    }

    await _throttle();
    _fetches++;
    final food = await live!.getDetails(fdcId);
    cache.writeFood(food);
    return food;
  }

  void _record(String label, List<FdcFood> foods) {
    if (foods.isEmpty) return;
    resolutions[label] = (
      fdcId: foods.first.fdcId,
      description: foods.first.description,
    );
  }

  /// Rewrites `index.json` from what this run resolved. Call once, at the
  /// end of a full run — a partial run would drop entries it never
  /// consulted.
  void writeIndex() => cache.writeIndex(resolutions);

  @override
  void close() => live?.close();
}

/// The `dataType` filter values, lifted out of [FdcClient] so
/// [CachingFdcSource] can default to the same one without importing the
/// live client.
abstract final class FdcClientDataTypes {
  /// Measured/lab-analysed data (not survey estimates or branded
  /// products) — matching the catalog's preferred `quality_tier` (§19.11).
  static const preferred = 'Foundation,SR Legacy';
}
