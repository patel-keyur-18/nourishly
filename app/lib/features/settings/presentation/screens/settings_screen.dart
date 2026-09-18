import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nourishly_data/nourishly_data.dart' hide NutrientTarget;
import 'package:nourishly_ui/nourishly_ui.dart';
import 'package:nutrition_core/nutrition_core.dart';

import '../../../../app/providers.dart';
import '../../../../shared/app_version.dart';
import '../appearance.dart';
import '../../../data_backup/data/backup_providers.dart';
import '../../../food_catalog/data/food_catalog_providers.dart';
import '../../../profile/data/profile_providers.dart';
import '../../../profile/presentation/profile_labels.dart';
import '../../../reminders/data/reminder_providers.dart';

/// Settings (prototype screen 13, option A — grouped list).
///
/// Redrawn on 2026-09-12 to be the screen that was approved. What had been
/// built was feature-led: five groups that grew one at a time, an inline
/// title where the prototype has an app bar, a body-weight history card in
/// the middle of the preferences, two paragraphs of disclaimer in a card of
/// their own, and an explanatory subtitle under almost every row. Option A
/// was chosen for being "dense, scannable, nothing to read", and it had
/// become the opposite.
///
/// What it is now, top to bottom, is 13A: an app bar titled **Settings**,
/// three groups — *Profile*, *Preferences*, *Your data* — of uniform
/// label-plus-value rows, and the prototype's centred fine print at the
/// bottom. Explanation moved to the screen each row opens, which is where
/// there is room for it.
///
/// Three deliberate departures, each recorded with its reasoning in
/// `docs/design/decisions.md`:
///
/// - **No profile switcher.** One profile per phone (§0.4's typical case),
///   so a switcher would add a second concept to every screen in service
///   of a case that does not arise. `owner_id` stays on every owned row, so
///   this forecloses nothing.
/// - **An Appearance row the prototype does not draw.** Dark mode was
///   built and honoured from Phase 1 but had no control (FR-S-09).
/// - **Switches for the two §21.8 toggles**, where 13A draws a value and a
///   chevron. A chevron on a boolean promises a screen that should not
///   exist; the row still reads as one dense line.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferencesAsync = ref.watch(preferencesProvider);
    final profileName = ref.watch(profileDisplayNameProvider).value ?? 'You';
    final goal = ref.watch(currentGoalProvider).value;
    final profile = ref.watch(currentProfileProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: preferencesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorBody(error: error),
        data: (preferences) => ListView(
          padding: const EdgeInsets.fromLTRB(
            NourishlySpace.s4,
            0,
            NourishlySpace.s4,
            NourishlySpace.s7,
          ),
          children: [
            // 13A's first group. One profile rather than the prototype's
            // three, and it opens the profile screen rather than switching
            // between them.
            const NourishlySectionHeader(label: 'Profile'),
            NourishlyRowGroup(
              children: [
                NourishlyListRow(
                  leading: NourishlyAvatar(name: profileName),
                  title: profileName,
                  subtitle: _profileSummary(goal, profile),
                  onTap: () => context.push('/profile/me'),
                ),
                NourishlyListRow(
                  title: 'Your recipes',
                  onTap: () => context.push('/recipes'),
                ),
              ],
            ),

            const NourishlySectionHeader(label: 'Preferences'),
            NourishlyRowGroup(
              children: [
                NourishlyListRow(
                  title: 'Units',
                  value: preferences.unitSystem == 'metric'
                      ? 'Metric'
                      : 'Imperial',
                  onTap: () => _editUnits(context, ref, preferences),
                ),
                NourishlyListRow(
                  title: 'Week starts',
                  value: preferences.weekStartDay == DateTime.sunday
                      ? 'Sunday'
                      : 'Monday',
                  onTap: () => _editWeekStart(context, ref, preferences),
                ),
                NourishlyListRow(
                  title: 'Day rolls over',
                  value: _formatMinutes(preferences.dayRolloverTime),
                  onTap: () => _editRollover(context, ref, preferences),
                ),
                NourishlyListRow(
                  title: 'Reminders',
                  value: _reminderSummary(ref),
                  onTap: () => context.push('/profile/reminders'),
                ),
                NourishlyListRow(
                  title: 'Focus nutrients',
                  value: _focusSummary(ref),
                  onTap: () => _editFocusNutrients(context, ref),
                ),
                NourishlyListRow(
                  title: 'Appearance',
                  value: Appearance.fromId(preferences.theme).label,
                  onTap: () => _editAppearance(context, ref, preferences),
                ),
                // §21.8: the score is fully dismissible, leaving the raw
                // data and the insights.
                NourishlyListRow.switched(
                  title: 'Show daily score',
                  value: preferences.showScore,
                  onChanged: (v) => _update(ref, showScore: v),
                ),
                // §21.8: for tracking nutrients without calories.
                NourishlyListRow.switched(
                  title: 'Hide energy',
                  value: preferences.hideEnergy,
                  onChanged: (v) => _update(ref, hideEnergy: v),
                ),
              ],
            ),

            // 13A's third group. §27.13: export and deletion are
            // discoverable, not buried.
            const NourishlySectionHeader(label: 'Your data'),
            const _YourDataGroup(),

            const _AboutFooter(),
          ],
        ),
      ),
    );
  }

  /// The prototype's `.lr-sub` on a profile row: "General health · active".
  static String _profileSummary(Goal? goal, UserProfileVersion? profile) {
    final parts = [
      if (goal != null) GoalType.fromId(goal.goalType).label,
      if (profile != null)
        ProfileLabels.activityInline(
          ActivityLevel.fromId(profile.activityLevel),
        ),
    ];
    return parts.isEmpty ? 'Not set up yet' : parts.join(' · ');
  }

  String _reminderSummary(WidgetRef ref) {
    if (!ref.watch(remindersEnabledProvider)) return 'Off';
    final count = ref.watch(enabledReminderCountProvider);
    return count == 0 ? 'None on' : '$count on';
  }

  String _focusSummary(WidgetRef ref) {
    final ids = ref.watch(focusNutrientIdsProvider);
    if (ids.isEmpty) return 'None';
    return ids.map(_titleCase).join(', ');
  }

  static void _update(
    WidgetRef ref, {
    bool? showScore,
    bool? hideEnergy,
    int? weekStartDay,
    int? dayRolloverTime,
    String? unitSystem,
    List<String>? focusNutrientIds,
    String? theme,
  }) async {
    final ownerId = await ref.read(defaultOwnerProvider.future);
    await ref
        .read(preferencesDaoProvider)
        .update(
          ownerId,
          showScore: showScore,
          hideEnergy: hideEnergy,
          weekStartDay: weekStartDay,
          dayRolloverTime: dayRolloverTime,
          unitSystem: unitSystem,
          focusNutrientIds: focusNutrientIds,
          theme: theme,
        );
    ref.read(summaryRevisionProvider.notifier).bump();
  }

  /// A picker rather than a blind flip. Tapping "Units" used to swap metric
  /// for imperial with no confirmation of what it had become until the row
  /// redrew — fine when you meant it, baffling when you did not.
  Future<void> _editUnits(
    BuildContext context,
    WidgetRef ref,
    UserPreference preferences,
  ) async {
    final choice = await showNourishlyOptions<String>(
      context: context,
      title: 'Units',
      selected: preferences.unitSystem,
      options: const [
        NourishlyOption(
          value: 'metric',
          label: 'Metric',
          subtitle: 'kg, cm, ml',
        ),
        NourishlyOption(
          value: 'imperial',
          label: 'Imperial',
          subtitle: 'lb, ft/in, fl oz',
        ),
      ],
    );
    if (choice == null) return;
    _update(ref, unitSystem: choice);
  }

  Future<void> _editWeekStart(
    BuildContext context,
    WidgetRef ref,
    UserPreference preferences,
  ) async {
    final choice = await showNourishlyOptions<int>(
      context: context,
      title: 'Week starts',
      message: 'Used by the weekly report and the consistency strip.',
      selected: preferences.weekStartDay,
      options: const [
        NourishlyOption(value: DateTime.monday, label: 'Monday'),
        NourishlyOption(value: DateTime.sunday, label: 'Sunday'),
      ],
    );
    if (choice == null) return;
    _update(ref, weekStartDay: choice);
  }

  Future<void> _editRollover(
    BuildContext context,
    WidgetRef ref,
    UserPreference preferences,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: preferences.dayRolloverTime ~/ 60,
        minute: preferences.dayRolloverTime % 60,
      ),
      helpText: 'A new day starts at',
    );
    if (picked == null) return;
    _update(ref, dayRolloverTime: picked.hour * 60 + picked.minute);
  }

  Future<void> _editAppearance(
    BuildContext context,
    WidgetRef ref,
    UserPreference preferences,
  ) async {
    final choice = await showNourishlyOptions<Appearance>(
      context: context,
      title: 'Appearance',
      selected: Appearance.fromId(preferences.theme),
      options: [
        for (final appearance in Appearance.values)
          NourishlyOption(value: appearance, label: appearance.label),
      ],
    );
    if (choice == null) return;
    _update(ref, theme: choice.id);
  }

  Future<void> _editFocusNutrients(BuildContext context, WidgetRef ref) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => const _FocusNutrientSheet(),
    );
  }
}

/// FR-U-09: up to three, because the dashboard has room for three and a
/// focus list of ten focuses on nothing.
class _FocusNutrientSheet extends ConsumerWidget {
  const _FocusNutrientSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    final selected = ref.watch(focusNutrientIdsProvider);
    final nutrients = ref.watch(allNutrientsProvider).value ?? const [];

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          NourishlySpace.s5,
          0,
          NourishlySpace.s5,
          NourishlySpace.s4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Focus nutrients', style: text.heading),
            const SizedBox(height: NourishlySpace.s1),
            Text(
              'Up to three, shown on the dashboard under water.',
              style: text.caption.copyWith(color: colors.ink3),
            ),
            const SizedBox(height: NourishlySpace.s3),
            Flexible(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: NourishlySpace.s2,
                  runSpacing: NourishlySpace.s2,
                  children: [
                    for (final nutrient in nutrients)
                      FilterChip(
                        label: Text(nutrient.displayName),
                        selected: selected.contains(nutrient.id),
                        onSelected: (on) async {
                          final next = [...selected];
                          if (on) {
                            if (next.length >= 3) next.removeAt(0);
                            next.add(nutrient.id);
                          } else {
                            next.remove(nutrient.id);
                          }
                          final ownerId = await ref.read(
                            defaultOwnerProvider.future,
                          );
                          await ref
                              .read(preferencesDaoProvider)
                              .update(ownerId, focusNutrientIds: next);
                          ref.read(summaryRevisionProvider.notifier).bump();
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Prototype 13A's "Your data": export, backup, and the destructive row.
///
/// The backup row is not a button — there is nothing to press. Android and
/// iOS back the app up on their own schedule (§0.5's mechanism 1), and the
/// honest thing to show is what that means, plus the one number the user
/// can actually act on: when they last took a copy of their own.
class _YourDataGroup extends ConsumerWidget {
  const _YourDataGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastExport = ref.watch(lastExportedAtProvider);

    return NourishlyRowGroup(
      children: [
        NourishlyListRow(
          title: 'Export everything',
          subtitle: 'JSON and CSV',
          onTap: () => context.push('/profile/data'),
        ),
        NourishlyListRow(
          title: 'Backup',
          subtitle: lastExport == null
              ? 'Automatic. No export of your own yet'
              : 'Automatic. You last exported '
                    '${_relativeDays(ref, lastExport)}',
          onTap: () => context.push('/profile/data'),
        ),
        // §30.7: deletion is two-step, offers export first, and says
        // plainly that it cannot be undone. Red is reserved for exactly
        // this (§21.8) — it is the one destructive action in the app.
        NourishlyListRow(
          title: 'Delete everything on this phone',
          style: NourishlyRowStyle.danger,
          onTap: () => context.push('/profile/data'),
        ),
      ],
    );
  }

  String _relativeDays(WidgetRef ref, DateTime at) {
    final days = ref.read(clockProvider).now().difference(at).inDays;
    return switch (days) {
      <= 0 => 'today',
      1 => 'yesterday',
      _ => '$days days ago',
    };
  }
}

/// The prototype's centred fine print — "Nourishly v1.0 · catalog 2026.09 ·
/// all data stays on this phone" — plus §21.8's signposting, which §27.13
/// requires somewhere and which reads as fine print rather than as a card
/// demanding to be read first.
class _AboutFooter extends ConsumerWidget {
  const _AboutFooter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    final catalog = ref.watch(catalogVersionProvider).value;
    return Padding(
      padding: const EdgeInsets.only(top: NourishlySpace.s6),
      child: Column(
        children: [
          Text(
            'Nourishly $appVersion'
            '${catalog == null ? '' : ' · catalog $catalog'}'
            ' · all data stays on this phone',
            textAlign: TextAlign.center,
            style: text.caption.copyWith(color: colors.ink3),
          ),
          const SizedBox(height: NourishlySpace.s2),
          Text(
            'Not suitable for managing a diagnosed condition or an eating '
            'disorder. A qualified professional is the right resource for '
            'that.',
            textAlign: TextAlign.center,
            style: text.caption.copyWith(color: colors.ink3, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(NourishlySpace.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, color: colors.danger, size: 28),
            const SizedBox(height: NourishlySpace.s3),
            Text(
              'Your settings could not be loaded.',
              style: text.body.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: NourishlySpace.s2),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: text.caption.copyWith(color: colors.ink3),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatMinutes(int minutes) {
  final hour = minutes ~/ 60;
  final minute = minutes % 60;
  final suffix = hour < 12 ? 'am' : 'pm';
  final displayHour = hour % 12 == 0 ? 12 : hour % 12;
  return '$displayHour:${minute.toString().padLeft(2, '0')} $suffix';
}

String _titleCase(String id) => [
  for (final word in id.split('_'))
    word.length <= 3 && word.startsWith('b')
        ? word.toUpperCase()
        : '${word[0].toUpperCase()}${word.substring(1)}',
].join(' ');
