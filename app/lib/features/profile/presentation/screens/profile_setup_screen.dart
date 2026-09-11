import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nourishly_data/nourishly_data.dart' hide NutrientTarget;
import 'package:nourishly_ui/nourishly_ui.dart';
import 'package:nutrition_core/nutrition_core.dart';

import '../../../../app/providers.dart';
import '../../data/profile_providers.dart';

/// Profile setup (prototype screen 2, option A — one question per step).
///
/// Five steps, and §27.1's rule holds at every one of them: **skippable**,
/// prominently, not hidden. A skipped profile is a working app with
/// generic targets, so nothing here is a gate.
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  static const _stepCount = 6;

  int _step = 0;
  DateTime _dateOfBirth = DateTime(1992, 3, 14);
  BiologicalSex? _sex = BiologicalSex.male;
  bool _sexDeclined = false;
  double _heightCm = 174;
  double _weightKg = 71;
  ActivityLevel _activity = ActivityLevel.light;
  GoalType _goal = GoalType.generalHealth;
  DietaryPreference? _diet;
  bool _saving = false;

  int get _age => _ageFrom(_dateOfBirth);

  ProfileInputs get _inputs => ProfileInputs(
    ageYears: _age,
    heightCm: _heightCm,
    weightKg: _weightKg,
    activityLevel: _activity,
    biologicalSex: _sexDeclined ? null : _sex,
  );

  DerivedTargets get _preview => deriveTargets(profile: _inputs, goal: _goal);

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final router = GoRouter.of(context);
    final ownerId = await ref.read(defaultOwnerProvider.future);
    await ref
        .read(profileDaoProvider)
        .saveProfileAndDeriveTargets(
          ownerId: ownerId,
          inputs: _inputs,
          dateOfBirth: _dateOfBirth,
          goal: _goal,
        );
    await ref
        .read(preferencesDaoProvider)
        .update(
          ownerId,
          dietaryPreference: _diet?.id,
          clearDietaryPreference: _diet == null,
          onboardingSeen: true,
        );
    ref.read(summaryRevisionProvider.notifier).bump();
    if (mounted) router.go('/today');
  }

  void _next() {
    if (_step == _stepCount - 1) {
      _save();
    } else {
      setState(() => _step++);
    }
  }

  void _back() {
    if (_step == 0) {
      context.go('/today');
    } else {
      setState(() => _step--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _back,
          tooltip: 'Back',
        ),
        title: const Text('About you'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: NourishlySpace.s4),
              child: Text(
                '${_step + 1} of $_stepCount',
                style: text.caption.copyWith(color: colors.ink3),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  NourishlySpace.s4,
                  NourishlySpace.s4,
                  NourishlySpace.s4,
                  NourishlySpace.s4,
                ),
                children: [
                  switch (_step) {
                    0 => _birthStep(),
                    1 => _bodyStep(),
                    2 => _activityStep(),
                    3 => _goalStep(),
                    4 => _dietStep(),
                    _ => _targetsStep(),
                  },
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                NourishlySpace.s4,
                0,
                NourishlySpace.s4,
                NourishlySpace.s4,
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saving ? null : _next,
                      child: Text(
                        _step == _stepCount - 1
                            ? (_saving ? 'Saving…' : 'Use these targets')
                            : 'Continue',
                      ),
                    ),
                  ),
                  // §27.1: skip is prominent at every step, not hidden.
                  TextButton(
                    onPressed: _saving ? null : () => context.go('/today'),
                    child: const Text('Skip for now'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _birthStep() => _Step(
    question: 'When were you born?',
    subtitle: 'Recommended intakes for several nutrients change with age.',
    children: [
      _FieldTile(
        label: 'Date of birth',
        value:
            '${_dateOfBirth.day} ${_monthName(_dateOfBirth.month)} '
            '${_dateOfBirth.year}',
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: _dateOfBirth,
            firstDate: DateTime(1920),
            lastDate: DateTime.now(),
          );
          if (picked != null) setState(() => _dateOfBirth = picked);
        },
      ),
      _Hint('$_age years old'),
      const SizedBox(height: NourishlySpace.s5),
      _SubQuestion(
        title: 'Which reference values should we use?',
        subtitle:
            'Recommended intakes for iron, calcium and a few others '
            'differ. You can skip this.',
      ),
      _ChoiceTile(
        title: 'Female',
        selected: !_sexDeclined && _sex == BiologicalSex.female,
        onTap: () => setState(() {
          _sex = BiologicalSex.female;
          _sexDeclined = false;
        }),
      ),
      _ChoiceTile(
        title: 'Male',
        selected: !_sexDeclined && _sex == BiologicalSex.male,
        onTap: () => setState(() {
          _sex = BiologicalSex.male;
          _sexDeclined = false;
        }),
      ),
      _ChoiceTile(
        title: 'Prefer not to say',
        subtitle: 'Uses a neutral reference',
        selected: _sexDeclined,
        onTap: () => setState(() => _sexDeclined = true),
      ),
    ],
  );

  Widget _bodyStep() => _Step(
    question: 'Your height and weight',
    subtitle:
        'These set your energy and protein targets more than anything else.',
    children: [
      _SliderField(
        label: 'Height',
        value: _heightCm,
        min: 120,
        max: 210,
        unit: 'cm',
        onChanged: (v) => setState(() => _heightCm = v),
      ),
      _SliderField(
        label: 'Weight',
        value: _weightKg,
        min: 30,
        max: 180,
        unit: 'kg',
        onChanged: (v) => setState(() => _weightKg = v),
      ),
      const SizedBox(height: NourishlySpace.s4),
      const _NoteBox(
        'You can update your weight any time. Past reports keep the '
        'targets they were measured against.',
      ),
    ],
  );

  Widget _activityStep() => _Step(
    question: 'How active are you on a normal day?',
    subtitle:
        'Pick the description that matches, not the one you are aiming for.',
    children: [
      for (final level in ActivityLevel.values)
        _ChoiceTile(
          title: _activityTitle(level),
          subtitle: level.description,
          selected: _activity == level,
          onTap: () => setState(() => _activity = level),
        ),
    ],
  );

  Widget _goalStep() => _Step(
    question: 'What are you tracking for?',
    subtitle: 'This changes what the score weighs most heavily.',
    children: [
      for (final goal in GoalType.values)
        _ChoiceTile(
          title: goal.label,
          subtitle: _goalSubtitle(goal),
          selected: _goal == goal,
          onTap: () => setState(() => _goal = goal),
        ),
    ],
  );

  /// FR-U-16. Skippable like every other step, and framed as what it
  /// actually does — it changes the order of search results, not what the
  /// app will let you log.
  Widget _dietStep() => _Step(
    question: 'Do you eat to a particular diet?',
    subtitle:
        'This only changes the order of search results, so what you eat '
        'most comes up first. Nothing is ever hidden, and you can skip '
        'this.',
    children: [
      for (final preference in DietaryPreference.values)
        _ChoiceTile(
          title: preference.label,
          subtitle: _dietSubtitle(preference),
          selected: _diet == preference,
          onTap: () =>
              setState(() => _diet = _diet == preference ? null : preference),
        ),
      const _NoteBox(
        'Kept on this phone like everything else, and used only to rank '
        'search results.',
      ),
    ],
  );

  static String? _dietSubtitle(DietaryPreference preference) =>
      switch (preference) {
        // Said plainly rather than implied: the catalog records neither
        // root vegetables nor slaughter method, so these two order results
        // the same way their nearest recorded neighbour does.
        DietaryPreference.jain =>
          'Ranked as vegetarian — the catalog does not record root '
              'vegetables',
        DietaryPreference.halal =>
          'The catalog does not record slaughter method, so this does not '
              'reorder anything',
        _ => null,
      };

  /// §27.1: the targets screen explains *why*, once, in one sentence.
  Widget _targetsStep() {
    final derived = _preview;
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;

    return _Step(
      question: 'Here are your targets',
      subtitle:
          'Based on your height, weight, age, activity and goal, we have set '
          '${derived.energyKcal.round()} kcal and '
          '${derived.targets['protein']!.amount.round()} g of protein a day. '
          'You can change any of these later.',
      children: [
        if (derived.safetyFloorApplied)
          const _NoteBox(
            'Your goal would have put the energy target below the minimum '
            'this app will set, so it has been raised to that minimum.',
          ),
        NourishlyCard(
          child: Column(
            children: [
              _TargetRow(
                label: 'Energy',
                value: '${derived.energyKcal.round()} kcal',
              ),
              _TargetRow(
                label: 'Protein',
                value: '${derived.targets['protein']!.amount.round()} g',
              ),
              _TargetRow(
                label: 'Carbs',
                value: '${derived.targets['carbs']!.amount.round()} g',
              ),
              _TargetRow(
                label: 'Fat',
                value: '${derived.targets['fat']!.amount.round()} g',
              ),
              _TargetRow(
                label: 'Fibre',
                value: '${derived.targets['fibre']!.amount.round()} g',
              ),
              _TargetRow(
                label: 'Water',
                value: '${(derived.waterTargetMl / 1000).toStringAsFixed(1)} L',
              ),
            ],
          ),
        ),
        const SizedBox(height: NourishlySpace.s3),
        Text(
          'Micronutrient targets come from the ICMR-NIN reference tables for '
          'your age and reference values, and appear on the goals screen.',
          style: text.caption.copyWith(color: colors.ink3),
        ),
      ],
    );
  }

  static String _activityTitle(ActivityLevel level) => switch (level) {
    ActivityLevel.sedentary => 'Not very',
    ActivityLevel.light => 'A little',
    ActivityLevel.moderate => 'Moderately',
    ActivityLevel.active => 'Very',
    ActivityLevel.veryActive => 'Extremely',
  };

  static String _goalSubtitle(GoalType goal) => switch (goal) {
    GoalType.maintain => 'Keep things where they are',
    GoalType.loseWeight => 'A bounded deficit, never an aggressive one',
    GoalType.gainWeight => 'A bounded surplus',
    GoalType.gainMuscle => 'More protein, and the score weighs it heavier',
    GoalType.generalHealth => 'Balanced targets, nothing pushed',
    GoalType.hydration => 'Water only — no nutrition setup needed',
  };
}

int _ageFrom(DateTime dob) {
  final now = DateTime.now();
  var age = now.year - dob.year;
  if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
    age -= 1;
  }
  return age;
}

String _monthName(int month) => const [
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
][month - 1];

class _Step extends StatelessWidget {
  const _Step({
    required this.question,
    required this.subtitle,
    required this.children,
  });

  final String question;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(question, style: text.title),
        const SizedBox(height: NourishlySpace.s2),
        Text(
          subtitle,
          style: text.caption.copyWith(color: colors.ink3, height: 1.5),
        ),
        const SizedBox(height: NourishlySpace.s4),
        ...children,
      ],
    );
  }
}

class _SubQuestion extends StatelessWidget {
  const _SubQuestion({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: text.body.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: NourishlySpace.s1),
        Text(
          subtitle,
          style: text.caption.copyWith(color: colors.ink3, height: 1.5),
        ),
        const SizedBox(height: NourishlySpace.s3),
      ],
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    return Padding(
      padding: const EdgeInsets.only(bottom: NourishlySpace.s2),
      child: Material(
        color: selected ? colors.accentSoft : colors.surface,
        borderRadius: BorderRadius.circular(NourishlyRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(NourishlyRadius.md),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(NourishlyRadius.md),
              border: Border.all(
                color: selected ? colors.accent : colors.line,
                width: selected
                    ? NourishlyStroke.tick
                    : NourishlyStroke.hairline,
              ),
            ),
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
                      Text(
                        title,
                        style: text.body.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: text.caption.copyWith(color: colors.ink3),
                        ),
                      ],
                    ],
                  ),
                ),
                if (selected)
                  Icon(Icons.check_rounded, size: 20, color: colors.accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldTile extends StatelessWidget {
  const _FieldTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(NourishlyRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(NourishlyRadius.md),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(NourishlyRadius.md),
            border: Border.all(color: colors.line),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: NourishlySpace.s4,
            vertical: NourishlySpace.s3,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: text.caption.copyWith(color: colors.ink3)),
              Text(
                value,
                style: text.body.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SliderField extends StatelessWidget {
  const _SliderField({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final String unit;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    return Padding(
      padding: const EdgeInsets.only(bottom: NourishlySpace.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: text.caption.copyWith(color: colors.ink3)),
              Text('${value.round()} $unit', style: text.heading),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: (max - min).round(),
            label: '${value.round()} $unit',
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: NourishlySpace.s2,
        left: NourishlySpace.s1,
      ),
      child: Text(
        text,
        style: context.nourishlyText.caption.copyWith(
          color: context.nourishlyColors.ink3,
        ),
      ),
    );
  }
}

class _NoteBox extends StatelessWidget {
  const _NoteBox(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    return Container(
      margin: const EdgeInsets.only(bottom: NourishlySpace.s3),
      padding: const EdgeInsets.all(NourishlySpace.s3),
      decoration: BoxDecoration(
        color: colors.accentSoft,
        borderRadius: BorderRadius.circular(NourishlyRadius.md),
      ),
      child: Text(
        text,
        style: context.nourishlyText.caption.copyWith(
          color: colors.accentSoftInk,
          height: 1.5,
        ),
      ),
    );
  }
}

class _TargetRow extends StatelessWidget {
  const _TargetRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: NourishlySpace.s2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: text.body.copyWith(color: colors.ink2)),
          Text(value, style: text.body.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
