import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nourishly_domain/nourishly_domain.dart';
import 'package:nourishly_ui/nourishly_ui.dart';

import '../../../../app/providers.dart';
import '../../../../shared/formatting.dart';
import '../../../profile/data/profile_providers.dart';
import '../../data/reminder_providers.dart';

/// Reminders (§29), reached from Settings' Preferences group.
///
/// Follows prototype 13A's treatment, which is what the row that opens it
/// belongs to: section headers over cards of list rows, values on the
/// right, nothing that needs reading. The screen's own job is §29.4's
/// behavioural requirements made visible — one switch that disables
/// everything, a per-type list, a quiet window, and an honest explanation
/// when the OS is the thing saying no.
class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    final enabled = ref.watch(remindersEnabledProvider);
    final rulesAsync = ref.watch(reminderRulesProvider);
    final permission = ref.watch(notificationPermissionProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Reminders')),
      body: SafeArea(
        top: false,
        child: rulesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('$error')),
          data: (rules) => ListView(
            padding: const EdgeInsets.fromLTRB(
              NourishlySpace.s4,
              NourishlySpace.s2,
              NourishlySpace.s4,
              NourishlySpace.s7,
            ),
            children: [
              // §29.4: "a single switch disables everything, and the app
              // remains fully functional."
              NourishlyCard(
                padding: EdgeInsets.zero,
                child: _MasterSwitch(enabled: enabled),
              ),

              // §29.4: permission denial is handled gracefully — the
              // settings show why they are inactive and how to fix it,
              // without prompting again.
              if (enabled && permission == NotificationPermission.denied)
                const _PermissionNotice(),

              if (enabled) ...[
                const NourishlySectionHeader(label: 'What to remind you about'),
                NourishlyCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final rule in rules)
                        _RuleRow(key: ValueKey(rule.id), rule: rule),
                    ],
                  ),
                ),

                const NourishlySectionHeader(label: 'Quiet hours'),
                const _QuietHoursCard(),

                const NourishlySectionHeader(label: 'Next up'),
                const _NextUpCard(),
              ],

              Padding(
                padding: const EdgeInsets.only(top: NourishlySpace.s5),
                child: Text(
                  // §29.1's posture, stated rather than implied. It is
                  // also the truthful answer to "does this app phone
                  // home to send me notifications?" — it does not.
                  'Reminders are scheduled on this phone. Nothing is sent '
                  'anywhere, and at most four arrive in a day.',
                  style: text.caption.copyWith(color: colors.ink3, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MasterSwitch extends ConsumerWidget {
  const _MasterSwitch({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        NourishlySpace.s4,
        NourishlySpace.s3,
        NourishlySpace.s3,
        NourishlySpace.s3,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reminders', style: text.body),
                Text(
                  enabled
                      ? 'On. Turn this off to silence all of them at once.'
                      : 'Off. Nothing is scheduled.',
                  style: text.caption.copyWith(color: colors.ink3, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: NourishlySpace.s2),
          Switch(
            value: enabled,
            onChanged: (on) => _toggleAll(context, ref, on: on),
          ),
        ],
      ),
    );
  }

  /// §29.1: the notification permission is asked for here, at the moment
  /// the user turns reminders on — never at launch.
  Future<void> _toggleAll(
    BuildContext context,
    WidgetRef ref, {
    required bool on,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    if (on) {
      final scheduler = ref.read(reminderSchedulerProvider);
      final current = await scheduler.permission();
      final granted = current == NotificationPermission.granted
          ? current
          : await scheduler.requestPermission();
      if (granted == NotificationPermission.denied) {
        showNourishlySnackOn(
          messenger,
          'Your phone is set to block notifications from Nourishly. '
          'Reminders will stay off until that changes.',
        );
      }
    }

    final ownerId = await ref.read(defaultOwnerProvider.future);
    await ref
        .read(preferencesDaoProvider)
        .update(ownerId, remindersEnabled: on);
    ref.read(summaryRevisionProvider.notifier).bump();
    await ref.read(reminderSyncProvider).resync();
  }
}

class _PermissionNotice extends StatelessWidget {
  const _PermissionNotice();

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    return Padding(
      padding: const EdgeInsets.only(top: NourishlySpace.s3),
      child: NourishlyCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.notifications_off_outlined,
              size: 20,
              color: colors.statusUnknown,
            ),
            const SizedBox(width: NourishlySpace.s3),
            Expanded(
              child: Text(
                'Notifications are turned off for Nourishly in your phone '
                'settings, so nothing below will appear. Everything else in '
                'the app works exactly as it does now.',
                style: text.caption.copyWith(color: colors.ink2, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleRow extends ConsumerWidget {
  const _RuleRow({super.key, required this.rule});

  final ReminderRule rule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    final schedule = rule.schedule;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        NourishlySpace.s4,
        NourishlySpace.s2,
        NourishlySpace.s3,
        NourishlySpace.s2,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_title, style: text.body),
                Text(
                  _describe(schedule),
                  style: text.caption.copyWith(color: colors.ink3),
                ),
              ],
            ),
          ),
          if (rule.enabled && schedule is DailySchedule)
            TextButton(
              onPressed: () => _pickTime(context, ref, schedule),
              child: Text(_formatTime(schedule.time)),
            ),
          Switch(
            value: rule.enabled,
            onChanged: (on) async {
              await ref
                  .read(reminderDaoProvider)
                  .setEnabled(rule.id, enabled: on);
              ref.read(summaryRevisionProvider.notifier).bump();
              await ref.read(reminderSyncProvider).resync();
            },
          ),
        ],
      ),
    );
  }

  String get _title => switch (rule.type) {
    ReminderType.meal => 'Log ${_slotName(rule.mealSlotKey)}',
    ReminderType.water => 'Drink water',
    ReminderType.endOfDaySummary => 'Day summary',
    ReminderType.goalAchieved => 'When a target is met',
    ReminderType.weeklyReport => 'Weekly report',
  };

  /// The subtitle says what the reminder will and will not do. The
  /// conditional half matters most: a user who does not know the water
  /// reminder stands down once they have had enough water will read a
  /// quiet afternoon as the feature being broken.
  String _describe(ReminderSchedule? schedule) => switch (rule.type) {
    ReminderType.water when schedule is InactivitySchedule =>
      'After ${_hours(schedule.gap)} without any water, between '
          '${_formatTime(schedule.windowStart)} and '
          '${_formatTime(schedule.windowEnd)}. Not once you have hit your '
          'target.',
    ReminderType.meal => 'Only if that meal is still empty.',
    ReminderType.endOfDaySummary =>
      'Your day in one line. Skipped on a day with nothing logged.',
    ReminderType.goalAchieved => 'When you reach water or protein for the day.',
    ReminderType.weeklyReport => 'On the morning your week starts.',
    _ => '',
  };

  Future<void> _pickTime(
    BuildContext context,
    WidgetRef ref,
    DailySchedule schedule,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: schedule.time.hour,
        minute: schedule.time.minute,
      ),
      helpText: 'Remind me at',
    );
    if (picked == null) return;
    await ref
        .read(reminderDaoProvider)
        .setSchedule(
          rule.id,
          DailySchedule(
            time: LocalTime.of(picked.hour, picked.minute),
            weekdays: schedule.weekdays,
          ),
        );
    ref.read(summaryRevisionProvider.notifier).bump();
    await ref.read(reminderSyncProvider).resync();
  }

  static String _slotName(String? key) => switch (key) {
    'breakfast' => 'breakfast',
    'lunch' => 'lunch',
    'dinner' => 'dinner',
    _ => 'a meal',
  };

  static String _hours(Duration gap) {
    final hours = gap.inMinutes / 60;
    final rounded = hours == hours.roundToDouble()
        ? hours.round().toString()
        : hours.toStringAsFixed(1);
    return '$rounded ${hours == 1 ? 'hour' : 'hours'}';
  }
}

class _QuietHoursCard extends ConsumerWidget {
  const _QuietHoursCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    final quiet = ref.watch(quietHoursProvider);

    return NourishlyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text('Nothing between', style: text.body)),
              TextButton(
                onPressed: () => _edit(context, ref, quiet, editingStart: true),
                child: Text(_formatTime(quiet.start)),
              ),
              Text('and', style: text.caption.copyWith(color: colors.ink3)),
              TextButton(
                onPressed: () =>
                    _edit(context, ref, quiet, editingStart: false),
                child: Text(_formatTime(quiet.end)),
              ),
            ],
          ),
          Text(
            'A reminder that falls inside this window waits until it ends '
            'rather than being dropped.',
            style: text.caption.copyWith(color: colors.ink3, height: 1.5),
          ),
        ],
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    QuietHours quiet, {
    required bool editingStart,
  }) async {
    final current = editingStart ? quiet.start : quiet.end;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
      helpText: editingStart ? 'Quiet from' : 'Quiet until',
    );
    if (picked == null) return;
    final next = LocalTime.of(picked.hour, picked.minute);
    final ownerId = await ref.read(defaultOwnerProvider.future);
    await ref
        .read(reminderDaoProvider)
        .setQuietHours(
          ownerId,
          QuietHours(
            start: editingStart ? next : quiet.start,
            end: editingStart ? quiet.end : next,
          ),
        );
    ref.read(summaryRevisionProvider.notifier).bump();
    await ref.read(reminderSyncProvider).resync();
  }
}

/// What is actually scheduled, as the app understands it.
///
/// Worth a card of its own because every rule on this screen is
/// conditional: the difference between "off" and "on but standing down
/// because you have already had enough water" is invisible otherwise, and
/// a user who cannot see it concludes the feature is broken.
class _NextUpCard extends ConsumerWidget {
  const _NextUpCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    final plan = ref.watch(reminderPlanProvider);

    return NourishlyCard(
      child: plan.when(
        loading: () => Text(
          'Working it out…',
          style: text.caption.copyWith(color: colors.ink3),
        ),
        error: (error, _) => Text(
          'Could not work out what is next.',
          style: text.caption.copyWith(color: colors.ink3),
        ),
        data: (reminders) => reminders.isEmpty
            ? Text(
                'Nothing is due. Reminders that are on stand down when '
                'there is nothing to say.',
                style: text.caption.copyWith(color: colors.ink3, height: 1.5),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final reminder in reminders.take(4))
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: NourishlySpace.s1,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(reminder.title, style: text.body),
                          ),
                          Text(
                            _whenLabel(ref, reminder.when),
                            style: text.caption.copyWith(color: colors.ink3),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  String _whenLabel(WidgetRef ref, DateTime when) {
    final today = ref.read(todayProvider);
    final day = DateTime(when.year, when.month, when.day);
    final time = _formatTime(LocalTime.fromDateTime(when));
    if (day == today) return time;
    if (day == today.add(const Duration(days: 1))) return 'Tomorrow, $time';
    return '${weekdayName(when.weekday)}, $time';
  }
}

String _formatTime(LocalTime time) {
  final suffix = time.hour < 12 ? 'am' : 'pm';
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  return '$hour:${time.minute.toString().padLeft(2, '0')} $suffix';
}
