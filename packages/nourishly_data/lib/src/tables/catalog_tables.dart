import 'package:drift/drift.dart';

import 'common.dart';

/// A definition of an edible thing — a type, not an event (§22.1, §22.5).
/// Catalog foods (`ownerId == null`) are server/pipeline-owned and
/// read-only on device (AP-2, I-5); user-created custom foods share the
/// same table so every consumer works identically for both (§22.5).
class FoodItems extends Table with Identifiable, SoftDeletable {
  /// Null for catalog foods; set for a profile's custom foods.
  TextColumn get ownerId =>
      text().nullable().customConstraint('REFERENCES users (id)')();

  /// `ingredient` | `dish` | `branded` | `recipe` | `user_custom`.
  TextColumn get kind => text()();
  TextColumn get canonicalName => text()();
  TextColumn get brand => text().nullable()();

  /// JSON-encoded list, e.g. `["gujarati", "tiffin"]`.
  TextColumn get cuisineTags => text().withDefault(const Constant('[]'))();

  /// `verified` | `derived` | `label` | `community` | `user`.
  TextColumn get qualityTier => text()();
  TextColumn get provenanceSource => text()();
  TextColumn get provenanceId => text().nullable()();
  IntColumn get revision => integer().withDefault(const Constant(1))();
  IntColumn get catalogVersion => integer().nullable().customConstraint(
    'REFERENCES catalog_versions (version)',
  )();
  RealColumn get densityGPerMl => real().nullable()();

  /// For `kind == 'recipe'` only — cooking yield applied when the pipeline
  /// sums ingredient nutrients (catalog spec §0.2).
  RealColumn get yieldFactor => real().nullable()();
  TextColumn get defaultServingId =>
      text().nullable().customConstraint('REFERENCES serving_sizes (id)')();
  BoolColumn get isVerified => boolean().withDefault(const Constant(false))();
}

/// Absence of a row means unknown — there is no null-amount row and no
/// zero-filling (AP-4, §22.5).
class FoodNutrientValues extends Table with Identifiable {
  TextColumn get foodId =>
      text().customConstraint('NOT NULL REFERENCES food_items (id)')();
  TextColumn get nutrientId =>
      text().customConstraint('NOT NULL REFERENCES nutrients (id)')();
  RealColumn get amountPer100g => real()();

  /// `measured` | `label` | `derived` | `estimated`.
  TextColumn get valueSource => text()();
  RealColumn get confidence => real().nullable()();
}

/// Every serving resolves to grams; that is the only contract downstream
/// code depends on (§22.5).
class ServingSizes extends Table with Identifiable {
  TextColumn get foodId =>
      text().customConstraint('NOT NULL REFERENCES food_items (id)')();
  TextColumn get label => text()();
  RealColumn get grams => real()();
  RealColumn get volumeMl => real().nullable()();
  BoolColumn get isHouseholdMeasure =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

/// Regional and transliteration variants, feeding the FTS index — this is
/// how "panir", "paneer" and "पनीर" all find the same food (§22.5).
class FoodAltNames extends Table with Identifiable {
  TextColumn get foodId =>
      text().customConstraint('NOT NULL REFERENCES food_items (id)')();
  TextColumn get name => text()();
  TextColumn get nameNormalized => text()();
  TextColumn get language => text()();
  BoolColumn get isTransliteration =>
      boolean().withDefault(const Constant(false))();
}

/// `(source, external_id)` — barcodes, USDA FDC ids, provenance. A GTIN is
/// just another external reference (§22.5).
class FoodExternalRefs extends Table with Identifiable {
  TextColumn get foodId =>
      text().customConstraint('NOT NULL REFERENCES food_items (id)')();

  /// `usda_fdc` | `off` | `ifct` | `gtin`.
  TextColumn get source => text()();
  TextColumn get externalId => text()();
}

/// Delta-free in this scope (no server to publish deltas to) but kept so
/// the bundled catalog's provenance is traceable across rebuilds (§22.5).
class CatalogVersions extends Table {
  IntColumn get version => integer()();
  DateTimeColumn get publishedAt => dateTime()();
  IntColumn get foodCount => integer()();
  TextColumn get checksum => text()();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {version};
}

/// A recipe [FoodItems] row's ingredient list with quantities (§19.10,
/// §22.5). The recipe's own nutrient values are derived from this once by
/// the catalog pipeline and stored as ordinary [FoodNutrientValues] rows,
/// so logging a recipe needs no special path.
class RecipeComponents extends Table with Identifiable {
  TextColumn get recipeFoodItemId =>
      text().customConstraint('NOT NULL REFERENCES food_items (id)')();
  TextColumn get ingredientFoodItemId =>
      text().customConstraint('NOT NULL REFERENCES food_items (id)')();
  RealColumn get quantityGrams => real()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}
