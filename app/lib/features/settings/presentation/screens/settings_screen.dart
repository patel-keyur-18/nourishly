import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nourishly_data/nourishly_data.dart' hide NutrientTarget;
import 'package:nourishly_ui/nourishly_ui.dart';

import '../../../../app/providers.dart';
import '../../../profile/data/profile_providers.dart';

/// Settings (prototype screen 13) — the Profile tab's root.
///
/// Everything here is a preference the spec names: units (FR-U-07), week
/// start and day rollover (FR-U-08), focus nutrients (FR-U-09), weight as
/// a series (FR-U-14), and §21.8's two safety toggles — the score is
/// dismissible, and energy can be hidden.
///
/// Export, deletion and reminders are Phase 5 and are deliberately absent
/// rather than stubbed: a settings row that does nothing is worse than one
/// that is not there.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferencesAsync = ref.watch(preferencesProvider);
    final profileName = ref.watch(profileDisplayNameProvider).value;
    final profile = ref.watch(currentProfileProvider).value;
    final weights = ref.watch(bodyWeightHistoryProvider).value ?? const [];
    final manualOnly = ref.watch(manualTargetsOnlyProvider).value ?? false;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: preferencesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('$error')),
          data: (preferences) => ListView(
            padding: const EdgeInsets.fromLTRB(
              NourishlySpace.s4,
              NourishlySpace.s4,
              NourishlySpace.s4,
              NourishlySpace.s7,
            ),
            children: [
              Text('Profile', style: context.nourishlyText.title),

              const NourishlySectionHeader(label: 'You'),
              NourishlyCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _NavRow(
                      title: 'Name',
                      value: profileName ?? 'You',
                      onTap: () => _renameProfile(context, ref, profileName),
                    ),
                    _NavRow(
                      title: 'Body and activity',
                      value: profile == null
                          ? 'Not set up'
                          : '${profile.heightCm.round()} cm · '
                                '${profile.weightKg.round()} kg',
                      onTap: () => context.go('/profile/setup'),
                    ),
                    _NavRow(
                      title: 'Diet',
                      value:
                          DietaryPreference.fromId(
                            preferences.dietaryPreference,
                          )?.label ??
                          'Not said',
                      subtitle: 'Orders search results. Hides nothing.',
                      onTap: () => _editDiet(context, ref, preferences),
                    ),
                    _NavRow(
                      title: 'Goals & targets',
                      value: manualOnly ? 'Manual' : 'Derived',
                      onTap: () => context.go('/profile/goals'),
                    ),
                    _NavRow(
                      title: 'Your recipes',
                      value: '',
                      subtitle:
                          'Dishes built from their ingredients, loggable '
                          'like any other food.',
                      onTap: () => context.push('/recipes'),
                    ),
                  ],
                ),
              ),

              NourishlySectionHeader(
                label: 'Weight',
                trailing: weights.isEmpty
                    ? null
                    : '${weights.first.weightKg.toStringAsFixed(1)} kg',
              ),
              _WeightCard(entries: weights),

              const NourishlySectionHeader(label: 'What you see'),
              NourishlyCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    // §21.8: the score is fully dismissible, leaving the
                    // raw data and the insights.
                    _SwitchRow(
                      title: 'Show the daily score',
                      subtitle:
                          'Turn this off to keep the numbers and the '
                          'insights without a score anywhere.',
                      value: preferences.showScore,
                      onChanged: (v) => _update(ref, showScore: v),
                    ),
                    // §21.8: for tracking nutrients without calories.
                    _SwitchRow(
                      title: 'Hide energy',
                      subtitle:
                          'Hides the calorie ring and the energy row. '
                          'Everything else keeps working.',
                      value: preferences.hideEnergy,
                      onChanged: (v) => _update(ref, hideEnergy: v),
                    ),
                    _NavRow(
                      title: 'Focus nutrients',
                      value: _focusSummary(ref),
                      onTap: () => _editFocusNutrients(context, ref),
                    ),
                  ],
                ),
              ),

              const NourishlySectionHeader(label: 'Units and the day'),
              NourishlyCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _NavRow(
                      title: 'Units',
                      value: preferences.unitSystem == 'metric'
                          ? 'Metric (kg, cm, ml)'
                          : 'Imperial (lb, ft/in, fl oz)',
                      onTap: () => _update(
                        ref,
                        unitSystem: preferences.unitSystem == 'metric'
                            ? 'imperial'
                            : 'metric',
                      ),
                    ),
                    _NavRow(
                      title: 'Week starts on',
                      value: preferences.weekStartDay == DateTime.sunday
                          ? 'Sunday'
                          : 'Monday',
                      onTap: () => _update(
                        ref,
                        weekStartDay:
                            preferences.weekStartDay == DateTime.sunday
                            ? DateTime.monday
                            : DateTime.sunday,
                      ),
                    ),
                    _NavRow(
                      title: 'Day rolls over at',
                      value: _formatMinutes(preferences.dayRolloverTime),
                      subtitle:
                          'A late dinner belongs to the day you ate it, not '
                          'to the calendar.',
                      onTap: () => _editRollover(context, ref, preferences),
                    ),
                  ],
                ),
              ),

              const NourishlySectionHeader(label: 'About'),
              const _AboutCard(),
            ],
          ),
        ),
      ),
    );
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
        );
    ref.read(summaryRevisionProvider.notifier).bump();
  }

  Future<void> _renameProfile(
    BuildContext context,
    WidgetRef ref,
    String? current,
  ) async {
    final controller = TextEditingController(text: current ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final ownerId = await ref.read(defaultOwnerProvider.future);
    await ref.read(preferencesDaoProvider).renameProfile(ownerId, name);
    ref.read(summaryRevisionProvider.notifier).bump();
    ref.invalidate(profileDisplayNameProvider);
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

  Future<void> _editDiet(
    BuildContext context,
    WidgetRef ref,
    UserPreference preferences,
  ) async {
    final current = DietaryPreference.fromId(preferences.dietaryPreference);
    final choice = await showModalBottomSheet<Object?>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // A plain list rather than RadioListTile: the sheet closes on
            // the tap, so there is no group state for a RadioGroup to hold.
            for (final preference in DietaryPreference.values)
              ListTile(
                title: Text(preference.label),
                trailing: preference == current
                    ? Icon(
                        Icons.check_rounded,
                        color: context.nourishlyColors.accent,
                      )
                    : null,
                onTap: () => Navigator.of(context).pop(preference),
              ),
            ListTile(
              title: const Text('Prefer not to say'),
              onTap: () => Navigator.of(context).pop('clear'),
            ),
            const SizedBox(height: NourishlySpace.s3),
          ],
        ),
      ),
    );
    if (choice == null) return;
    final ownerId = await ref.read(defaultOwnerProvider.future);
    await ref
        .read(preferencesDaoProvider)
        .update(
          ownerId,
          dietaryPreference: choice is DietaryPreference ? choice.id : null,
          clearDietaryPreference: choice == 'clear',
        );
    ref.read(summaryRevisionProvider.notifier).bump();
  }

  Future<void> _editFocusNutrients(BuildContext context, WidgetRef ref) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          NourishlySpace.s4,
          0,
          NourishlySpace.s4,
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

/// FR-U-14 — weight as a series, never a verdict (§21.8): no BMI, no
/// category, just the numbers and when they were taken.
class _WeightCard extends ConsumerWidget {
  const _WeightCard({required this.entries});

  final List<BodyWeightEntry> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;

    return NourishlyCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                NourishlySpace.s4,
                NourishlySpace.s3,
                NourishlySpace.s4,
                NourishlySpace.s1,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Nothing recorded yet.',
                  style: text.caption.copyWith(color: colors.ink3),
                ),
              ),
            )
          else
            for (final entry in entries.take(5))
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: NourishlySpace.s4,
                  vertical: NourishlySpace.s2,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDate(entry.recordedAt),
                      style: text.caption.copyWith(color: colors.ink3),
                    ),
                    Text(
                      '${entry.weightKg.toStringAsFixed(1)} kg',
                      style: text.body.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              NourishlySpace.s4,
              NourishlySpace.s2,
              NourishlySpace.s4,
              NourishlySpace.s3,
            ),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _record(context, ref),
                child: const Text("Record today's weight"),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _record(BuildContext context, WidgetRef ref) async {
    final profile = ref.read(currentProfileProvider).value;
    final controller = TextEditingController(
      text:
          (entries.isNotEmpty
                  ? entries.first.weightKg
                  : profile?.weightKg ?? 70)
              .toStringAsFixed(1),
    );
    final messenger = ScaffoldMessenger.of(context);
    final entered = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Weight today'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(suffixText: 'kg'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final weight = double.tryParse(entered ?? '');
    if (weight == null || weight <= 0) return;

    final ownerId = await ref.read(defaultOwnerProvider.future);
    final newTargets = await ref
        .read(bodyWeightDaoProvider)
        .record(ownerId: ownerId, weightKg: weight);
    ref.read(summaryRevisionProvider.notifier).bump();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          newTargets == null
              ? 'Recorded ${weight.toStringAsFixed(1)} kg.'
              : 'Recorded ${weight.toStringAsFixed(1)} kg. Your targets '
                    'follow it from today; past days keep theirs.',
        ),
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    return NourishlyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Everything stays on this phone. There is no account and no '
            'server.',
            style: text.caption.copyWith(color: colors.ink2, height: 1.5),
          ),
          const SizedBox(height: NourishlySpace.s3),
          // §21.8's signposting: plain, and not alarmist.
          Text(
            'Nourishly is not suitable for managing a diagnosed condition '
            'or an eating disorder. A qualified professional is the right '
            'resource for that.',
            style: text.caption.copyWith(color: colors.ink3, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.title,
    required this.value,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final String value;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: NourishlySpace.s4,
            vertical: NourishlySpace.s3,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: text.body),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: text.caption.copyWith(color: colors.ink3),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: NourishlySpace.s2),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.caption.copyWith(color: colors.ink3),
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 20, color: colors.ink3),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
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
                Text(title, style: text.body),
                Text(
                  subtitle,
                  style: text.caption.copyWith(color: colors.ink3, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: NourishlySpace.s2),
          Switch(value: value, onChanged: onChanged),
        ],
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

String _formatDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]}';
}

String _titleCase(String id) => [
  for (final word in id.split('_'))
    word.length <= 3 && word.startsWith('b')
        ? word.toUpperCase()
        : '${word[0].toUpperCase()}${word.substring(1)}',
].join(' ');
