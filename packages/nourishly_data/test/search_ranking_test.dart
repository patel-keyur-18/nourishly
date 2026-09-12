import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly_data/nourishly_data.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// How search orders what it found.
///
/// Three stable partitions over fts5 relevance, applied weakest first so
/// the strongest ends up outermost: cuisine affinity, then foods this
/// profile owns, then dietary preference. None of them filters — a search
/// that silently omits what you typed is the dead end §27.4 rules out.
void main() {
  late NourishlyDatabase db;
  late FoodSearchDao dao;

  setUp(() async {
    db = NourishlyDatabase.forTesting();
    dao = FoodSearchDao(db);
  });

  tearDown(() => db.close());

  Future<String> food(
    String name, {
    String? tags,
    String? owner,
    String? dietClass,
  }) async {
    final id = _uuid.v7();
    await db
        .into(db.foodItems)
        .insert(
          FoodItemsCompanion.insert(
            id: id,
            ownerId: Value(owner),
            kind: 'recipe',
            canonicalName: name,
            cuisineTags: tags == null ? const Value.absent() : Value(tags),
            qualityTier: 'derived',
            provenanceSource: 'catalog_pipeline_recipe',
            dietClass: Value(dietClass),
          ),
        );
    await dao.indexFood(foodId: id, canonicalName: name, altNames: const []);
    return id;
  }

  test('without an affinity, relevance is left exactly as it was', () async {
    // A new profile, or a seed built before cuisine tags existed.
    await food('Dal makhani', tags: '["cuisine:north-indian"]');
    await food('Dal dhokli', tags: '["cuisine:gujarati"]');

    final plain = await dao.search('dal');
    final empty = await dao.search('dal', preferredCuisines: const {});
    expect(
      empty.map((f) => f.canonicalName),
      plain.map((f) => f.canonicalName),
    );
  });

  test('the cuisine this household eats comes first', () async {
    // Typing "dal" in a Gujarati kitchen should reach Gujarati dal before
    // dal makhani, without anyone configuring that.
    await food('Dal makhani', tags: '["cuisine:north-indian"]');
    await food('Dal dhokli', tags: '["cuisine:gujarati"]');
    await food('Dal tadka', tags: '["cuisine:north-indian"]');

    final results = await dao.search(
      'dal',
      preferredCuisines: const {'gujarati'},
    );
    expect(results.first.canonicalName, 'Dal dhokli');
    expect(results, hasLength(3), reason: 'promoted, never filtered');
  });

  test('promotion is stable — the rest keep their order', () async {
    await food('Dal makhani', tags: '["cuisine:north-indian"]');
    await food('Dal tadka', tags: '["cuisine:north-indian"]');
    await food('Dal dhokli', tags: '["cuisine:gujarati"]');

    final before = await dao.search('dal');
    final after = await dao.search(
      'dal',
      preferredCuisines: const {'gujarati'},
    );
    final demoted = after
        .where((f) => f.cuisine != 'gujarati')
        .map((f) => f.canonicalName);
    final originalOrder = before
        .where((f) => f.cuisine != 'gujarati')
        .map((f) => f.canonicalName);
    expect(demoted, originalOrder);
  });

  test('your own version of a dish outranks the catalog\'s', () async {
    // If she has recorded how this kitchen cooks it, that is the one she
    // cooks — scrolling past the catalog's estimate every time would be
    // the app ignoring what it already knows.
    await food('Bataka nu shaak', tags: '["cuisine:gujarati"]');
    await food('Bataka nu shaak (our version)', owner: 'owner-1');

    final results = await dao.search('bataka');
    expect(results.first.canonicalName, 'Bataka nu shaak (our version)');
  });

  test('yours outranks a preferred cuisine', () async {
    // Applied later, so it wins: what you actually cook beats what you
    // generally eat.
    await food('Dal dhokli', tags: '["cuisine:gujarati"]');
    await food('Dal, mine', owner: 'owner-1');

    final results = await dao.search(
      'dal',
      preferredCuisines: const {'gujarati'},
    );
    expect(results.first.canonicalName, 'Dal, mine');
  });

  test('dietary preference still decides before either', () async {
    // FR-U-16 is the strongest rule, so it is applied last and ends up
    // outermost.
    await food('Dal, mine', owner: 'owner-1', dietClass: 'non_vegetarian');
    await food('Dal dhokli', tags: '["cuisine:gujarati"]', dietClass: 'vegan');

    final results = await dao.search(
      'dal',
      preference: DietaryPreference.vegan,
      preferredCuisines: const {'gujarati'},
    );
    expect(results.first.canonicalName, 'Dal dhokli');
    expect(results, hasLength(2), reason: 'reordered, never hidden');
  });
}
