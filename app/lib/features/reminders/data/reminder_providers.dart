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

/// Today's summary, specifically — not the day the dashboard happens to be
/// showing.
///
/// [selectedDaySummaryProvider] follows the day header's arrows, and
/// planning from it meant that scrolling back to last Tuesday re-planned
/// tomorrow's reminders against last Tuesday's meals: a lunch reminder
/// would come back from the dead because that day's lunch was empty.
final _todaySummaryProvider = FutureProvider<DaySummary>((ref) {
  return ref.watch(daySummaryProvider(ref.watch(todayProvider)).future);
});

/// Today's state, as the planner needs it (§29.4's conditionality).
final reminderDayStateProvider = FutureProvider<ReminderDayState>((ref) async {
  final now = ref.watch(clockProvider).now();
  final preferences = ref.watch(preferencesProvider).value;
  final summary = await ref.watch(_todaySummaryProvider.future);
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
  final summary = await ref.watch(_todaySummaryProvider.future);
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
/// device reboot". Reboot is the manifest's boot receiver, and the other
/// two come through here — but resume and rule changes were never the
/// whole story. A "log lunch" notification sitting in the tray is
/// cancelled by *logging lunch*, and logging lunch is neither of those
/// events. [NourishlyApp] therefore watches [reminderPlanProvider] and
/// calls [apply] whenever the plan changes, which covers every write that
/// moves a condition: a meal logged, a glass of water drunk, a target met.
///
/// Because [ReminderScheduler.apply] replaces the whole pending set,
/// calling it again with the same plan is harmless — but it is also
/// cancel-then-reschedule on the platform side, so [apply] skips a plan
/// identical to the one already pushed rather than churning the tray.
class ReminderSync {
  ReminderSync(this._ref);

  final Ref _ref;

  /// What the platform was last given, as an order-sensitive signature of
  /// the rule ids and their times.
  String? _applied;

  /// Applies run one at a time.
  ///
  /// [resync] invalidates the day state and then reads the plan, and that
  /// invalidation also wakes [NourishlyApp]'s plan listener — so two
  /// applies are routinely in flight together. The adapter cancels the
  /// whole pending set before it schedules the new one, so interleaving
  /// two of them can leave the later plan's notifications wiped by the
  /// earlier one's cancel.
  Future<void> _pending = Future<void>.value();

  /// Re-reads the plan from scratch and pushes it unconditionally.
  ///
  /// For resume and rule changes, where an input may have moved without
  /// any provider noticing — the clock above all, which [ReminderDayState]
  /// samples once when it builds and which is exactly what has changed
  /// while the app was in the background.
  Future<void> resync() async {
    _applied = null;
    _ref.invalidate(reminderDayStateProvider);
    await apply(await _ref.read(reminderPlanProvider.future));
  }

  Future<void> apply(List<ScheduledReminder> plan) {
    final next = _pending.then((_) => _applyNow(plan));
    // The chain has to survive a failed link — one scheduler error must
    // not wedge every later apply — but the caller still sees its own.
    _pending = next.then((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  Future<void> _applyNow(List<ScheduledReminder> plan) async {
    final signature = [
      for (final reminder in plan)
        '${reminder.ruleId}@${reminder.when.toIso8601String()}',
    ].join('|');
    if (signature == _applied) return;
    await _ref.read(reminderSchedulerProvider).apply(plan);
    _applied = signature;
  }
}

final reminderSyncProvider = Provider<ReminderSync>(ReminderSync.new);
