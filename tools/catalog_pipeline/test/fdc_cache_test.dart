import 'dart:convert';
import 'dart:io';

import 'package:catalog_pipeline/catalog_pipeline.dart';
import 'package:test/test.dart';

/// A scripted [FdcSource] standing in for the network, so the cache's
/// behaviour is tested without one — and so "how many times did this hit
/// FDC" is observable, which is the whole point of the cache.
class _FakeLive implements FdcSource {
  _FakeLive(this.foods);

  final Map<int, FdcFood> foods;
  final searches = <String>[];
  final details = <int>[];
  bool closed = false;

  @override
  Future<List<FdcFood>> search(
    String query, {
    int pageSize = 5,
    String? dataType = FdcClient.preferredDataTypes,
  }) async {
    searches.add(query);
    return foods.values.toList();
  }

  @override
  Future<FdcFood> getDetails(int fdcId) async {
    details.add(fdcId);
    final food = foods[fdcId];
    if (food == null) throw StateError('no such food $fdcId');
    return food;
  }

  @override
  void close() => closed = true;
}

FdcFood _food(int id, String description) => FdcFood(
  fdcId: id,
  description: description,
  dataType: 'SR Legacy',
  nutrients: const [
    FdcNutrientReading(name: 'Energy', unit: 'KCAL', amountPer100g: 342),
    FdcNutrientReading(name: 'Protein', unit: 'G', amountPer100g: 22.5),
  ],
);

void main() {
  late Directory temp;
  late FdcCache cache;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('fdc_cache_test');
    cache = FdcCache(temp);
  });

  tearDown(() => temp.deleteSync(recursive: true));

  group('FdcCache keys', () {
    test('a key never contains the query verbatim, let alone a URL', () {
      // The live request URL carries api_key. Hashing canonical *query
      // parameters* rather than the URL is what keeps a key out of a
      // filename, an index entry and a commit.
      final key = FdcCache.searchKey('toor dal', pageSize: 3, dataType: null);
      expect(key, matches(RegExp(r'^[0-9a-f]{40}$')));
      expect(key, isNot(contains('toor')));
    });

    test('case and surrounding whitespace do not make a new key', () {
      expect(
        FdcCache.searchKey('  Toor Dal ', pageSize: 3, dataType: 'A'),
        FdcCache.searchKey('toor dal', pageSize: 3, dataType: 'A'),
      );
    });

    test('pageSize and dataType are part of the identity', () {
      final base = FdcCache.searchKey('rice', pageSize: 3, dataType: 'A');
      expect(
        base,
        isNot(FdcCache.searchKey('rice', pageSize: 5, dataType: 'A')),
      );
      expect(
        base,
        isNot(FdcCache.searchKey('rice', pageSize: 3, dataType: 'B')),
      );
      expect(
        base,
        isNot(FdcCache.searchKey('rice', pageSize: 3, dataType: null)),
      );
    });
  });

  group('round trip', () {
    test('a trimmed food record reads back with its nutrients intact', () {
      cache.writeFood(_food(1001, 'Dal, toor, raw'));
      final read = cache.readFood(1001);
      expect(read, isNotNull);
      expect(read!.fdcId, 1001);
      expect(read.description, 'Dal, toor, raw');
      expect(read.dataType, 'SR Legacy');
      expect(read.nutrients, hasLength(2));
      expect(read.nutrients.first.name, 'Energy');
      expect(read.nutrients.first.amountPer100g, 342);
    });

    test('the record carries only the four fields the pipeline reads', () {
      cache.writeFood(_food(1001, 'Dal, toor, raw'));
      final json = jsonDecode(
        File('${temp.path}/food/1001.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      expect(
        json.keys,
        unorderedEquals(['fdcId', 'description', 'dataType', 'foodNutrients']),
      );
    });

    test('a miss is null, not an empty record', () {
      expect(cache.readFood(9999), isNull);
      expect(cache.readSearch('nope'), isNull);
    });
  });

  group('CachingFdcSource', () {
    test('only the best match is detailed, not every candidate', () async {
      // Detailing all three hits would treble the cost of the cold run
      // that populates the cache, to store foods nothing ever reads.
      final live = _FakeLive({
        1001: _food(1001, 'Toor dal'),
        1002: _food(1002, 'Toor dal, other'),
        1003: _food(1003, 'Toor dal, third'),
      });
      final source = CachingFdcSource(
        cache: cache,
        mode: FdcCacheMode.refreshMissing,
        live: live,
      );
      final foods = await source.search('toor dal', pageSize: 3);
      expect(live.details, [1001]);
      expect(foods.single.fdcId, 1001);
      expect(cache.readFood(1002), isNull);
    });

    test('an empty search is cached too, so it is asked only once', () async {
      final live = _FakeLive(const {});
      await CachingFdcSource(
        cache: cache,
        mode: FdcCacheMode.refreshMissing,
        live: live,
      ).search('unobtanium', pageSize: 3);

      final live2 = _FakeLive(const {});
      final second = CachingFdcSource(
        cache: cache,
        mode: FdcCacheMode.refreshMissing,
        live: live2,
      );
      expect(await second.search('unobtanium', pageSize: 3), isEmpty);
      expect(live2.searches, isEmpty, reason: 'the dead end was remembered');
    });

    test(
      'refreshMissing fetches once, then serves from disk forever',
      () async {
        final live = _FakeLive({1001: _food(1001, 'Toor dal')});
        final first = CachingFdcSource(
          cache: cache,
          mode: FdcCacheMode.refreshMissing,
          live: live,
        );
        await first.search('toor dal', pageSize: 3);
        expect(live.searches, ['toor dal']);
        expect(first.fetches, greaterThan(0));

        // A second source over the same directory — a later run — must not
        // touch the network at all.
        final live2 = _FakeLive({1001: _food(1001, 'Toor dal')});
        final second = CachingFdcSource(
          cache: cache,
          mode: FdcCacheMode.refreshMissing,
          live: live2,
        );
        final foods = await second.search('toor dal', pageSize: 3);
        expect(live2.searches, isEmpty, reason: 'should have been a cache hit');
        expect(live2.details, isEmpty);
        expect(second.fetches, 0);
        expect(foods.single.description, 'Toor dal');
      },
    );

    test('cacheOnly needs no live client and reports a miss by name', () async {
      final source = CachingFdcSource(
        cache: cache,
        mode: FdcCacheMode.cacheOnly,
      );
      await expectLater(
        source.search('mushroom', pageSize: 3),
        throwsA(
          isA<FdcCacheMiss>().having(
            (e) => e.what,
            'what',
            contains('mushroom'),
          ),
        ),
      );
    });

    test('cacheOnly serves what the cache has', () async {
      final live = _FakeLive({1001: _food(1001, 'Toor dal')});
      await CachingFdcSource(
        cache: cache,
        mode: FdcCacheMode.refreshMissing,
        live: live,
      ).search('toor dal', pageSize: 3);

      final offline = CachingFdcSource(
        cache: cache,
        mode: FdcCacheMode.cacheOnly,
      );
      final foods = await offline.search('toor dal', pageSize: 3);
      expect(foods.single.fdcId, 1001);
      expect(offline.hits, greaterThan(0));
    });

    test('refreshAll re-fetches even when the cache has the answer', () async {
      final live = _FakeLive({1001: _food(1001, 'Toor dal')});
      await CachingFdcSource(
        cache: cache,
        mode: FdcCacheMode.refreshMissing,
        live: live,
      ).search('toor dal', pageSize: 3);

      final live2 = _FakeLive({1001: _food(1001, 'Toor dal, revised')});
      await CachingFdcSource(
        cache: cache,
        mode: FdcCacheMode.refreshAll,
        live: live2,
      ).search('toor dal', pageSize: 3);
      expect(live2.searches, ['toor dal']);
      expect(cache.readFood(1001)!.description, 'Toor dal, revised');
    });

    test(
      'a search hit whose food record is missing is an error, not a miss',
      () async {
        // Silently treating this as "no match" would drop a dish from the
        // catalog for a reason nobody could see.
        cache.writeSearch(
          FdcCache.searchKey(
            'ghost',
            pageSize: 3,
            dataType: FdcClient.preferredDataTypes,
          ),
          label: 'ghost [${FdcClient.preferredDataTypes}]',
          fdcIds: [4242],
        );
        final source = CachingFdcSource(
          cache: cache,
          mode: FdcCacheMode.cacheOnly,
        );
        await expectLater(
          source.search('ghost', pageSize: 3),
          throwsA(isA<StateError>()),
        );
      },
    );

    test('index.json records what resolved to what, sorted', () async {
      final live = _FakeLive({1001: _food(1001, 'Toor dal')});
      final source = CachingFdcSource(
        cache: cache,
        mode: FdcCacheMode.refreshMissing,
        live: live,
      );
      await source.search('zucchini', pageSize: 3, dataType: null);
      await source.search('apple', pageSize: 3, dataType: null);
      source.writeIndex();

      final json = jsonDecode(
        File('${temp.path}/index.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final searches = json['searches'] as Map<String, dynamic>;
      expect(searches.keys.toList(), ['apple [*]', 'zucchini [*]']);
      expect((searches['apple [*]'] as Map)['fdcId'], 1001);
      expect((searches['apple [*]'] as Map)['description'], 'Toor dal');
    });

    test('closing closes the live client, and tolerates not having one', () {
      final live = _FakeLive(const {});
      CachingFdcSource(
        cache: cache,
        mode: FdcCacheMode.refreshMissing,
        live: live,
      ).close();
      expect(live.closed, isTrue);

      expect(
        () => CachingFdcSource(
          cache: cache,
          mode: FdcCacheMode.cacheOnly,
        ).close(),
        returnsNormally,
      );
    });
  });
}
