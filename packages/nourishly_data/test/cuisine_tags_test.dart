import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly_data/nourishly_data.dart';

/// Reading the `cuisineTags` column back off a food.
///
/// The column has existed since Phase 1 and nothing wrote it until the
/// catalog pipeline started to, so every read has to cope with a food that
/// has no tags — including one imported from a seed built before tags
/// existed.
void main() {
  late NourishlyDatabase db;

  setUp(() => db = NourishlyDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<FoodItem> insert(String name, {String? tags}) async {
    const id = 'food-under-test';
    await db
        .into(db.foodItems)
        .insert(
          FoodItemsCompanion.insert(
            id: id,
            kind: 'recipe',
            canonicalName: name,
            cuisineTags: tags == null ? const Value.absent() : Value(tags),
            qualityTier: 'derived',
            provenanceSource: 'catalog_pipeline_recipe',
          ),
        );
    return (db.select(db.foodItems)..where((f) => f.id.equals(id))).getSingle();
  }

  test('reads cuisine and course out of the pipeline\'s JSON list', () async {
    final food = await insert(
      'Gujarati dal',
      tags: '["cuisine:gujarati","course:gravy"]',
    );
    expect(food.tags, ['cuisine:gujarati', 'course:gravy']);
    expect(food.cuisine, 'gujarati');
    expect(food.course, 'gravy');
  });

  test('a food with no tags reports none, not an empty string', () async {
    // The default column value, and what a pre-tags seed produces.
    final food = await insert('Something old');
    expect(food.tags, isEmpty);
    expect(food.cuisine, isNull);
    expect(food.course, isNull);
  });

  test('a cuisine with no course still reports its cuisine', () async {
    // One heading in the catalog spans too many courses to label, so its
    // dishes carry a cuisine alone.
    final food = await insert(
      'Coconut chutney',
      tags: '["cuisine:pan-indian"]',
    );
    expect(food.cuisine, 'pan-indian');
    expect(food.course, isNull);
  });

  test('a course is never mistaken for a cuisine', () async {
    // Position is convention, not contract: the known-cuisine set is what
    // decides, so a row carrying only a course does not report it as one.
    final food = await insert('Odd one', tags: '["course:sweet"]');
    expect(food.cuisine, isNull);
    expect(food.course, 'sweet');
  });

  test('malformed JSON is empty, never an exception', () async {
    // This is display metadata on a food someone is trying to log. A
    // stray character in it must not fail a search.
    for (final broken in ['not json', '{"a":1}', '[1,2,3]', '']) {
      final food = await insert('Broken', tags: broken);
      expect(food.tags, isEmpty, reason: broken);
      expect(food.cuisine, isNull, reason: broken);
      await db.delete(db.foodItems).go();
    }
  });
}
