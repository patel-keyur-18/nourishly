import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nourishly_data/nourishly_data.dart';

import '../../../app/providers.dart';
import '../../food_catalog/data/food_catalog_providers.dart';
import '../../profile/data/profile_providers.dart';

final mealPlanDaoProvider = Provider<MealPlanDao>((ref) {
  return MealPlanDao(ref.watch(nourishlyDatabaseProvider));
});

/// The week the plan screen is showing, as its first day.
///
/// Starts on the week containing today, honouring the profile's own
/// week-start preference — a household that starts its week on Sunday
/// plans it on Sunday too.
final planWeekStartProvider = NotifierProvider<PlanWeekStart, DateTime>(
  PlanWeekStart.new,
);

class PlanWeekStart extends Notifier<DateTime> {
  @override
  DateTime build() {
    final weekStartDay =
        ref.watch(preferencesProvider).value?.weekStartDay ?? DateTime.monday;
    return startOfWeek(ref.watch(todayProvider), weekStartDay);
  }

  void shiftBy(int weeks) => state = state.add(Duration(days: 7 * weeks));
}

/// The day the week screen's agenda is showing. Defaults to today when
/// today is in the visible week, and to the week's first day otherwise —
/// opening next week on "Monday" is right; opening it on a day that is not
/// in it is not.
final planSelectedDayProvider = NotifierProvider<PlanSelectedDay, DateTime>(
  PlanSelectedDay.new,
);

class PlanSelectedDay extends Notifier<DateTime> {
  @override
  DateTime build() {
    final weekStart = ref.watch(planWeekStartProvider);
    final today = ref.watch(todayProvider);
    final isThisWeek =
        !today.isBefore(weekStart) &&
        today.isBefore(weekStart.add(const Duration(days: 7)));
    return isThisWeek ? today : weekStart;
  }

  void select(DateTime date) => state = date;
}

/// Every entry in the visible week — eaten, planned and skipped alike.
final planWeekEntriesProvider = StreamProvider<List<PlannedFood>>((ref) async* {
  final ownerId = await ref.watch(defaultOwnerProvider.future);
  final weekStart = ref.watch(planWeekStartProvider);
  yield* ref
      .watch(mealPlanDaoProvider)
      .watchRange(
        ownerId: ownerId,
        from: weekStart,
        to: weekStart.add(const Duration(days: 6)),
      );
});

/// Today's planned entries, grouped for the dashboard's confirm cards.
final todayPlannedProvider = StreamProvider<List<PlannedFood>>((ref) async* {
  final ownerId = await ref.watch(defaultOwnerProvider.future);
  final date = ref.watch(selectedDateProvider);
  yield* ref
      .watch(mealPlanDaoProvider)
      .watchRange(ownerId: ownerId, from: date, to: date)
      .map(
        (entries) => [
          for (final e in entries)
            if (e.isPlanned) e,
        ],
      );
});

/// What the selected day comes to if the rest of its plan is eaten.
///
/// Keyed on the entry stream rather than on a revision counter so it
/// refreshes when a meal is confirmed, planned or skipped — the three
/// things that change the answer.
final planProjectionProvider =
    FutureProvider.family<Map<String, ProjectedNutrient>, DateTime>((
      ref,
      date,
    ) async {
      ref.watch(planWeekEntriesProvider);
      final ownerId = await ref.watch(defaultOwnerProvider.future);
      return ref
          .watch(mealPlanDaoProvider)
          .projectionFor(ownerId: ownerId, logDate: date);
    });

/// The dashboard's own projection for the day it is showing.
final todayProjectionProvider = FutureProvider<Map<String, ProjectedNutrient>>((
  ref,
) async {
  ref.watch(todayPlannedProvider);
  final ownerId = await ref.watch(defaultOwnerProvider.future);
  return ref
      .watch(mealPlanDaoProvider)
      .projectionFor(
        ownerId: ownerId,
        logDate: ref.watch(selectedDateProvider),
      );
});
