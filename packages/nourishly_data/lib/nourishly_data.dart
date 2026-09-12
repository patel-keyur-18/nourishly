/// Nourishly's data layer: the Drift (SQLite) schema, DAOs, and repository
/// implementations (§12.3).
///
/// Phase 1 shipped schema only. Phase 2 adds the first DAO,
/// [FoodSearchDao], over the FTS5 search index (§27.4, §22.7). More DAOs
/// and repository implementations (the concrete side of
/// `nourishly_domain`'s ports) arrive with the features that need them.
library;

export 'src/catalog_importer.dart';
export 'src/cooking_fat.dart';
export 'src/cuisine_tags.dart';
export 'src/dao/body_weight_dao.dart';
export 'src/dao/custom_food_dao.dart';
export 'src/dao/daily_summary_dao.dart';
export 'src/dao/default_owner.dart';
export 'src/dao/food_logging_dao.dart';
export 'src/dao/food_search_dao.dart';
export 'src/dao/period_summary_dao.dart';
export 'src/dao/preferences_dao.dart';
export 'src/dao/recipe_dao.dart';
export 'src/dao/profile_dao.dart';
export 'src/dao/profile_eraser.dart';
export 'src/dao/reminder_dao.dart';
export 'src/dao/water_log_dao.dart';
export 'src/database.dart';
export 'src/diet_classifier.dart';
export 'src/rda_importer.dart';
export 'src/tables/catalog_tables.dart';
export 'src/tables/common.dart';
export 'src/tables/derived_tables.dart';
export 'src/tables/identity_tables.dart';
export 'src/tables/logging_tables.dart';
export 'src/tables/reference_tables.dart';
export 'src/tables/reminder_tables.dart';
export 'src/export/data_exporter.dart';
export 'src/export/data_importer.dart';
export 'src/export/export_archive.dart';
export 'src/export/export_schema.dart';
