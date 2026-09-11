import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nourishly_data/nourishly_data.dart' hide NutrientTarget;
import 'package:nourishly_ui/nourishly_ui.dart';
import 'package:nutrition_core/nutrition_core.dart';

import '../../../../app/providers.dart';
import '../../../../shared/formatting.dart';
import '../../../profile/data/profile_providers.dart';

/// Goals and targets (prototype screen 12, option B — card per target).
///
/// The six headline targets get a card each with its reasoning and a
/// slider; the micronutrients are a compact list. Every change writes a
/// **new** effective-dated target set and says so — §27.12 calls that
/// sentence the user-facing expression of I-3, and it is what makes the
/// history trustworthy in the user's eyes as well as in the data.
class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  static const _headline = [
    'energy',
    'protein',
    'fibre',
    'water',
    'carbs',
    'fat',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider);
    final targetsAsync = ref.watch(targetsForDateProvider(today));
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Goals & targets')),
      body: targetsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (targets) {
          if (targets.isEmpty) return const _NoTargetsYet();
          final profile = profileAsync.value;
          final micros =
              targets.keys.where((id) => !_headline.contains(id)).toList()
                ..sort();

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              NourishlySpace.s4,
              NourishlySpace.s2,
              NourishlySpace.s4,
              NourishlySpace.s7,
            ),
            children: [
              const NourishlySectionHeader(label: 'The six you look at'),
              for (final id in _headline)
                if (targets[id] case final target?)
                  _TargetCard(nutrientId: id, target: target, profile: profile),
              NourishlySectionHeader(
                label: 'Micronutrients',
                trailing: '${micros.length} tracked',
              ),
              _MicroList(ids: micros, targets: targets),
              const NourishlySectionHeader(label: 'How targets are set'),
              const _ManualTargetsCard(),
              const SizedBox(height: NourishlySpace.s4),
              const _EffectiveDatingNote(),
              const SizedBox(height: NourishlySpace.s2),
              OutlinedButton(
                onPressed: () => context.go('/profile/setup'),
                child: const Text('Change my profile or goal'),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Q-27's manual-targets-only mode, as §0.3 scopes it: a should-have on
/// top of FR-U-05's per-target overrides, which already cover most of the
/// need.
///
/// It is the override mechanism applied to every target at once, not a
/// second code path: turning it on freezes today's numbers as user-set, so
/// a weight or goal change stops recomputing them.
class _ManualTargetsCard extends ConsumerWidget {
  const _ManualTargetsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    final manualOnly = ref.watch(manualTargetsOnlyProvider).value ?? false;

    return NourishlyCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Set my own targets',
                  style: text.body.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  manualOnly
                      ? 'Your targets stay where you put them. Changing your '
                            'weight or goal records the change but does not '
                            'move them.'
                      : 'Targets follow your profile. Turn this on to keep '
                            'them exactly where you set them instead.',
                  style: text.caption.copyWith(color: colors.ink3, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: NourishlySpace.s2),
          Switch(
            value: manualOnly,
            onChanged: (enabled) async {
              final ownerId = await ref.read(defaultOwnerProvider.future);
              await ref
                  .read(profileDaoProvider)
                  .setManualTargetsOnly(ownerId: ownerId, enabled: enabled);
              ref.read(summaryRevisionProvider.notifier).bump();
            },
          ),
        ],
      ),
    );
  }
}

class _EffectiveDatingNote extends StatelessWidget {
  const _EffectiveDatingNote();

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    return Container(
      padding: const EdgeInsets.all(NourishlySpace.s3),
      decoration: BoxDecoration(
        color: colors.accentSoft,
        borderRadius: BorderRadius.circular(NourishlyRadius.md),
      ),
      child: Text(
        'Changes apply from today. Your past reports keep the targets they '
        'were measured against.',
        style: context.nourishlyText.caption.copyWith(
          color: colors.accentSoftInk,
          height: 1.5,
        ),
      ),
    );
  }
}

class _TargetCard extends ConsumerStatefulWidget {
  const _TargetCard({
    required this.nutrientId,
    required this.target,
    required this.profile,
  });

  final String nutrientId;
  final NutrientTarget target;
  final UserProfileVersion? profile;

  @override
  ConsumerState<_TargetCard> createState() => _TargetCardState();
}

class _TargetCardState extends ConsumerState<_TargetCard> {
  double? _draft;

  double get _value => _draft ?? widget.target.amount;

  Future<void> _commit() async {
    final draft = _draft;
    if (draft == null) return;
    final ownerId = await ref.read(defaultOwnerProvider.future);
    await ref
        .read(profileDaoProvider)
        .overrideTarget(
          ownerId: ownerId,
          nutrientId: widget.nutrientId,
          amount: draft,
        );
    ref.read(summaryRevisionProvider.notifier).bump();
    if (mounted) setState(() => _draft = null);
  }

  Future<void> _reset() async {
    final profile = widget.profile;
    if (profile == null) return;
    final ownerId = await ref.read(defaultOwnerProvider.future);
    final goalRow = ref.read(currentGoalProvider).value;
    await ref
        .read(profileDaoProvider)
        .resetTargetToDerived(
          ownerId: ownerId,
          nutrientId: widget.nutrientId,
          inputs: ProfileInputs(
            ageYears: ageInYears(profile.dateOfBirth),
            heightCm: profile.heightCm,
            weightKg: profile.weightKg,
            activityLevel: ActivityLevel.fromId(profile.activityLevel),
            biologicalSex: BiologicalSex.fromId(profile.biologicalSex),
          ),
          goal: goalRow == null
              ? GoalType.generalHealth
              : GoalType.fromId(goalRow.goalType),
        );
    ref.read(summaryRevisionProvider.notifier).bump();
    if (mounted) setState(() => _draft = null);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    final unit = _unitFor(widget.nutrientId);
    final display = widget.nutrientId == 'water'
        ? (_value / 1000).toStringAsFixed(1)
        : formatThousands(_value);

    return Padding(
      padding: const EdgeInsets.only(bottom: NourishlySpace.s3),
      child: NourishlyCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _label(widget.nutrientId),
                    style: text.body.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                StatusChip(
                  label: widget.target.isUserOverride
                      ? 'You set this'
                      : 'Derived',
                  status: widget.target.isUserOverride
                      ? NourishlyStatus.unknown
                      : NourishlyStatus.ok,
                  dense: true,
                ),
              ],
            ),
            const SizedBox(height: NourishlySpace.s2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(display, style: text.display.copyWith(height: 1)),
                const SizedBox(width: 4),
                Text(unit, style: text.caption.copyWith(color: colors.ink3)),
              ],
            ),
            Slider(
              value: _value.clamp(
                _min(widget.nutrientId),
                _max(widget.nutrientId),
              ),
              min: _min(widget.nutrientId),
              max: _max(widget.nutrientId),
              onChanged: (v) => setState(() => _draft = v),
              onChangeEnd: (_) => _commit(),
            ),
            Text(
              _reasonFor(widget.nutrientId, widget.target),
              style: text.caption.copyWith(color: colors.ink3, height: 1.5),
            ),
            if (widget.target.isUserOverride && widget.profile != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _reset,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Reset to derived'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _label(String id) => switch (id) {
    'energy' => 'Energy',
    'protein' => 'Protein',
    'fibre' => 'Fibre',
    'water' => 'Water',
    'carbs' => 'Carbs',
    'fat' => 'Fat',
    _ => id,
  };

  static String _unitFor(String id) => switch (id) {
    'energy' => 'kcal',
    'water' => 'L',
    _ => 'g',
  };

  static double _min(String id) => switch (id) {
    'energy' => 1000,
    'water' => 1000,
    _ => 0,
  };

  static double _max(String id) => switch (id) {
    'energy' => 4500,
    'water' => 6000,
    'carbs' => 600,
    'protein' => 250,
    'fat' => 200,
    _ => 80,
  };

  /// The sentence under each target, which is the point of this screen:
  /// §27.12 wants control over targets *without* needing to understand the
  /// derivation, and that only works if the derivation explains itself.
  static String _reasonFor(String id, NutrientTarget target) {
    if (target.isUserOverride) {
      return 'You set this yourself. It stays put when your profile changes.';
    }
    return switch (id) {
      'energy' =>
        'Mifflin-St Jeor from your height, weight and age, times your '
            'activity level.',
      'protein' => 'Per kg of body weight, for your goal.',
      'fibre' => '14 g per 1,000 kcal.',
      'water' => '35 ml per kg of body weight, plus a little for activity.',
      'fat' => '27.5% of your energy target — the middle of the 20-35% range.',
      'carbs' => 'Whatever energy is left after protein and fat.',
      _ => 'Derived from your profile.',
    };
  }
}

class _MicroList extends StatefulWidget {
  const _MicroList({required this.ids, required this.targets});

  final List<String> ids;
  final Map<String, NutrientTarget> targets;

  @override
  State<_MicroList> createState() => _MicroListState();
}

class _MicroListState extends State<_MicroList> {
  /// The prototype shows four and a "Show all" row: the full list is
  /// eighteen entries a person looks at once a year, below six they change.
  static const _collapsedCount = 4;

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    final targets = widget.targets;
    final ids = _expanded
        ? widget.ids
        : widget.ids.take(_collapsedCount).toList();

    return NourishlyCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final id in ids)
            Padding(
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
                        Text(_titleCase(id), style: text.body),
                        Text(
                          _source(id, targets[id]!),
                          style: text.caption.copyWith(color: colors.ink3),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${_round(targets[id]!.amount)} ${_unit(id)}',
                    style: text.caption.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          if (widget.ids.length > _collapsedCount)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: NourishlySpace.s4,
                    vertical: NourishlySpace.s3,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _expanded
                          ? 'Show fewer'
                          : 'Show all ${widget.ids.length}',
                      style: text.caption.copyWith(
                        color: colors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _source(String id, NutrientTarget target) {
    if (target.isUserOverride) return 'You set this';
    return switch (target.curveType) {
      TargetCurveType.ceiling when id == 'sodium' => 'Upper limit, WHO',
      TargetCurveType.ceiling => 'Upper limit, WHO guidance on energy share',
      _ => 'ICMR-NIN 2020',
    };
  }

  static String _titleCase(String id) {
    final words = id.split('_');
    return [
      for (final w in words)
        w.startsWith('b') && w.length <= 3
            ? w.toUpperCase()
            : '${w[0].toUpperCase()}${w.substring(1)}',
    ].join(' ');
  }

  static String _unit(String id) => switch (id) {
    'vitamin_a' || 'vitamin_d' || 'vitamin_b12' || 'folate' => 'µg',
    'sugar' || 'saturated_fat' => 'g',
    _ => 'mg',
  };

  static String _round(double value) =>
      value >= 10 ? formatThousands(value) : value.toStringAsFixed(1);
}

class _NoTargetsYet extends StatelessWidget {
  const _NoTargetsYet();

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
            Text(
              'No targets yet',
              style: text.heading,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: NourishlySpace.s2),
            Text(
              'Answer five questions and every screen gains something to '
              'measure against.',
              textAlign: TextAlign.center,
              style: text.caption.copyWith(color: colors.ink3, height: 1.5),
            ),
            const SizedBox(height: NourishlySpace.s4),
            FilledButton(
              onPressed: () => context.go('/profile/setup'),
              child: const Text('Set up my targets'),
            ),
          ],
        ),
      ),
    );
  }
}
