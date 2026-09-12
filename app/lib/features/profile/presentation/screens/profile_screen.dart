import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nourishly_data/nourishly_data.dart' hide NutrientTarget;
import 'package:nourishly_ui/nourishly_ui.dart';
import 'package:nutrition_core/nutrition_core.dart';

import '../../../../app/providers.dart';
import '../../data/profile_editor.dart';
import '../../data/profile_providers.dart';
import '../profile_labels.dart';

/// Who you are, what your body is doing, how you eat, and what you are
/// aiming at — on one screen, reached from Settings.
///
/// Added by the 2026-09-12 UX revision, which split this out of prototype
/// 13A's Settings screen. Settings had become the place where *everything*
/// about a profile lived, which made it long, made the genuinely
/// settings-like rows (units, week start, rollover) hard to find, and put
/// five unrelated ideas under one title.
///
/// The rule that makes this screen worth having: **every row edits in
/// place.** Tapping "Height" asks for a height; it does not re-run setup.
/// Setup is a first-run flow, and a six-step wizard is the wrong tool for
/// correcting one number — which is what it had become.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final preferencesAsync = ref.watch(preferencesProvider);
    final name = ref.watch(profileDisplayNameProvider).value ?? 'You';
    final goal = ref.watch(currentGoalProvider).value;
    final weights = ref.watch(bodyWeightHistoryProvider).value ?? const [];
    final today = ref.watch(todayProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorBody(error: error),
        data: (profile) {
          final preferences = preferencesAsync.value;
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              NourishlySpace.s4,
              NourishlySpace.s3,
              NourishlySpace.s4,
              NourishlySpace.s7,
            ),
            children: [
              _IdentityCard(
                name: name,
                profile: profile,
                goal: goal == null ? null : GoalType.fromId(goal.goalType),
                today: today,
              ),

              const NourishlySectionHeader(label: 'You'),
              NourishlyRowGroup(
                children: [
                  NourishlyListRow(
                    title: 'Name',
                    value: name,
                    onTap: () => _editName(context, ref, name),
                  ),
                  NourishlyListRow(
                    title: 'Date of birth',
                    value: profile == null
                        ? 'Not set'
                        : _formatDate(profile.dateOfBirth),
                    subtitle: profile == null
                        ? null
                        : '${ageFromDateOfBirth(profile.dateOfBirth, now: today)} '
                              'years old',
                    onTap: profile == null
                        ? null
                        : () => _editDateOfBirth(context, ref, profile),
                  ),
                  NourishlyListRow(
                    title: 'Reference values',
                    // Never "sex: unset". The app asks which reference
                    // tables to use, and declining is an answer (§27.1).
                    value: switch (BiologicalSex.fromId(
                      profile?.biologicalSex,
                    )) {
                      BiologicalSex.female => 'Female',
                      BiologicalSex.male => 'Male',
                      null => 'Neutral',
                    },
                    onTap: profile == null
                        ? null
                        : () => _editReference(context, ref, profile),
                  ),
                ],
              ),

              const NourishlySectionHeader(label: 'Body'),
              NourishlyRowGroup(
                children: [
                  NourishlyListRow(
                    title: 'Height',
                    value: profile == null
                        ? 'Not set'
                        : '${profile.heightCm.round()} cm',
                    onTap: profile == null
                        ? null
                        : () => _editHeight(context, ref, profile),
                  ),
                  NourishlyListRow(
                    title: 'Weight',
                    value: profile == null
                        ? 'Not set'
                        : '${profile.weightKg.toStringAsFixed(1)} kg',
                    subtitle: 'Kept as a series, never overwritten.',
                    onTap: () => _recordWeight(context, ref, weights, profile),
                  ),
                ],
              ),
              if (weights.length > 1) ...[
                const SizedBox(height: NourishlySpace.s2),
                _WeightHistoryCard(entries: weights),
              ],

              const NourishlySectionHeader(label: 'Activity and goal'),
              NourishlyRowGroup(
                children: [
                  NourishlyListRow(
                    title: 'Activity',
                    value: profile == null
                        ? 'Not set'
                        : ProfileLabels.activity(
                            ActivityLevel.fromId(profile.activityLevel),
                          ),
                    subtitle: profile == null
                        ? null
                        : ActivityLevel.fromId(
                            profile.activityLevel,
                          ).description,
                    onTap: profile == null
                        ? null
                        : () => _editActivity(context, ref, profile),
                  ),
                  NourishlyListRow(
                    title: 'Goal',
                    value: goal == null
                        ? 'Not set'
                        : GoalType.fromId(goal.goalType).label,
                    onTap: profile == null
                        ? null
                        : () => _editGoal(context, ref, goal),
                  ),
                  NourishlyListRow(
                    title: 'Goals & targets',
                    subtitle: 'Every target, and a way to set your own.',
                    onTap: () => context.push('/profile/goals'),
                  ),
                ],
              ),

              const NourishlySectionHeader(label: 'Diet'),
              NourishlyRowGroup(
                children: [
                  NourishlyListRow(
                    title: 'Dietary preference',
                    value:
                        DietaryPreference.fromId(
                          preferences?.dietaryPreference,
                        )?.label ??
                        'Not said',
                    subtitle: 'Orders search results. Hides nothing.',
                    onTap: preferences == null
                        ? null
                        : () => _editDiet(context, ref, preferences),
                  ),
                ],
              ),

              if (profile == null) ...[
                const SizedBox(height: NourishlySpace.s5),
                const _NoProfileCard(),
              ],
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Editors. Each one changes a single field and returns to this screen —
  // no wizard, no redirect, no "Use these targets" at the end.
  // ---------------------------------------------------------------------

  Future<void> _editName(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final name = await showNourishlyPrompt(
      context: context,
      title: 'Your name',
      message: 'Shown on the dashboard, and nowhere else.',
      initialValue: current == 'You' ? '' : current,
      label: 'Name',
      hint: 'Name',
      textCapitalization: TextCapitalization.words,
    );
    if (name == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(profileEditorProvider).rename(name);
    showNourishlySnackOn(messenger, 'Name saved.');
  }

  Future<void> _editDateOfBirth(
    BuildContext context,
    WidgetRef ref,
    UserProfileVersion profile,
  ) async {
    final now = ref.read(clockProvider).now();
    final picked = await showDatePicker(
      context: context,
      initialDate: profile.dateOfBirth,
      firstDate: DateTime(1920),
      lastDate: now,
      helpText: 'Date of birth',
    );
    if (picked == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(profileEditorProvider).setDateOfBirth(picked);
    showNourishlySnackOn(messenger, 'Date of birth saved.');
  }

  Future<void> _editReference(
    BuildContext context,
    WidgetRef ref,
    UserProfileVersion profile,
  ) async {
    final current = BiologicalSex.fromId(profile.biologicalSex);
    final choice = await showNourishlyOptions<String>(
      context: context,
      title: 'Reference values',
      message:
          'Recommended intakes for iron, calcium and a few others differ. '
          'Declining uses a neutral reference rather than defaulting to '
          'either.',
      selected: current?.id ?? 'neutral',
      options: const [
        NourishlyOption(value: 'female', label: 'Female'),
        NourishlyOption(value: 'male', label: 'Male'),
        NourishlyOption(
          value: 'neutral',
          label: 'Prefer not to say',
          subtitle: 'Uses a neutral reference',
        ),
      ],
    );
    if (choice == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await ref
        .read(profileEditorProvider)
        .setBiologicalSex(
          choice == 'neutral' ? null : BiologicalSex.fromId(choice),
        );
    showNourishlySnackOn(messenger, 'Reference values saved.');
  }

  Future<void> _editHeight(
    BuildContext context,
    WidgetRef ref,
    UserProfileVersion profile,
  ) async {
    final entered = await showNourishlyPrompt(
      context: context,
      title: 'Your height',
      initialValue: profile.heightCm.round().toString(),
      label: 'Height',
      suffix: 'cm',
      numeric: true,
      validator: (value) {
        final cm = double.tryParse(value);
        return cm != null && cm >= 90 && cm <= 230;
      },
      helper: 'Between 90 and 230 cm.',
    );
    final height = double.tryParse(entered ?? '');
    if (height == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(profileEditorProvider).setHeightCm(height);
    showNourishlySnackOn(
      messenger,
      'Height saved. Your targets follow it from today; past days keep '
      'theirs.',
    );
  }

  Future<void> _recordWeight(
    BuildContext context,
    WidgetRef ref,
    List<BodyWeightEntry> entries,
    UserProfileVersion? profile,
  ) async {
    final latest = entries.isNotEmpty
        ? entries.first.weightKg
        : profile?.weightKg;
    final entered = await showNourishlyPrompt(
      context: context,
      title: 'Weight today',
      message:
          'Recorded as of today. Nothing already reported is rewritten — '
          'each day keeps the targets it was measured against.',
      initialValue: latest?.toStringAsFixed(1),
      label: 'Weight',
      suffix: 'kg',
      numeric: true,
      validator: (value) {
        final kg = double.tryParse(value);
        return kg != null && kg >= 20 && kg <= 300;
      },
      helper: 'Between 20 and 300 kg.',
    );
    final weight = double.tryParse(entered ?? '');
    if (weight == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final newTargets = await ref
        .read(profileEditorProvider)
        .recordWeight(weight);
    showNourishlySnackOn(
      messenger,
      newTargets == null
          ? 'Recorded ${weight.toStringAsFixed(1)} kg.'
          : 'Recorded ${weight.toStringAsFixed(1)} kg. Your targets follow '
                'it from today; past days keep theirs.',
    );
  }

  Future<void> _editActivity(
    BuildContext context,
    WidgetRef ref,
    UserProfileVersion profile,
  ) async {
    final choice = await showNourishlyOptions<ActivityLevel>(
      context: context,
      title: 'How active are you on a normal day?',
      message: 'Pick the description that matches, not the one you are '
          'aiming for.',
      selected: ActivityLevel.fromId(profile.activityLevel),
      options: [
        for (final level in ActivityLevel.values)
          NourishlyOption(
            value: level,
            label: ProfileLabels.activity(level),
            subtitle: level.description,
          ),
      ],
    );
    if (choice == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(profileEditorProvider).setActivityLevel(choice);
    showNourishlySnackOn(
      messenger,
      'Activity saved. Your energy target follows it from today.',
    );
  }

  Future<void> _editGoal(
    BuildContext context,
    WidgetRef ref,
    Goal? goal,
  ) async {
    final choice = await showNourishlyOptions<GoalType>(
      context: context,
      title: 'What are you tracking for?',
      message: 'This changes what the daily score weighs most heavily.',
      selected: goal == null ? null : GoalType.fromId(goal.goalType),
      options: [
        for (final type in GoalType.values)
          NourishlyOption(
            value: type,
            label: type.label,
            subtitle: ProfileLabels.goalSubtitle(type),
          ),
      ],
    );
    if (choice == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(profileEditorProvider).setGoal(choice);
    // §27.12's sentence, verbatim: this is what makes the history
    // trustworthy in the user's eyes as well as in the data (I-3).
    showNourishlySnackOn(
      messenger,
      'This applies from today. Your past reports keep the targets they '
      'were measured against.',
    );
  }

  Future<void> _editDiet(
    BuildContext context,
    WidgetRef ref,
    UserPreference preferences,
  ) async {
    final choice = await showNourishlyOptions<String>(
      context: context,
      title: 'Do you eat to a particular diet?',
      message:
          'This only changes the order of search results. Nothing is ever '
          'hidden, and it stays on this phone like everything else.',
      selected: preferences.dietaryPreference ?? 'none_stated',
      options: [
        for (final preference in DietaryPreference.values)
          NourishlyOption(
            value: preference.id,
            label: preference.label,
            subtitle: ProfileLabels.dietSubtitle(preference),
          ),
        const NourishlyOption(value: 'none_stated', label: 'Prefer not to say'),
      ],
    );
    if (choice == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await ref
        .read(profileEditorProvider)
        .setDietaryPreference(
          choice == 'none_stated' ? null : DietaryPreference.fromId(choice),
        );
    showNourishlySnackOn(messenger, 'Diet saved.');
  }
}

/// The prototype's `.prof` block from option 13B, which was the one part of
/// the unchosen option worth keeping: an avatar, a name, and the one line
/// that says what this profile is set up for.
class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.name,
    required this.profile,
    required this.goal,
    required this.today,
  });

  final String name;
  final UserProfileVersion? profile;
  final GoalType? goal;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;

    final details = [
      if (goal != null) goal!.label,
      if (profile != null) '${profile!.heightCm.round()} cm',
      if (profile != null) '${profile!.weightKg.toStringAsFixed(1)} kg',
      if (profile != null)
        '${ageFromDateOfBirth(profile!.dateOfBirth, now: today)} years',
    ];

    return NourishlyCard(
      child: Row(
        children: [
          NourishlyAvatar(name: name, size: 44),
          const SizedBox(width: NourishlySpace.s4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: text.heading),
                const SizedBox(height: 2),
                Text(
                  details.isEmpty ? 'Nothing set up yet' : details.join(' · '),
                  style: text.caption.copyWith(
                    color: colors.ink3,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// FR-U-14 — weight as a series, never a verdict (§21.8): no BMI, no
/// category, just the numbers and when they were taken.
class _WeightHistoryCard extends StatelessWidget {
  const _WeightHistoryCard({required this.entries});

  final List<BodyWeightEntry> entries;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;

    return NourishlyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent weights',
            style: text.label.copyWith(color: colors.ink2),
          ),
          const SizedBox(height: NourishlySpace.s2),
          for (final entry in entries.take(6))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
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
        ],
      ),
    );
  }
}

/// §27.1: a skipped setup is a working app, not an error. The invitation
/// stays available and says what it buys, without nagging.
class _NoProfileCard extends StatelessWidget {
  const _NoProfileCard();

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    return NourishlyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nothing set up yet',
            style: text.body.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: NourishlySpace.s2),
          Text(
            'Answer five questions once and every screen gains something to '
            'measure against. You can change any single answer here '
            'afterwards, one at a time.',
            style: text.caption.copyWith(color: colors.ink3, height: 1.5),
          ),
          const SizedBox(height: NourishlySpace.s4),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => context.push('/profile/setup'),
              child: const Text('Set up my profile'),
            ),
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
              'Your profile could not be loaded.',
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

String _formatDate(DateTime date) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}
