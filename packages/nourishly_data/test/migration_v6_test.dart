import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly_data/nourishly_data.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// v5 -> v6 adds `food_items.forked_from_food_id`.
///
/// The riskiest change in this work: a schema migration runs against a
/// database that already holds someone's food log, and there is no undo.
/// The column is nullable and additive, so there is nothing to backfill —
/// a recipe written before this simply has no parent, which is the truth
/// about it — but "nothing to backfill" is a claim worth testing rather
/// than asserting.
///
/// v5 is simulated by dropping the column from a fresh database, which is
/// exactly the shape a device upgrading from the previous release is in.
void main() {
  late NourishlyDatabase db;

  setUp(() => db = NourishlyDatabase.forTesting());
  tearDown(() => db.close());

  Future<void> insertRecipe(String id, String name) => db.customStatement(
    'INSERT INTO food_items (id, kind, canonical_name, quality_tier, '
    'provenance_source, cuisine_tags, revision, is_verified) '
    "VALUES (?, 'recipe', ?, 'derived', 'catalog_pipeline_recipe', '[]', 1, 0)",
    [id, name],
  );

  test('the upgrade adds the column and leaves existing rows intact', () async {
    // Put the database back into its v5 shape, with a row already in it.
    await db.customStatement(
      'ALTER TABLE food_items DROP COLUMN forked_from_food_id',
    );
    final id = _uuid.v7();
    await insertRecipe(id, 'A dish logged before the upgrade');

    await db.migration.onUpgrade(Migrator(db), 5, 6);

    final row = await (db.select(
      db.foodItems,
    )..where((f) => f.id.equals(id))).getSingle();
    expect(row.canonicalName, 'A dish logged before the upgrade');
    expect(
      row.forkedFromFoodId,
      isNull,
      reason: 'a recipe written before forking existed has no parent',
    );
  });

  test('a fork saved after the upgrade records its parent', () async {
    await db.customStatement(
      'ALTER TABLE food_items DROP COLUMN forked_from_food_id',
    );
    final parentId = _uuid.v7();
    await insertRecipe(parentId, 'Bataka nu shaak');

    await db.migration.onUpgrade(Migrator(db), 5, 6);

    final forkId = _uuid.v7();
    await db
        .into(db.foodItems)
        .insert(
          FoodItemsCompanion.insert(
            id: forkId,
            kind: 'recipe',
            canonicalName: 'Bataka nu shaak (our version)',
            qualityTier: 'user',
            provenanceSource: 'user',
            forkedFromFoodId: Value(parentId),
          ),
        );

    final row = await (db.select(
      db.foodItems,
    )..where((f) => f.id.equals(forkId))).getSingle();
    expect(row.forkedFromFoodId, parentId);
  });

  test('the database reports the new schema version', () {
    expect(db.schemaVersion, 6);
  });
}
