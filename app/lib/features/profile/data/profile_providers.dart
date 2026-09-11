import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nourishly_data/nourishly_data.dart' hide NutrientTarget;
import 'package:nutrition_core/nutrition_core.dart' show NutrientTarget;

import '../../../app/providers.dart';
import '../../food_catalog/data/food_catalog_providers.dart';

final profileDaoProvider = Provider<ProfileDao>((ref) {
  return ProfileDao(ref.watch(nourishlyDatabaseProvider));
});

final dailySummaryDaoProvider = Provider<DailySummaryDao>((ref) {
  return DailySummaryDao(ref.watch(nourishlyDatabaseProvider));
});

/// Bumped after any write that changes what a day contains, so the
/// summary providers below re-read. Drift's own change stream covers the
/// entry tables, but a summary also depends on the target set and the
/// profile, and those are written from a different screen.
class SummaryRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final summaryRevisionProvider = NotifierProvider<SummaryRevision, int>(
  SummaryRevision.new,
);

/// The profile version in force today, or null if setup was skipped.
///
/// Null is a first-class state everywhere downstream: §27.1 makes profile
/// setup skippable at every step, so a null profile means generic targets
/// and a persistent, non-nagging invitation to personalise — not an error
/// and not a blocked app.
final currentProfileProvider = FutureProvider<UserProfileVersion?>((ref) async {
  ref.watch(summaryRevisionProvider);
  await ref.watch(catalogReadyProvider.future);
  final ownerId = await ref.watch(defaultOwnerProvider.future);
  return ref.watch(profileDaoProvider).currentProfile(ownerId);
});

/// The local profile's name, shown in the dashboard's day header.
final profileDisplayNameProvider = FutureProvider<String?>((ref) async {
  final db = ref.watch(nourishlyDatabaseProvider);
  final ownerId = await ref.watch(defaultOwnerProvider.future);
  final rows = await (db.select(
    db.users,
  )..where((u) => u.id.equals(ownerId))).get();
  return rows.isEmpty ? null : rows.first.displayName;
});

final currentGoalProvider = FutureProvider<Goal?>((ref) async {
  ref.watch(summaryRevisionProvider);
  final ownerId = await ref.watch(defaultOwnerProvider.future);
  return ref.watch(profileDaoProvider).currentGoal(ownerId);
});

/// The targets in force on a given date — the ones that date is measured
/// against, which is not necessarily today's (I-3).
final targetsForDateProvider =
    FutureProvider.family<Map<String, NutrientTarget>, DateTime>((
      ref,
      date,
    ) async {
      ref.watch(summaryRevisionProvider);
      await ref.watch(catalogReadyProvider.future);
      final ownerId = await ref.watch(defaultOwnerProvider.future);
      final dao = ref.watch(profileDaoProvider);
      final set = await dao.targetSetOn(ownerId, date);
      if (set == null) return const {};
      return dao.targetsIn(set.id);
    });

/// A whole day, aggregated and scored. The dashboard and the daily report
/// both read this and nothing else — §27.2 requires the dashboard to
/// render from one materialised summary rather than re-aggregating.
final daySummaryProvider = FutureProvider.family<DaySummary, DateTime>((
  ref,
  date,
) async {
  ref.watch(summaryRevisionProvider);
  await ref.watch(catalogReadyProvider.future);
  final ownerId = await ref.watch(defaultOwnerProvider.future);
  // Drift's change stream: any write to an entry table invalidates this.
  ref.watch(todayFoodLogProvider);
  ref.watch(todayWaterLogProvider);
  return ref
      .watch(dailySummaryDaoProvider)
      .summaryFor(ownerId: ownerId, logDate: date);
});

/// The date the dashboard and report are showing. §27.2 gives the day
/// header quick navigation to adjacent days, so this is not simply today.
class SelectedDate extends Notifier<DateTime> {
  @override
  DateTime build() => ref.watch(todayProvider);

  void shiftBy(int days) => state = state.add(Duration(days: days));

  void setTo(DateTime date) =>
      state = DateTime(date.year, date.month, date.day);
}

final selectedDateProvider = NotifierProvider<SelectedDate, DateTime>(
  SelectedDate.new,
);

/// Today's summary, which is what the dashboard shows by default.
final selectedDaySummaryProvider = FutureProvider<DaySummary>((ref) {
  return ref.watch(daySummaryProvider(ref.watch(selectedDateProvider)).future);
});
