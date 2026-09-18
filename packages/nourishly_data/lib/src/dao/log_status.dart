import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/logging_tables.dart';

/// The one place the difference between *eaten* and *intended* is spelled
/// out.
///
/// Adding a status column to the log put a question in front of every
/// query that already read it: which entries does this one mean? Answering
/// it inline, query by query, is how one of them ends up answering it
/// differently — and a single missed filter puts food nobody ate into a
/// daily score. So the answer lives here, both readings are named, and
/// every caller picks one by name.

/// Entries that record actual intake: what the dashboard, the summaries,
/// the reports, the score, the insights and the export all mean.
///
/// A skipped entry is excluded for the same reason a planned one is — it
/// is a record of a plan, not of a meal.
Expression<bool> isActual($FoodLogEntriesTable entries) =>
    entries.deletedAt.isNull() & entries.status.equals(logStatusLogged);

/// Entries that make up a projected day: what has been eaten so far plus
/// what is still planned. Only the plan screen and the dashboard's
/// projection read this — a forecast never reaches a report.
Expression<bool> isProjected($FoodLogEntriesTable entries) =>
    entries.deletedAt.isNull() &
    entries.status.isIn(const [logStatusLogged, logStatusPlanned]);

/// The same restriction as [isActual], for the handful of reads written as
/// raw SQL. Interpolated into a `WHERE`, with `e` as the table alias.
const String isActualSql = "e.deleted_at IS NULL AND e.status = 'logged'";
