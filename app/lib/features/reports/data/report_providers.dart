import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nourishly_data/nourishly_data.dart';
import 'package:nutrition_core/nutrition_core.dart';

import '../../../app/providers.dart';
import '../../food_catalog/data/food_catalog_providers.dart';
import '../../profile/data/profile_providers.dart';

final periodSummaryDaoProvider = Provider<PeriodSummaryDao>((ref) {
  return PeriodSummaryDao(ref.watch(nourishlyDatabaseProvider));
});

/// Which day of the week a week starts on, from `UserPreferences`.
final weekStartDayProvider = Provider<int>((ref) {
  return ref.watch(preferencesProvider).value?.weekStartDay ?? DateTime.monday;
});

/// The Monday (or whichever day the profile starts its week on) of the
/// week the weekly report is showing.
class SelectedWeekStart extends Notifier<DateTime> {
  @override
  DateTime build() =>
      startOfWeek(ref.watch(todayProvider), ref.watch(weekStartDayProvider));

  void shiftBy(int weeks) => state = state.add(Duration(days: 7 * weeks));

  void setTo(DateTime date) =>
      state = startOfWeek(date, ref.read(weekStartDayProvider));
}

final selectedWeekStartProvider = NotifierProvider<SelectedWeekStart, DateTime>(
  SelectedWeekStart.new,
);

/// The first of the month the monthly report is showing.
class SelectedMonth extends Notifier<DateTime> {
  @override
  DateTime build() => startOfMonth(ref.watch(todayProvider));

  void shiftBy(int months) =>
      state = DateTime(state.year, state.month + months);

  void setTo(DateTime date) => state = startOfMonth(date);
}

final selectedMonthProvider = NotifierProvider<SelectedMonth, DateTime>(
  SelectedMonth.new,
);

/// A week of days, reduced by the core engine.
final weekSummaryProvider = FutureProvider.family<PeriodSummary, DateTime>((
  ref,
  weekStart,
) async {
  ref.watch(summaryRevisionProvider);
  await ref.watch(catalogReadyProvider.future);
  final ownerId = await ref.watch(defaultOwnerProvider.future);
  // Drift's change stream, as elsewhere: any write to an entry table
  // invalidates the period that contains it.
  ref.watch(todayFoodLogProvider);
  ref.watch(todayWaterLogProvider);
  return ref
      .watch(periodSummaryDaoProvider)
      .week(
        ownerId: ownerId,
        containing: weekStart,
        weekStartDay: ref.watch(weekStartDayProvider),
      );
});

final monthSummaryProvider = FutureProvider.family<PeriodSummary, DateTime>((
  ref,
  month,
) async {
  ref.watch(summaryRevisionProvider);
  await ref.watch(catalogReadyProvider.future);
  final ownerId = await ref.watch(defaultOwnerProvider.future);
  ref.watch(todayFoodLogProvider);
  ref.watch(todayWaterLogProvider);
  return ref
      .watch(periodSummaryDaoProvider)
      .month(ownerId: ownerId, containing: month);
});

/// This month against the one before it (§27.10).
///
/// Both months go through the same engine, and [PeriodComparison] refuses
/// to produce a delta unless both clear §25.6's logging threshold.
final monthComparisonProvider =
    FutureProvider.family<PeriodComparison, DateTime>((ref, month) async {
      final current = await ref.watch(monthSummaryProvider(month).future);
      final previous = await ref.watch(
        monthSummaryProvider(DateTime(month.year, month.month - 1)).future,
      );
      return PeriodComparison.between(current: current, previous: previous);
    });

/// An inclusive date range, as a family key. A record, so two ranges with
/// the same ends are the same provider.
typedef ReportRange = ({DateTime from, DateTime to});

/// What this household's own lighter versions of dishes saved over a
/// period (`ForkSavingsDao`).
///
/// This is the payoff for recording how the kitchen actually cooks: it is
/// a difference between two recipes each summed from its own ingredients,
/// not a model of anything, and no public nutrition app can tell this
/// household the same thing because none of them knows how they cook.
final periodSavingsProvider = FutureProvider.family<PeriodSavings, ReportRange>(
  (ref, range) async {
    await ref.watch(catalogReadyProvider.future);
    final ownerId = await ref.watch(defaultOwnerProvider.future);
    return ForkSavingsDao(ref.watch(nourishlyDatabaseProvider))
        .savingsOver(ownerId, from: range.from, to: range.to);
  },
);

/// How a period's logged meals divided by cuisine (`CuisineDao.cuisineMix`).
final cuisineMixProvider =
    FutureProvider.family<
      ({List<CuisineCount> byCuisine, int totalEntries}),
      ReportRange
    >((ref, range) async {
      await ref.watch(catalogReadyProvider.future);
      final ownerId = await ref.watch(defaultOwnerProvider.future);
      return CuisineDao(ref.watch(nourishlyDatabaseProvider))
          .cuisineMix(ownerId, from: range.from, to: range.to);
    });
