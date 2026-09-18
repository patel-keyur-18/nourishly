import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nourishly_data/nourishly_data.dart';
import 'package:nourishly_ui/nourishly_ui.dart';

import '../../../profile/data/profile_providers.dart';
import '../../data/meal_plan_providers.dart';

/// Where a day lands if the rest of its plan is eaten — the reason the
/// week screen exists.
///
/// The solid part of each bar is what has actually been eaten; the hatched
/// part is the plan. A shortfall that shows here is one you can still fix
/// by changing the plan, which is the difference between this and the
/// daily report.
class PlanProjectionCard extends ConsumerWidget {
  const PlanProjectionCard({super.key, required this.date});

  final DateTime date;

  /// The four the household actually steers by, plus energy. Not the
  /// profile's focus nutrients: those are chosen for the dashboard, and
  /// the ones worth checking a *plan* against are the ones a plan can
  /// realistically move.
  static const _nutrients = ['protein', 'fibre', 'iron', 'folate', 'calcium'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    final projectionAsync = ref.watch(planProjectionProvider(date));
    final summaryAsync = ref.watch(daySummaryProvider(date));

    final projection = projectionAsync.value;
    final summary = summaryAsync.value;
    if (projection == null || summary == null) {
      return const SizedBox.shrink();
    }
    // `projectionFor` covers eaten entries too, so a day with meals logged
    // and nothing planned comes back full. Without this the card would
    // promise "if you eat this day" and then report on a day that already
    // happened — which is the daily report's job, not this card's.
    final hasPlan = projection.values.any((n) => n.planned > 0);
    if (!hasPlan) {
      return NourishlyCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'If you eat this day',
              style: text.overline.copyWith(color: colors.ink3),
            ),
            const SizedBox(height: NourishlySpace.s2),
            Text(
              'Plan a meal and this shows where the day lands against '
              'your targets.',
              style: text.caption.copyWith(color: colors.ink3),
            ),
          ],
        ),
      );
    }

    final energy = projection['energy'];
    final energyTarget = summary.energyTargetKcal;
    final rows = [
      for (final id in _nutrients)
        if (summary.nutrient(id) case final nutrient?)
          if (nutrient.targetAmount != null && nutrient.targetAmount! > 0)
            (nutrient, projection[id]),
    ];

    return NourishlyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'If you eat this day',
                  style: text.overline.copyWith(color: colors.ink3),
                ),
              ),
              Text(
                'solid eaten · hatched planned',
                style: text.caption.copyWith(color: colors.ink3),
              ),
            ],
          ),
          if (energy != null && energyTarget != null && energyTarget > 0) ...[
            const SizedBox(height: NourishlySpace.s3),
            _EnergyLine(
              eaten: energy.eaten,
              planned: energy.planned,
              target: energyTarget,
            ),
          ],
          const SizedBox(height: NourishlySpace.s2),
          for (final (nutrient, projected) in rows)
            NutrientBar(
              name: nutrient.displayName,
              value: projected?.eaten ?? nutrient.amount,
              planned: projected?.planned ?? 0,
              target: nutrient.targetAmount!,
              unit: nutrient.unit,
              color: _colorFor(nutrient.nutrientId, colors),
            ),
          if (rows.isNotEmpty) ...[
            const SizedBox(height: NourishlySpace.s2),
            _ShortfallNote(rows: rows),
          ],
        ],
      ),
    );
  }

  static Color _colorFor(String nutrientId, NourishlyColors colors) =>
      switch (nutrientId) {
        'protein' => colors.seriesProtein,
        'carbs' => colors.seriesCarbs,
        'fat' => colors.seriesFat,
        'fibre' => colors.seriesFibre,
        _ => colors.accent,
      };
}

class _EnergyLine extends StatelessWidget {
  const _EnergyLine({
    required this.eaten,
    required this.planned,
    required this.target,
  });

  final double eaten;
  final double planned;
  final double target;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    final projected = eaten + planned;
    final remaining = target - projected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '${projected.round()}',
                style: text.numeral.copyWith(fontSize: 26),
              ),
              TextSpan(
                text: ' of ${target.round()} kcal',
                style: text.caption.copyWith(color: colors.ink3),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          // Stated as a direction rather than a signed number: "260 under"
          // is read correctly at a glance, "-260" is not.
          remaining.abs() < 25
              ? 'The plan lands on your energy target'
              : remaining > 0
              ? '${remaining.round()} kcal under target if the plan holds'
              : '${remaining.abs().round()} kcal over target if the plan holds',
          style: text.caption.copyWith(color: colors.ink2),
        ),
      ],
    );
  }
}

/// The one sentence that turns the bars into a decision.
class _ShortfallNote extends StatelessWidget {
  const _ShortfallNote({required this.rows});

  final List<(SummaryNutrient, ProjectedNutrient?)> rows;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;

    final short = <String>[];
    for (final (nutrient, projected) in rows) {
      final target = nutrient.targetAmount!;
      final total =
          (projected?.eaten ?? nutrient.amount) + (projected?.planned ?? 0);
      if (total / target < 0.8) short.add(nutrient.displayName.toLowerCase());
    }
    if (short.isEmpty) {
      return Row(
        children: [
          const StatusChip(label: 'On track', status: NourishlyStatus.ok),
          const SizedBox(width: NourishlySpace.s2),
          Expanded(
            child: Text(
              'The plan reaches every target here.',
              style: text.caption.copyWith(color: colors.ink3),
            ),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StatusChip(label: 'Short', status: NourishlyStatus.low),
        const SizedBox(width: NourishlySpace.s2),
        Expanded(
          child: Text(
            'Even with the plan, ${_list(short)} ${short.length == 1 ? 'stays' : 'stay'} '
            'under 80% of target. Change the plan while you still can.',
            style: text.caption.copyWith(color: colors.ink2),
          ),
        ),
      ],
    );
  }

  static String _list(List<String> items) => switch (items.length) {
    1 => items.single,
    2 => '${items.first} and ${items.last}',
    _ => '${items.sublist(0, items.length - 1).join(', ')} and ${items.last}',
  };
}
