import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly_data/nourishly_data.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Browsing and ranking by cuisine.
///
/// Both exist because the catalog outgrew the point where a person can
/// remember what is in it: 441 foods across seven cuisines makes "search
/// for a food" assume knowledge the user does not have, and makes "dal"
/// ambiguous in a way it never used to be.
void main() {
  late NourishlyDatabase db;
  late CuisineDao dao;
  late String ownerId;
  final now = DateTime(2026, 9, 12);

  setUp(() async {
    db = NourishlyDatabase.forTesting();
    dao = CuisineDao(db);
    ownerId = await ensureDefaultOwner(db);
    await db
        .into(db.mealSlots)
        .insert(
          MealSlotsCompanion.insert(
            id: 'slot-lunch',
            key: 'lunch',
            displayName: 'Lunch',
            sortOrder: 0,
          ),
        );
  });

  tearDown(() => db.close());

  Future<String> food(
    String name, {
    String? tags,
    String kind = 'recipe',
    String provenance = 'catalog_pipeline_recipe',
    String? owner,
  }) async {
    final id = _uuid.v7();
    await db
        .into(db.foodItems)
        .insert(
          FoodItemsCompanion.insert(
            id: id,
            ownerId: Value(owner),
            kind: kind,
            canonicalName: name,
            cuisineTags: tags == null ? const Value.absent() : Value(tags),
            qualityTier: 'derived',
            provenanceSource: provenance,
          ),
        );
    return id;
  }

  Future<void> log(String foodId, {required DateTime on, int times = 1}) async {
    for (var i = 0; i < times; i++) {
      await db
          .into(db.foodLogEntries)
          .insert(
            FoodLogEntriesCompanion.insert(
              id: _uuid.v7(),
              ownerId: ownerId,
              logDate: on,
              mealSlotId: 'slot-lunch',
              foodId: foodId,
              foodRevision: 1,
              quantity: 1,
              gramsConsumed: 150,
              loggedAt: on,
              source: 'manual',
            ),
          );
    }
  }

  group('browsing the catalog', () {
    test('lists the cuisines present, biggest first', () async {
      await food('Gujarati dal', tags: '["cuisine:gujarati","course:gravy"]');
      await food('Kadhi', tags: '["cuisine:gujarati","course:gravy"]');
      await food('Thepla', tags: '["cuisine:gujarati","course:bread"]');
      await food('Idli', tags: '["cuisine:tamil","course:tiffin"]');

      final cuisines = await dao.cuisinesInCatalog();
      expect(cuisines.map((c) => c.cuisine), ['gujarati', 'tamil']);
      // Counted across different course tags, not per tag list.
      expect(cuisines.first.count, 3);
    });

    test(
      'a catalog with no tags offers nothing, rather than an empty shelf',
      () async {
        // What a seed built before tags existed looks like. The screen must
        // be able to tell "no cuisines" from "a cuisine with no foods".
        await food('Something old');
        expect(await dao.cuisinesInCatalog(), isEmpty);
      },
    );

    test('component-only rows are never browsable', () async {
      // A raw USDA description with no serving size is a provenance
      // trail, kept out of search for the same reason.
      await food(
        'Pigeon peas, mature seeds, raw',
        tags: '["cuisine:pan-indian","course:ingredient"]',
        kind: 'ingredient',
        provenance: 'usda_fdc_component',
      );
      expect(await dao.cuisinesInCatalog(), isEmpty);
      expect(await dao.foodsInCuisine('pan-indian'), isEmpty);
    });

    test('lists a cuisine\'s foods by name', () async {
      await food('Thepla', tags: '["cuisine:gujarati","course:bread"]');
      await food('Dhokla', tags: '["cuisine:gujarati","course:snack"]');
      await food('Idli', tags: '["cuisine:tamil","course:tiffin"]');

      final foods = await dao.foodsInCuisine('gujarati');
      expect(foods.map((f) => f.canonicalName), ['Dhokla', 'Thepla']);
    });

    test('one tag never matches a longer one that starts the same', () async {
      await food('Idli', tags: '["cuisine:tamil","course:tiffin"]');
      await food('Made up', tags: '["cuisine:tamilnadu"]');
      expect(await dao.foodsInCuisine('tamil'), hasLength(1));
    });
  });

  group('what this household actually eats', () {
    test('ranks the cuisines it logs, most first', () async {
      final dal = await food('Dal', tags: '["cuisine:gujarati"]');
      final idli = await food('Idli', tags: '["cuisine:tamil"]');
      await log(dal, on: now, times: 6);
      await log(idli, on: now, times: 3);

      expect(await dao.frequentCuisines(ownerId, now: now), [
        'gujarati',
        'tamil',
      ]);
    });

    test('one meal is not evidence of a habit', () async {
      // The honesty gate. Letting a single logged pasta reorder every
      // search would make the app feel arbitrary rather than observant.
      final pasta = await food('Pasta', tags: '["cuisine:italian"]');
      await log(pasta, on: now, times: 2);
      expect(await dao.frequentCuisines(ownerId, now: now), isEmpty);
    });

    test(
      'old eating stops counting, so the ranking can follow a change',
      () async {
        final dal = await food('Dal', tags: '["cuisine:gujarati"]');
        await log(dal, on: now.subtract(const Duration(days: 200)), times: 10);
        expect(await dao.frequentCuisines(ownerId, now: now), isEmpty);
      },
    );

    test('another profile\'s log does not rank this one', () async {
      final other = _uuid.v7();
      await db
          .into(db.users)
          .insert(
            UsersCompanion.insert(
              id: other,
              displayName: 'Someone',
              avatarColor: 'indigo',
            ),
          );
      final dal = await food('Dal', tags: '["cuisine:gujarati"]');
      for (var i = 0; i < 5; i++) {
        await db
            .into(db.foodLogEntries)
            .insert(
              FoodLogEntriesCompanion.insert(
                id: _uuid.v7(),
                ownerId: other,
                logDate: now,
                mealSlotId: 'slot-lunch',
                foodId: dal,
                foodRevision: 1,
                quantity: 1,
                gramsConsumed: 150,
                loggedAt: now,
                source: 'manual',
              ),
            );
      }
      expect(await dao.frequentCuisines(ownerId, now: now), isEmpty);
    });

    test('a deleted entry stops counting', () async {
      final dal = await food('Dal', tags: '["cuisine:gujarati"]');
      await log(dal, on: now, times: 5);
      await (db.update(db.foodLogEntries))
          .write(FoodLogEntriesCompanion(deletedAt: Value(now)));
      expect(await dao.frequentCuisines(ownerId, now: now), isEmpty);
    });
  });

  group('cuisine mix', () {
    test('divides a period by cuisine, biggest first', () async {
      final dal = await food('Dal', tags: '["cuisine:gujarati"]');
      final idli = await food('Idli', tags: '["cuisine:tamil"]');
      await log(dal, on: now, times: 7);
      await log(idli, on: now, times: 3);

      final mix = await dao.cuisineMix(
        ownerId,
        from: now.subtract(const Duration(days: 7)),
        to: now,
      );
      expect(mix.totalEntries, 10);
      expect(mix.byCuisine.map((c) => c.cuisine), ['gujarati', 'tamil']);
      expect(mix.byCuisine.first.count, 7);
    });

    test(
      'an untagged food counts toward the total but not toward a share',
      () async {
        // A share is only meaningful against a known total. Bucketing the
        // unknown as "other" would invent a cuisine nobody assigned.
        final dal = await food('Dal', tags: '["cuisine:gujarati"]');
        final mystery = await food('Something old');
        await log(dal, on: now, times: 4);
        await log(mystery, on: now, times: 6);

        final mix = await dao.cuisineMix(
          ownerId,
          from: now.subtract(const Duration(days: 7)),
          to: now,
        );
        expect(mix.totalEntries, 10, reason: 'the period had ten entries');
        expect(mix.byCuisine, hasLength(1));
        expect(mix.byCuisine.single.count, 4);
      },
    );
  });
}
