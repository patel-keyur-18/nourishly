import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nourishly_data/nourishly_data.dart';
import 'package:nourishly_ui/nourishly_ui.dart';
import 'package:nutrition_core/nutrition_core.dart';

import '../../../../app/providers.dart';
import '../../../../shared/formatting.dart';
import '../../../profile/data/profile_providers.dart';

/// The prototype's ring card: the ring on the left, eaten/target/band on
/// the right.
///
/// With no energy target there is nothing to count down from, so the card
/// shows what was eaten and invites setup rather than drawing a ring
/// against an invented number (AP-4).
class EnergyCard extends StatelessWidget {
  const EnergyCard({super.key, required this.summary});

  final DaySummary summary;

  @override
  Widget build(BuildContext context) {
    final target = summary.energyTargetKcal;
    if (target == null || target <= 0) return _NoTargetCard(summary: summary);

    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    final band = summary.nutrient('energy');

    return NourishlyCard(
      child: Row(
        children: [
          EnergyRing(consumed: summary.totalEnergyKcal, target: target),
          const SizedBox(width: NourishlySpace.s4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _KeyValue(
                  label: 'Eaten',
                  value: _kcal(summary.totalEnergyKcal),
                ),
                _KeyValue(label: 'Target', value: _kcal(target)),
                const SizedBox(height: 2),
                // §27.2: the ring shows a target *band*, not a point,
                // because the underlying precision does not support a
                // point (§19.6). On its own line — paired with a label it
                // does not fit beside a 118px ring on a 390pt screen.
                Text(
                  'Band ${_kcal(target * 0.9)}\u2013${_kcal(target * 1.1)}',
                  style: text.caption.copyWith(color: colors.ink3),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (band != null && band.status == NutrientStatus.above)
                  Padding(
                    padding: const EdgeInsets.only(top: NourishlySpace.s2),
                    child: Text(
                      'Over the band for today.',
                      style: text.caption.copyWith(color: colors.ink3),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _kcal(double value) => formatThousands(value);
}

class _NoTargetCard extends StatelessWidget {
  const _NoTargetCard({required this.summary});

  final DaySummary summary;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    return NourishlyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${formatThousands(summary.totalEnergyKcal)} kcal',
            style: text.display.copyWith(height: 1.1),
          ),
          const SizedBox(height: NourishlySpace.s1),
          Text(
            'logged today',
            style: text.caption.copyWith(color: colors.ink3),
          ),
          const SizedBox(height: NourishlySpace.s3),
          Text(
            'Answer five questions and this becomes a target you can track '
            'against. Nothing is estimated until you do.',
            style: text.caption.copyWith(color: colors.ink2),
          ),
          const SizedBox(height: NourishlySpace.s3),
          FilledButton(
            onPressed: () => context.go('/profile/setup'),
            child: const Text('Personalise my targets'),
          ),
        ],
      ),
    );
  }
}

/// §27.2 item 3 — protein, carbs, fat and fibre, each with its target
/// marker. Horizontal bars rather than a macro pie, because a pie shows
/// proportion and cannot answer "am I short of protein" (§27.11).
class MacroCard extends StatelessWidget {
  const MacroCard({super.key, required this.summary});

  final DaySummary summary;

  static const _macros = ['protein', 'carbs', 'fat', 'fibre'];

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final rows = [
      for (final id in _macros)
        if (summary.nutrient(id) case final n? when n.targetAmount != null)
          NutrientBar(
            name: shortNutrientName(n.displayName),
            value: n.amount,
            target: n.targetAmount!,
            unit: n.unit,
            color: switch (id) {
              'protein' => colors.seriesProtein,
              'carbs' => colors.seriesCarbs,
              'fat' => colors.seriesFat,
              _ => colors.seriesFibre,
            },
          ),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return NourishlyCard(child: Column(children: rows));
  }
}

/// §27.2 item 4 — water with its quick-add chips inline, so hydration
/// never requires a trip to another tab.
class WaterCard extends ConsumerWidget {
  const WaterCard({super.key, required this.summary});

  final DaySummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.nourishlyColors;
    final target = summary.waterTargetMl;

    return NourishlyCard(
      child: Column(
        children: [
          if (target != null && target > 0)
            NutrientBar(
              name: 'Water',
              value: summary.waterMl / 1000,
              target: target / 1000,
              unit: 'L',
              color: colors.accent,
            )
          else
            _KeyValue(
              label: 'Water',
              value: '${(summary.waterMl / 1000).toStringAsFixed(1)} L',
            ),
          const SizedBox(height: NourishlySpace.s2),
          Row(
            children: [
              Expanded(
                child: QuickAddButton(
                  label: '+250 ml',
                  onPressed: () => _quickAdd(context, ref, 250),
                ),
              ),
              const SizedBox(width: NourishlySpace.s2),
              Expanded(
                child: QuickAddButton(
                  label: '+500 ml',
                  onPressed: () => _quickAdd(context, ref, 500),
                ),
              ),
              const SizedBox(width: NourishlySpace.s2),
              Expanded(
                child: QuickAddButton(
                  label: 'Custom',
                  onPressed: () => context.go('/water'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _quickAdd(BuildContext context, WidgetRef ref, double ml) async {
    final messenger = ScaffoldMessenger.of(context);
    final ownerId = await ref.read(defaultOwnerProvider.future);
    final dao = ref.read(waterLogDaoProvider);
    final entryId = await dao.logWater(
      ownerId: ownerId,
      volumeMl: ml,
      logDate: ref.read(selectedDateProvider),
    );
    ref.read(summaryRevisionProvider.notifier).bump();
    messenger.showSnackBar(
      SnackBar(
        content: Text('Logged ${ml.round()} ml'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await dao.undo(entryId);
            ref.read(summaryRevisionProvider.notifier).bump();
          },
        ),
      ),
    );
  }
}

/// §27.2 item 7's live status line, as the prototype's chip row: what is
/// on track, what is short, and how much of the day the micros actually
/// cover. Neutral wording throughout (§21.8) — no alarm colours, no
/// warning icons.
class StatusChipRow extends StatelessWidget {
  const StatusChipRow({super.key, required this.summary});

  final DaySummary summary;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];

    final protein = summary.nutrient('protein');
    if (protein?.targetAmount != null && protein!.hasData) {
      final met = protein.amount >= protein.targetAmount!;
      chips.add(
        StatusChip(
          label: met
              ? 'Protein on track'
              : 'Protein ${(protein.targetAmount! - protein.amount).round()} g short',
          status: met ? NourishlyStatus.ok : NourishlyStatus.low,
        ),
      );
    }

    final fibre = summary.nutrient('fibre');
    if (fibre?.targetAmount != null && fibre!.hasData) {
      final short = fibre.targetAmount! - fibre.amount;
      if (short > 1) {
        chips.add(
          StatusChip(
            label: 'Fibre ${short.round()} g short',
            status: NourishlyStatus.low,
          ),
        );
      }
    }

    final micros = summary.score.component(
      ScoreComponentKey.micronutrientCoverage,
    );
    if (micros != null && summary.entryCount > 0) {
      final covered = summary.nutrients
          .where((n) => _isMicro(n.nutrientId))
          .toList();
      if (covered.isNotEmpty) {
        final mean =
            covered.fold<double>(0, (a, n) => a + n.coverage) / covered.length;
        chips.add(
          StatusChip(
            label: 'Micros ${(mean * 100).round()}% covered',
            status: mean >= 0.6 ? NourishlyStatus.ok : NourishlyStatus.unknown,
          ),
        );
      }
    }

    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: NourishlySpace.s2,
      runSpacing: NourishlySpace.s2,
      children: chips,
    );
  }

  static bool _isMicro(String id) => !const {
    'energy',
    'protein',
    'carbs',
    'fat',
    'fibre',
    'sugar',
    'saturated_fat',
  }.contains(id);
}

/// §27.2 item 6 — the four slots with their energy totals and items. An
/// empty slot shows an inviting "+ Add" rather than an emptiness, which is
/// the difference between a screen that asks for something and one that
/// reports a lack.
class MealsCard extends ConsumerWidget {
  const MealsCard({super.key, required this.summary});

  final DaySummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;

    return NourishlyCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final meal in summary.meals)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => context.go('/log'),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    NourishlySpace.s4,
                    NourishlySpace.s3,
                    NourishlySpace.s4,
                    NourishlySpace.s3,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              meal.displayName,
                              style: text.body.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (meal.isEmpty)
                            Text(
                              '+ Add',
                              style: text.caption.copyWith(
                                color: colors.accent,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          else
                            Text(
                              formatThousands(meal.energyKcal),
                              style: text.body.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                      if (!meal.isEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          meal.itemNames.join(' · '),
                          style: text.caption.copyWith(color: colors.ink3),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _KeyValue extends StatelessWidget {
  const _KeyValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: text.caption.copyWith(color: colors.ink3)),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.body.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// §27.2 item 5 — up to three user-chosen nutrients, promoted onto the
/// dashboard (FR-U-09). Persona 3's screen: someone tracking iron or
/// sodium should not have to open the report to see it.
///
/// A focus nutrient with too little coverage says so rather than showing a
/// bar filled to a number the day cannot support (§21.5).
class FocusNutrientsCard extends ConsumerWidget {
  const FocusNutrientsCard({super.key, required this.summary});

  final DaySummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    final ids = ref.watch(focusNutrientIdsProvider);
    if (ids.isEmpty) return const SizedBox.shrink();

    final rows = <Widget>[];
    for (final id in ids) {
      final nutrient = summary.nutrient(id);
      if (nutrient == null) continue;
      if (!nutrient.hasData || nutrient.targetAmount == null) {
        rows.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: NourishlySpace.s2),
            child: Row(
              children: [
                SizedBox(
                  width: 58,
                  child: Text(
                    shortNutrientName(nutrient.displayName),
                    style: text.caption.copyWith(color: colors.ink2),
                  ),
                ),
                const SizedBox(width: NourishlySpace.s2),
                Expanded(
                  child: Text(
                    nutrient.targetAmount == null
                        ? 'No target set'
                        : 'Too little of today reports this',
                    style: text.caption.copyWith(color: colors.ink3),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }
      rows.add(
        NutrientBar(
          name: shortNutrientName(nutrient.displayName),
          value: nutrient.amount,
          target: nutrient.targetAmount!,
          unit: nutrient.unit,
          color: colors.statusUnknown,
        ),
      );
    }
    if (rows.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: NourishlySpace.s3),
      child: NourishlyCard(child: Column(children: rows)),
    );
  }
}
