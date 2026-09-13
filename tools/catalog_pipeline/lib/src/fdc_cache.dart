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

  List<int>? readSearch(String key) {
    final file = File('${_searchDir.path}/$key.json');
    if (!file.existsSync()) return null;
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    return (json['fdcIds'] as List).cast<int>();
  }

  void writeSearch(
    String key, {
    required String label,
    required List<int> fdcIds,
  }) {
    _searchDir.createSync(recursive: true);
    File('${_searchDir.path}/$key.json')
        .writeAsStringSync(_encode({'query': label, 'fdcIds': fdcIds}));
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
        final foods = <FdcFood>[];
        for (final id in cached) {
          final food = cache.readFood(id);
          if (food == null) {
            throw StateError(
              'FDC cache is inconsistent: search "$label" resolved to '
              'fdcId $id, but food/$id.json is missing. Re-run with '
              '--refresh-all.',
            );
          }
          foods.add(food);
        }
        _record(label, foods);
        return foods;
      }
    }

    if (mode == FdcCacheMode.cacheOnly) {
      throw FdcCacheMiss('search "$label"');
    }

    _fetches++;
    final foods = await live!.search(
      query,
      pageSize: pageSize,
      dataType: dataType,
    );
    if (foods.isEmpty) {
      // A search that found nothing is still an answer, and caching it is
      // what stops every later run re-asking FDC the same dead question.
      cache.writeSearch(key, label: label, fdcIds: const []);
      return const [];
    }

    // Only the best match is materialised.
    //
    // Search results carry an abbreviated nutrient panel, so a usable
    // record has to come from the details endpoint — but detailing all
    // three hits would treble the cost of the one cold run that populates
    // this cache, to store two foods nothing reads. `fetch_catalog` takes
    // `candidates.first` and discards the rest, so that is what is kept.
    final best = await getDetails(foods.first.fdcId);
    cache.writeSearch(key, label: label, fdcIds: [best.fdcId]);
    _record(label, [best]);
    return [best];
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
