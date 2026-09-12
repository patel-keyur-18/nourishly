/// Which tables an export covers, how each is scoped to one profile, and
/// which of them an import is allowed to write.
///
/// This is the list §30.6 calls "complete": profile versions, goals,
/// target sets, all log entries with their nutrient snapshots, water logs,
/// custom foods, templates, favourites, preferences, and derived
/// summaries. It is kept as data rather than as twenty hand-written
/// methods so that a table added later is one line here, and so the
/// completeness test can compare it against the live schema and fail when
/// somebody forgets.
library;

/// How a table's rows are narrowed to the profile being exported.
///
/// The predicate is raw SQL with one `?` bound to the owner id — the
/// tables divide cleanly into "has an owner_id" and "belongs to a parent
/// that does", and expressing the second as a subquery keeps the exporter
/// free of per-table joins.
class ExportedTable {
  const ExportedTable({
    required this.name,
    required this.scope,
    required this.primaryKey,
    this.derived = false,
    this.childOf,
  });

  /// The SQL table name.
  final String name;

  /// A `WHERE` predicate with exactly one `?` placeholder for the owner
  /// id, or one that uses it inside a subquery.
  final String scope;

  /// The columns that identify a row. Single-column for everything with a
  /// UUID; composite for the snapshot tables that are keyed by their
  /// parent plus a nutrient.
  final List<String> primaryKey;

  /// Derived data (§22.5's "rebuildable, never synced").
  ///
  /// Exported, because §30.6 asks for a complete archive and a report a
  /// user can read without the app is worth more than a few kilobytes
  /// saved. **Never imported**: recomputing from the imported entries is
  /// strictly better than trusting a summary that was computed against a
  /// ruleset version this build may no longer agree with.
  final bool derived;

  /// `(parentTable, foreignKeyColumn)` for rows that live and die with a
  /// parent row.
  ///
  /// When a merge accepts a newer parent, its existing children are
  /// cleared before the incoming ones land. Without this, editing an entry
  /// on one device and importing it into another would leave the old
  /// nutrient snapshot rows behind, and the entry would read as having
  /// more nutrients than it has.
  final (String, String)? childOf;
}

/// Everything a profile owns, in dependency order — parents before the
/// rows that reference them, so a single forward pass can insert without
/// tripping a foreign key.
const exportedTables = <ExportedTable>[
  ExportedTable(name: 'users', scope: 'id = ?', primaryKey: ['id']),
  ExportedTable(
    name: 'user_preferences',
    scope: 'owner_id = ?',
    primaryKey: ['owner_id'],
  ),
  ExportedTable(
    name: 'user_profile_versions',
    scope: 'owner_id = ?',
    primaryKey: ['id'],
  ),
  ExportedTable(name: 'goals', scope: 'owner_id = ?', primaryKey: ['id']),
  ExportedTable(name: 'target_sets', scope: 'owner_id = ?', primaryKey: ['id']),
  ExportedTable(
    name: 'nutrient_targets',
    scope: 'target_set_id IN (SELECT id FROM target_sets WHERE owner_id = ?)',
    primaryKey: ['id'],
    childOf: ('target_sets', 'target_set_id'),
  ),
  ExportedTable(
    name: 'body_weight_entries',
    scope: 'owner_id = ?',
    primaryKey: ['id'],
  ),

  // Custom foods and recipes. Catalog rows (`owner_id IS NULL`) are left
  // out deliberately: they are identical on every device and rebuilt from
  // the bundled asset on launch, so exporting them would multiply the
  // archive size by a hundred for nothing (§0.5's same argument as the
  // backup exclusion).
  ExportedTable(
    name: 'food_items',
    scope: 'owner_id = ?',
    primaryKey: ['id'],
  ),
  ExportedTable(
    name: 'serving_sizes',
    scope: 'food_id IN (SELECT id FROM food_items WHERE owner_id = ?)',
    primaryKey: ['id'],
    childOf: ('food_items', 'food_id'),
  ),
  ExportedTable(
    name: 'food_nutrient_values',
    scope: 'food_id IN (SELECT id FROM food_items WHERE owner_id = ?)',
    primaryKey: ['id'],
    childOf: ('food_items', 'food_id'),
  ),
  ExportedTable(
    name: 'food_alt_names',
    scope: 'food_id IN (SELECT id FROM food_items WHERE owner_id = ?)',
    primaryKey: ['id'],
    childOf: ('food_items', 'food_id'),
  ),
  ExportedTable(
    name: 'recipe_components',
    scope:
        'recipe_food_item_id IN (SELECT id FROM food_items WHERE owner_id = ?)',
    primaryKey: ['id'],
    childOf: ('food_items', 'recipe_food_item_id'),
  ),

  // A profile's own meal slots only; the four system slots come from the
  // catalog import.
  ExportedTable(name: 'meal_slots', scope: 'owner_id = ?', primaryKey: ['id']),

  ExportedTable(
    name: 'food_log_entries',
    scope: 'owner_id = ?',
    primaryKey: ['id'],
  ),
  ExportedTable(
    name: 'log_entry_nutrients',
    scope:
        'entry_id IN (SELECT id FROM food_log_entries WHERE owner_id = ?)',
    primaryKey: ['entry_id', 'nutrient_id'],
    childOf: ('food_log_entries', 'entry_id'),
  ),
  ExportedTable(
    name: 'water_log_entries',
    scope: 'owner_id = ?',
    primaryKey: ['id'],
  ),
  ExportedTable(
    name: 'meal_templates',
    scope: 'owner_id = ?',
    primaryKey: ['id'],
  ),
  ExportedTable(
    name: 'meal_template_items',
    scope:
        'template_id IN (SELECT id FROM meal_templates WHERE owner_id = ?)',
    primaryKey: ['id'],
    childOf: ('meal_templates', 'template_id'),
  ),
  ExportedTable(
    name: 'favorite_foods',
    scope: 'owner_id = ?',
    primaryKey: ['id'],
  ),
  ExportedTable(
    name: 'reminder_rules',
    scope: 'owner_id = ?',
    primaryKey: ['id'],
  ),

  // Derived. Read-only on the way back in — see [ExportedTable.derived].
  ExportedTable(
    name: 'daily_summaries',
    scope: 'owner_id = ?',
    primaryKey: ['id'],
    derived: true,
  ),
  ExportedTable(
    name: 'daily_summary_nutrients',
    scope: 'summary_id IN (SELECT id FROM daily_summaries WHERE owner_id = ?)',
    primaryKey: ['summary_id', 'nutrient_id'],
    derived: true,
  ),
  ExportedTable(
    name: 'daily_scores',
    scope: 'summary_id IN (SELECT id FROM daily_summaries WHERE owner_id = ?)',
    primaryKey: ['summary_id'],
    derived: true,
  ),
  ExportedTable(
    name: 'score_components',
    scope: 'summary_id IN (SELECT id FROM daily_summaries WHERE owner_id = ?)',
    primaryKey: ['summary_id', 'component_key'],
    derived: true,
  ),
  ExportedTable(
    name: 'daily_insights',
    scope: 'summary_id IN (SELECT id FROM daily_summaries WHERE owner_id = ?)',
    primaryKey: ['id'],
    derived: true,
  ),
];

/// The tables an import is allowed to write.
Iterable<ExportedTable> get importableTables =>
    exportedTables.where((t) => !t.derived);
