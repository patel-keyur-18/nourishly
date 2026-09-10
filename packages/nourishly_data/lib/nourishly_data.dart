/// Nourishly's data layer: the Drift (SQLite) schema, DAOs, and repository
/// implementations (§12.3).
///
/// Phase 1 ships schema only — [NourishlyDatabase] and its tables. DAOs and
/// repository implementations (the concrete side of `nourishly_domain`'s
/// ports) arrive with the features that need them.
library;

export 'src/database.dart';
export 'src/tables/catalog_tables.dart';
export 'src/tables/common.dart';
export 'src/tables/derived_tables.dart';
export 'src/tables/identity_tables.dart';
export 'src/tables/logging_tables.dart';
export 'src/tables/reference_tables.dart';
export 'src/tables/reminder_tables.dart';
