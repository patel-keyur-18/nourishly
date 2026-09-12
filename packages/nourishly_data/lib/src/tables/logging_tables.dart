import 'package:drift/drift.dart';

import 'common.dart';

/// Breakfast/lunch/dinner/snack, or a user-defined category (§22.5).
/// System rows have `ownerId == null`; a profile's custom slots set it
/// (FR-M-11).
class MealSlots extends Table with Identifiable {
  TextColumn get ownerId =>
      text().nullable().customConstraint('REFERENCES users (id)')();

  /// `breakfast` | `lunch` | `dinner` | `snack` | `custom`.
  TextColumn get key => text()();
  TextColumn get displayName => text()();
  IntColumn get sortOrder => integer()();

  /// `HH:mm`, local time — drives meal auto-selection (FR-M-02).
  TextColumn get defaultTimeStart => text().nullable()();
  TextColumn get defaultTimeEnd => text().nullable()();
}

/// The central fact: a user consumed a quantity of a food, in a meal slot,
/// on a date (§22.1, §22.5). `gramsConsumed` and `logDate` are stored
/// explicitly even though derivable — servings can change, and back-dating
/// plus the configurable rollover time both break naive derivation.
///
/// `(owner_id, log_date)` is the only shape anything reads this table in:
/// the dashboard asks for one day, the reports ask for a range, and both
/// scope by profile. Without the index every one of those is a full scan
/// over the largest table in the app — fine at a week of logging, and the
/// thing that makes NFR-P-05 and NFR-P-06 unreachable at a year of it.
@TableIndex(name: 'food_log_entries_owner_date', columns: {#ownerId, #logDate})
class FoodLogEntries extends Table with Identifiable, Owned, SoftDeletable {
  DateTimeColumn get logDate => dateTime()();
  TextColumn get mealSlotId =>
      text().customConstraint('NOT NULL REFERENCES meal_slots (id)')();
  TextColumn get foodId =>
      text().customConstraint('NOT NULL REFERENCES food_items (id)')();

  /// Traceability: which [FoodItems.revision] this entry was logged against.
  IntColumn get foodRevision => integer()();
  TextColumn get servingSizeId =>
      text().nullable().customConstraint('REFERENCES serving_sizes (id)')();
  RealColumn get quantity => real()();
  RealColumn get gramsConsumed => real()();
  DateTimeColumn get loggedAt => dateTime()();

  /// `manual` | `template` | `copy` | `barcode` | `ai_suggested`.
  TextColumn get source => text()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now())();
}

/// The immutable nutrient snapshot, written in the same transaction as the
/// entry (I-1). Absent row = the food did not report that nutrient (I-2).
/// Never updated except by wholesale replacement when the entry is edited.
class LogEntryNutrients extends Table {
  TextColumn get entryId =>
      text().customConstraint('NOT NULL REFERENCES food_log_entries (id)')();
  TextColumn get nutrientId =>
      text().customConstraint('NOT NULL REFERENCES nutrients (id)')();

  /// In the nutrient's canonical unit (I-10).
  RealColumn get amount => real()();

  @override
  Set<Column> get primaryKey => {entryId, nutrientId};
}

/// Immutable and additive by design (§17.6 → still true with no sync: an
/// edit is a delete-and-recreate, never an in-place amount change).
@TableIndex(
  name: 'water_log_entries_owner_date',
  columns: {#ownerId, #logDate},
)
class WaterLogEntries extends Table with Identifiable, Owned, SoftDeletable {
  DateTimeColumn get logDate => dateTime()();
  DateTimeColumn get loggedAt => dateTime()();

  /// Canonical regardless of the display unit (I-10).
  RealColumn get volumeMl => real()();

  /// `quick_add` | `custom` | `beverage_derived`.
  TextColumn get source => text()();

  /// Links a logged beverage's hydration contribution back to its food
  /// entry (FR-W-09), so deleting the tea also removes its water credit.
  TextColumn get beverageEntryId =>
      text().nullable().customConstraint('REFERENCES food_log_entries (id)')();
}

class MealTemplates extends Table
    with Identifiable, Owned, Timestamped, SoftDeletable {
  TextColumn get name => text()();
  TextColumn get defaultMealSlotId =>
      text().nullable().customConstraint('REFERENCES meal_slots (id)')();
  DateTimeColumn get lastUsedAt => dateTime().nullable()();
  IntColumn get useCount => integer().withDefault(const Constant(0))();
}

/// Applying a template creates independent [FoodLogEntries] rows with
/// fresh snapshots — entries never reference the template back, so editing
/// one never alters past logs (§22.5).
@TableIndex(name: 'meal_template_items_template', columns: {#templateId})
class MealTemplateItems extends Table with Identifiable {
  TextColumn get templateId =>
      text().customConstraint('NOT NULL REFERENCES meal_templates (id)')();
  TextColumn get foodId =>
      text().customConstraint('NOT NULL REFERENCES food_items (id)')();
  TextColumn get servingSizeId =>
      text().nullable().customConstraint('REFERENCES serving_sizes (id)')();
  RealColumn get quantity => real()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

/// `preferredServingId` is what makes repeat logging one tap (J-2, §22.5).
class FavoriteFoods extends Table with Identifiable, Owned {
  TextColumn get foodId =>
      text().customConstraint('NOT NULL REFERENCES food_items (id)')();
  TextColumn get preferredServingId =>
      text().nullable().customConstraint('REFERENCES serving_sizes (id)')();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();
}
