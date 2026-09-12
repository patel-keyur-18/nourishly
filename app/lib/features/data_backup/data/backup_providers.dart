import 'package:drift/drift.dart' show Variable;
import 'package:nourishly_data/nourishly_data.dart' show ProfileEraser;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../food_catalog/data/food_catalog_providers.dart';
import '../../profile/data/profile_providers.dart';
import 'export_service.dart';

final exportServiceProvider = Provider<ExportService>((ref) {
  return ExportService(ref.watch(nourishlyDatabaseProvider));
});

/// §30.7's "delete all local data", built on the same table registry the
/// exporter uses — see [ProfileEraser].
final profileEraserProvider = Provider<ProfileEraser>((ref) {
  return ProfileEraser(ref.watch(nourishlyDatabaseProvider));
});

/// When a complete export was last written, or null if never.
final lastExportedAtProvider = Provider<DateTime?>((ref) {
  return ref.watch(preferencesProvider).value?.lastExportedAt;
});

/// §0.5's third mechanism: "a periodic export prompt — monthly,
/// dismissible, never nagging. With no server, an occasional gentle
/// reminder is the entire disaster-recovery strategy."
///
/// Three conditions, all of which have to hold:
///
/// - there is something worth losing (a profile that has logged nothing
///   does not need backing up, and prompting on day one teaches the user
///   to dismiss the prompt before it ever means anything);
/// - it has been a month since the last export, or there has never been
///   one;
/// - the user has not dismissed it recently.
final shouldPromptForExportProvider = Provider<bool>((ref) {
  final preferences = ref.watch(preferencesProvider).value;
  if (preferences == null) return false;

  final now = ref.watch(clockProvider).now();
  final snoozedUntil = preferences.exportPromptSnoozedUntil;
  if (snoozedUntil != null && snoozedUntil.isAfter(now)) return false;

  final summary = ref.watch(selectedDaySummaryProvider).value;
  final hasHistory = ref.watch(hasAnyHistoryProvider).value ?? false;
  if (!hasHistory && !(summary?.hasAnything ?? false)) return false;

  final lastExport = preferences.lastExportedAt;
  if (lastExport == null) {
    // Never exported. Prompt once there is a month of data to lose, not
    // on the first day — the prompt has to arrive when it reads as useful
    // advice rather than as a chore the app invented.
    final firstEntry = ref.watch(firstEntryDateProvider).value;
    return firstEntry != null &&
        now.difference(firstEntry) >= const Duration(days: 30);
  }
  return now.difference(lastExport) >= const Duration(days: 30);
});

/// Whether this profile has logged anything at all, ever.
final hasAnyHistoryProvider = FutureProvider<bool>((ref) async {
  ref.watch(summaryRevisionProvider);
  await ref.watch(catalogReadyProvider.future);
  final ownerId = await ref.watch(defaultOwnerProvider.future);
  final db = ref.watch(nourishlyDatabaseProvider);
  final row = await db
      .customSelect(
        'SELECT COUNT(*) AS c FROM food_log_entries '
        'WHERE owner_id = ? AND deleted_at IS NULL',
        variables: [Variable<String>(ownerId)],
      )
      .getSingle();
  return (row.data['c']! as int) > 0;
});

/// The date of the profile's earliest entry — what the export prompt uses
/// to decide whether there is a month of history worth protecting.
final firstEntryDateProvider = FutureProvider<DateTime?>((ref) async {
  ref.watch(summaryRevisionProvider);
  await ref.watch(catalogReadyProvider.future);
  final ownerId = await ref.watch(defaultOwnerProvider.future);
  final db = ref.watch(nourishlyDatabaseProvider);
  final row = await db
      .customSelect(
        'SELECT MIN(log_date) AS d FROM food_log_entries '
        'WHERE owner_id = ? AND deleted_at IS NULL',
        variables: [Variable<String>(ownerId)],
      )
      .getSingle();
  final seconds = row.data['d'] as int?;
  return seconds == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
});
