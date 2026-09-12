import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nourishly_data/nourishly_data.dart'
    hide NutrientTarget, ReminderRule;
import 'package:nourishly_domain/nourishly_domain.dart';

import '../../../app/providers.dart';
import '../../food_catalog/data/food_catalog_providers.dart';
import '../../profile/data/profile_providers.dart';
import 'end_of_day_summary.dart';
import 'local_notification_scheduler.dart';

final reminderDaoProvider = Provider<ReminderDao>((ref) {
  return ReminderDao(ref.watch(nourishlyDatabaseProvider));
});

/// The one [ReminderScheduler] for the app (§29.3).
///
/// Overridden with [NoopReminderScheduler] in tests: a widget test has no
/// platform channel to answer the plugin, and a screen that cannot render
/// without one is a screen that cannot be tested.
final reminderSchedulerProvider = Provider<ReminderScheduler>((ref) {
  return LocalNotificationScheduler();
});

final reminderPlannerProvider = Provider<ReminderPlanner>((ref) {
  return const ReminderPlanner();
});

/// This profile's rules, seeded with §29.2's defaults on first read.
final reminderRulesProvider = FutureProvider<List<ReminderRule>>((ref) async {
  ref.watch(summaryRevisionProvider);
  final ownerId = await ref.watch(defaultOwnerProvider.future);
  return ref.watch(reminderDaoProvider).rulesFor(ownerId);
});

/// §29.4's single switch.
final remindersEnabledProvider = Provider<bool>((ref) {
  return ref.watch(preferencesProvider).value?.remindersEnabled ?? false;
});

/// How many rules are on — Settings' "3 on" summary (prototype 13A).
final enabledReminderCountProvider = Provider<int>((ref) {
  if (!ref.watch(remindersEnabledProvider)) return 0;
  final rules = ref.watch(reminderRulesProvider).value ?? const [];
  return rules.where((r) => r.enabled).length;
});

/// The quiet window, which the UI edits for the whole profile at once.
final quietHoursProvider = Provider<QuietHours>((ref) {
  final rules = ref.watch(reminderRulesProvider).value ?? const [];
  for (final rule in rules) {
    final quiet = rule.quietHours;
    if (quiet != null) return quiet;
  }
  return QuietHours.defaults;
});

/// Whether the OS will actually deliver anything.
///
/// §29.4: permission denial is handled gracefully — the settings screen
/// shows why reminders are inactive and how to turn them on, and does not
/// prompt again.
final notificationPermissionProvider = FutureProvider<NotificationPermission>((
  ref,
) async {
  ref.watch(summaryRevisionProvider);
  return ref.watch(reminderSchedulerProvider).permission();
});

/// Today's state, as the planner needs it (§29.4's conditionality).
final reminderDayStateProvider = FutureProvider<ReminderDayState>((ref) async {
  final now = ref.watch(clockProvider).now();
  final preferences = ref.watch(preferencesProvider).value;
  final summary = await ref.watch(selectedDaySummaryProvider.future);
  final water = ref.watch(todayWaterLogProvider).value ?? const [];

  final protein = summary.nutrient('protein');
  return ReminderDayState(
    now: now,
    waterTargetMet:
        summary.waterTargetMl != null &&
        summary.waterMl >= summary.waterTargetMl!,
    proteinTargetMet:
        protein?.pctOfTarget != null && protein!.pctOfTarget! >= 100,
    lastWaterLoggedAt: water.isEmpty
        ? null
        : water.map((e) => e.loggedAt).reduce((a, b) => a.isAfter(b) ? a : b),
    loggedMealSlotKeys: {
      for (final meal in summary.meals)
        if (!meal.isEmpty) meal.slotKey,
    },
    weekStartDay: preferences?.weekStartDay ?? DateTime.monday,
    dayHasEntries: summary.hasAnything,
  );
});

/// What would be pending right now, given the rules and the day.
///
/// Exposed as a provider rather than computed inside the sync service so
/// the reminders screen can show the user the next reminder without
/// asking the platform, and so a test can assert on the plan.
final reminderPlanProvider = FutureProvider<List<ScheduledReminder>>((
  ref,
) async {
  final rules = await ref.watch(reminderRulesProvider.future);
  final state = await ref.watch(reminderDayStateProvider.future);
  final summary = await ref.watch(selectedDaySummaryProvider.future);
  return ref
      .watch(reminderPlannerProvider)
      .plan(
        rules: rules,
        state: state,
        masterEnabled: ref.watch(remindersEnabledProvider),
        summaryLine: endOfDaySummaryLine(summary),
      );
});

/// Pushes the current plan to the platform.
///
/// §29.4 wants rescheduling "on app resume, on rule change, and after
/// device reboot". Reboot is the manifest's boot receiver; the other two
/// both come through here, and because [ReminderScheduler.apply] replaces
/// the whole pending set, calling it more often than necessary is
/// harmless rather than a source of duplicates.
class ReminderSync {
  const ReminderSync(this._ref);

  final Ref _ref;

  Future<void> resync() async {
    final plan = await _ref.read(reminderPlanProvider.future);
    await _ref.read(reminderSchedulerProvider).apply(plan);
  }
}

final reminderSyncProvider = Provider<ReminderSync>(ReminderSync.new);
