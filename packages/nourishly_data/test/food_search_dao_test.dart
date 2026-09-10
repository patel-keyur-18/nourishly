import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly_data/nourishly_data.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

Future<String> _insertFood(
  NourishlyDatabase db, {
  required String name,
  String kind = 'ingredient',
}) async {
  final id = _uuid.v7();
  await db
      .into(db.foodItems)
      .insert(
        FoodItemsCompanion.insert(
          id: id,
          kind: kind,
          canonicalName: name,
          qualityTier: 'verified',
          provenanceSource: 'test',
        ),
      );
  return id;
}

void main() {
  group('FoodSearchDao', () {
    late NourishlyDatabase db;
    late FoodSearchDao dao;

    setUp(() {
      db = NourishlyDatabase.forTesting();
      dao = FoodSearchDao(db);
    });
    tearDown(() => db.close());

    test('matches a food by its canonical name', () async {
      final id = await _insertFood(db, name: 'Paneer');
      await dao.indexFood(
        foodId: id,
        canonicalName: 'Paneer',
        altNames: const [],
      );

      expect(await dao.matchingFoodIds('paneer'), [id]);
    });

    test('an alt-name spelling finds the same food as the canonical name (panir/paneer)', () async {
      // The exact worked example from §22.5's FoodAltName docs.
      final id = await _insertFood(db, name: 'Paneer');
      await dao.indexFood(
        foodId: id,
        canonicalName: 'Paneer',
        altNames: const ['panir', 'cottage cheese'],
      );

      expect(await dao.matchingFoodIds('panir'), [id]);
      expect(await dao.matchingFoodIds('paneer'), [id]);
      expect(await dao.matchingFoodIds('cottage cheese'), [id]);
    });

    test(
      'a food matching on two name variants is only returned once',
      () async {
        final id = await _insertFood(db, name: 'Rice, white, cooked');
        await dao.indexFood(
          foodId: id,
          canonicalName: 'Rice, white, cooked',
          altNames: const ['chawal', 'sadam', 'anna', 'bhaat'],
        );

        // "rice" only matches the canonical name here, but re-indexing under
        // an overlapping alt name must still dedupe to one result.
        await dao.indexFood(
          foodId: id,
          canonicalName: 'rice extra variant',
          altNames: const [],
        );

        final results = await dao.matchingFoodIds('rice');
        expect(results, [id]);
      },
    );

    test('an unmatched query returns no results, not an error', () async {
      await _insertFood(db, name: 'Paneer');
      expect(await dao.matchingFoodIds('nonexistent food xyz'), isEmpty);
    });

    test('an empty query returns no results without hitting fts5', () async {
      expect(await dao.matchingFoodIds(''), isEmpty);
      expect(await dao.matchingFoodIds('   '), isEmpty);
    });

    test(
      'removeFromIndex makes a previously-matching food unfindable',
      () async {
        final id = await _insertFood(db, name: 'Paneer');
        await dao.indexFood(
          foodId: id,
          canonicalName: 'Paneer',
          altNames: const [],
        );
        expect(await dao.matchingFoodIds('paneer'), [id]);

        await dao.removeFromIndex(id);
        expect(await dao.matchingFoodIds('paneer'), isEmpty);
      },
    );

    test(
      'search() hydrates to live FoodItem rows and excludes soft-deleted foods',
      () async {
        final keptId = await _insertFood(db, name: 'Paneer');
        final deletedId = await _insertFood(db, name: 'Paneer, deprecated');
        await dao.indexFood(
          foodId: keptId,
          canonicalName: 'Paneer',
          altNames: const [],
        );
        await dao.indexFood(
          foodId: deletedId,
          canonicalName: 'Paneer, deprecated',
          altNames: const [],
        );
        await (db.update(db.foodItems)..where((f) => f.id.equals(deletedId)))
            .write(FoodItemsCompanion(deletedAt: Value(DateTime.now())));

        final results = await dao.search('paneer');
        expect(results.map((f) => f.id), [keptId]);
        expect(results.single.canonicalName, 'Paneer');
      },
    );

    test('limit caps the number of results', () async {
      for (var i = 0; i < 5; i++) {
        final id = await _insertFood(db, name: 'Dal variant $i');
        await dao.indexFood(
          foodId: id,
          canonicalName: 'Dal variant $i',
          altNames: const [],
        );
      }

      expect(await dao.matchingFoodIds('dal', limit: 3), hasLength(3));
    });
  });
}
