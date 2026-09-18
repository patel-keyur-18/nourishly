import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nourishly_data/nourishly_data.dart' hide DailyScore;
import 'package:nourishly_ui/nourishly_ui.dart';
import 'package:nutrition_core/nutrition_core.dart';

import '../../../../shared/formatting.dart';
import '../../../profile/data/profile_providers.dart';

/// The daily report (prototype screen 9, option C — full table).
///
/// §27.8's order, and the order matters: the verdict comes first because
/// most people read only that, the score decomposes immediately below it
/// because §21.6 forbids a composite without its parts, and the nutrient
/// table is the whole day in one scan.
class DailyReportScreen extends ConsumerWidget {
  const DailyReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(selectedDaySummaryProvider);
    final date = ref.watch(selectedDateProvider);
    final showScore = ref.watch(showScoreProvider);

    return Scaffold(
      appBar: AppBar(title: Text(formatLongDate(date))),
      body: summaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (summary) => ListView(
          padding: const EdgeInsets.fromLTRB(
            NourishlySpace.s4,
            NourishlySpace.s3,
            NourishlySpace.s4,
            NourishlySpace.s7,
          ),
          children: [
            _VerdictCard(summary: summary, showScore: showScore),
            if (showScore) ...[
              const NourishlySectionHeader(label: 'How the score is made up'),
              _SubScoreCard(score: summary.score),
            ],
            NourishlySectionHeader(
              label: 'Every nutrient',
              trailing:
                  '${formatThousands(summary.totalEnergyKcal)} of '
                  '${summary.energyTargetKcal == null ? '\u2014' : formatThousands(summary.energyTargetKcal!)} kcal',
            ),
            _NutrientTable(summary: summary),
            if (summary.insights.isNotEmpty) ...[
              const NourishlySectionHeader(label: 'What to do about it'),
              _InsightsCard(insights: summary.insights),
            ],
            const NourishlySectionHeader(label: 'Across the day'),
            _MealBreakdown(summary: summary),
          ],
        ),
      ),
    );
  }
}

/// §27.8 items 1-2: one sentence, then the band and the composite — or the
/// withheld reason, stated plainly.
class _VerdictCard extends StatelessWidget {
  const _VerdictCard({required this.summary, required this.showScore});

  final DaySummary summary;
  final bool showScore;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    final score = summary.score;

    return NourishlyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_verdict(summary), style: text.body.copyWith(height: 1.45)),
          if (showScore) ...[
            const SizedBox(height: NourishlySpace.s3),
            if (score.isWithheld)
              // The reason is the verdict sentence directly above;
              // repeating the whole thing in a chip only truncates it.
              StatusChip(
                label: switch (score.withheldReason!) {
                  ScoreWithheldReason.dayIncomplete => 'Not scored yet',
                  ScoreWithheldReason.looksIncompletelyLogged =>
                    'Not scored \u2014 partly logged',
                  ScoreWithheldReason.nothingLogged => 'Nothing logged',
                  ScoreWithheldReason.noTargets => 'No targets set',
                  ScoreWithheldReason.allComponentsExcluded =>
                    'Not enough data',
                },
                status: NourishlyStatus.unknown,
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    score.band!.label,
                    style: text.caption.copyWith(
                      color: colors.ink2,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(width: NourishlySpace.s3),
                  Text(
                    '${score.composite!.round()}',
                    style: text.display.copyWith(height: 1),
                  ),
                  Text(
                    '/100',
                    style: text.caption.copyWith(color: colors.ink3),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  /// One sentence, assembled from whole clauses rather than fragments
  /// (§27.14) and inside §21.7's language boundary — it describes the day
  /// against the user's own targets and never judges it.
  static String _verdict(DaySummary summary) {
    if (summary.entryCount == 0) {
      return 'Nothing was logged on this day.';
    }
    if (summary.score.withheldReason ==
        ScoreWithheldReason.looksIncompletelyLogged) {
      return 'The total for this day is well under your usual, so it looks '
          'like something is missing rather than that you ate this little.';
    }
    if (summary.score.withheldReason == ScoreWithheldReason.dayIncomplete) {
      return 'Today is still going. Here is where it stands so far.';
    }
    if (summary.score.withheldReason == ScoreWithheldReason.noTargets) {
      return 'Here is the day as logged. Set up your targets and it becomes '
          'something to measure against.';
    }

    final short =
        summary.nutrients
            .where(
              (n) =>
                  n.hasData &&
                  n.status == NutrientStatus.below &&
                  n.targetAmount != null,
            )
            .toList()
          ..sort((a, b) => (a.pctOfTarget ?? 0).compareTo(b.pctOfTarget ?? 0));
    final over = summary.nutrients
        .where((n) => n.hasData && n.status == NutrientStatus.above)
        .toList();

    if (short.isEmpty && over.isEmpty) {
      return 'Everything landed inside its target range today.';
    }
    if (short.isEmpty) {
      return '${over.first.displayName} came in above its limit; everything '
          'else landed where you wanted it.';
    }
    if (over.isEmpty) {
      return 'A solid day, with ${short.first.displayName.toLowerCase()} the '
          'one that fell short.';
    }
    return '${short.first.displayName} fell short and '
        '${over.first.displayName.toLowerCase()} came in above its limit.';
  }
}

/// §27.8 item 3 — each sub-score with its weight, its value, and any
/// exclusion reason. §21.4 requires the exclusions to be stated, not
/// quietly absorbed.
class _SubScoreCard extends StatelessWidget {
  const _SubScoreCard({required this.score});

  final DailyScore score;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;

    // §21.4's order, which is the order the weights are explained in.
    // Reading them back from the database returns them in insertion order,
    // which is not it.
    final ordered = [...score.components]
      ..sort((a, b) => a.key.index.compareTo(b.key.index));

    return NourishlyCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final component in ordered)
            // FR-D-03: every score is explainable, and tapping it shows
            // exactly what contributed.
            _Tappable(
              onTap: () => _explainComponent(context, component),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  NourishlySpace.s4,
                  NourishlySpace.s2,
                  NourishlySpace.s4,
                  NourishlySpace.s2,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(component.key.label, style: text.body),
                          Text(
                            component.wasExcluded
                                ? _exclusionLabel(component.exclusion!)
                                : '${(component.appliedWeight * 100).round()}% of the score',
                            style: text.caption.copyWith(color: colors.ink3),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: NourishlySpace.s2),
                    Text(
                      component.wasExcluded
                          ? '—'
                          : '${component.score!.round()}',
                      style: text.heading.copyWith(
                        color: component.wasExcluded ? colors.ink3 : colors.ink,
                      ),
                    ),
                    const SizedBox(width: NourishlySpace.s1),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: colors.ink3,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _exclusionLabel(ScoreExclusion exclusion) =>
      switch (exclusion) {
        ScoreExclusion.insufficientCoverage =>
          'Not enough of the day reports these',
        ScoreExclusion.noTarget => 'No target set',
        ScoreExclusion.noData => 'Nothing logged for this',
      };
}

/// §27.8 items 7-8 as the prototype's `.nt` rows: every tracked nutrient
/// against its target in one scan, with coverage stated and unknowns
/// rendered as "—" rather than zero (AP-4).
class _NutrientTable extends StatelessWidget {
  const _NutrientTable({required this.summary});

  final DaySummary summary;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    final noData = summary.nutrients.where((n) => !n.hasData).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NourishlyCard(
          padding: const EdgeInsets.symmetric(vertical: NourishlySpace.s1),
          child: Column(
            children: [
              for (final nutrient in summary.nutrients)
                _NutrientRow(nutrient: nutrient),
            ],
          ),
        ),
        if (noData.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              NourishlySpace.s1,
              NourishlySpace.s2,
              NourishlySpace.s1,
              0,
            ),
            child: Text(
              noData.length == 1
                  ? '${noData.single.displayName} shows no data rather than '
                        'zero — too little of today’s food reports it.'
                  : '${noData.length} nutrients show no data rather than '
                        'zero — too little of today’s food reports them.',
              style: text.caption.copyWith(color: colors.ink3),
            ),
          ),
      ],
    );
  }
}

class _NutrientRow extends ConsumerWidget {
  const _NutrientRow({required this.nutrient});

  final SummaryNutrient nutrient;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    final pct = nutrient.pctOfTarget;

    final (label, status) = switch (nutrient.status) {
      NutrientStatus.insufficientData => ('None', NourishlyStatus.unknown),
      NutrientStatus.below => ('Short', NourishlyStatus.low),
      NutrientStatus.above => ('Over', NourishlyStatus.high),
      NutrientStatus.within => ('On', NourishlyStatus.ok),
    };

    return Semantics(
      // §27.11: the text alternative states the conclusion, not the
      // coordinates.
      label: nutrient.hasData
          ? '${nutrient.displayName}: ${_amount(nutrient)}'
                '${pct == null ? '' : ' of target, ${pct.round()}%'}, $label'
          : '${nutrient.displayName}: no data',
      // FR-D-03's second tap: from a number to the foods behind it.
      child: _Tappable(
        onTap: () => _explainNutrient(context, ref, nutrient),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: NourishlySpace.s4,
            vertical: NourishlySpace.s2,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 66,
                child: Text(
                  shortNutrientName(nutrient.displayName),
                  style: text.caption.copyWith(color: colors.ink2),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: NourishlySpace.s2),
              Expanded(
                child: SizedBox(
                  height: NourishlyStroke.bar,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.track,
                          borderRadius: BorderRadius.circular(
                            NourishlyStroke.bar,
                          ),
                        ),
                      ),
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        // A row that will not state its amount does not draw
                        // a bar for it either: a filled track next to "—"
                        // implies a quantity the row has just declined to
                        // give (AP-4).
                        widthFactor: nutrient.hasData
                            ? ((pct ?? 0) / 100).clamp(0.0, 1.0)
                            : 0.0,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: switch (status) {
                              NourishlyStatus.high => colors.statusHigh,
                              NourishlyStatus.unknown => colors.statusUnknown,
                              NourishlyStatus.low => colors.statusLow,
                              _ => colors.accent,
                            },
                            borderRadius: BorderRadius.circular(
                              NourishlyStroke.bar,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: NourishlySpace.s2),
              SizedBox(
                width: 76,
                child: Text(
                  nutrient.hasData ? _amount(nutrient) : '—',
                  textAlign: TextAlign.right,
                  style: text.caption.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: NourishlySpace.s2),
              SizedBox(
                width: 62,
                child: StatusChip(label: label, status: status, dense: true),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _amount(SummaryNutrient n) {
    final rendered = n.amount >= 10
        ? formatThousands(n.amount)
        : n.amount.toStringAsFixed(1);
    return '$rendered ${n.unit}';
  }
}

class _InsightsCard extends StatelessWidget {
  const _InsightsCard({required this.insights});

  final List<Insight> insights;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;

    return NourishlyCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final insight in insights)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                NourishlySpace.s4,
                NourishlySpace.s3,
                NourishlySpace.s4,
                NourishlySpace.s3,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 3,
                    height: 34,
                    margin: const EdgeInsets.only(
                      right: NourishlySpace.s3,
                      top: 2,
                    ),
                    decoration: BoxDecoration(
                      color: switch (insight.category) {
                        InsightCategory.celebrate => colors.statusOk,
                        InsightCategory.caution => colors.statusHigh,
                        InsightCategory.suggest => colors.accent,
                        InsightCategory.dataQuality => colors.statusUnknown,
                        InsightCategory.inform => colors.statusLow,
                      },
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      insight.text,
                      style: text.caption.copyWith(
                        color: colors.ink2,
                        height: 1.5,
                      ),
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

/// §27.8 item 10 — a horizontal stacked bar of the day's meals plus the
/// per-slot totals. §27.11 prefers this over a donut: compact, comparable
/// across days, and the labels fit.
class _MealBreakdown extends StatelessWidget {
  const _MealBreakdown({required this.summary});

  final DaySummary summary;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    final withFood = summary.meals.where((m) => m.energyKcal > 0).toList();
    final total = withFood.fold<double>(0, (a, m) => a + m.energyKcal);

    return NourishlyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (total > 0) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(NourishlyStroke.bar),
              child: SizedBox(
                height: NourishlyStroke.bar,
                child: Row(
                  children: [
                    for (var i = 0; i < withFood.length; i++)
                      Expanded(
                        flex: (withFood[i].energyKcal / total * 1000).round(),
                        child: ColoredBox(
                          color: _slotColors(
                            colors,
                          )[i % _slotColors(colors).length],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: NourishlySpace.s3),
          ],
          for (final meal in summary.meals)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    meal.displayName,
                    style: text.caption.copyWith(color: colors.ink3),
                  ),
                  Text(
                    meal.isEmpty
                        ? 'Nothing logged'
                        : '${formatThousands(meal.energyKcal)} kcal',
                    style: text.caption.copyWith(
                      fontWeight: meal.isEmpty
                          ? FontWeight.w400
                          : FontWeight.w700,
                      color: meal.isEmpty ? colors.ink3 : colors.ink,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static List<Color> _slotColors(NourishlyColors colors) => [
    colors.seriesProtein,
    colors.seriesCarbs,
    colors.seriesFat,
    colors.seriesFibre,
  ];
}

/// A row that responds to a tap without changing how it looks — the report
/// is a table, and giving every row a button's chrome would bury the
/// numbers it exists to show.
class _Tappable extends StatelessWidget {
  const _Tappable({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: child),
    );
  }
}

/// FR-D-03 for a sub-score: its value, its weight, the curve behind it and
/// why it was excluded if it was.
void _explainComponent(BuildContext context, ScoredComponent component) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final colors = context.nourishlyColors;
      final text = context.nourishlyText;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            NourishlySpace.s4,
            0,
            NourishlySpace.s4,
            NourishlySpace.s6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(component.key.label, style: text.heading),
              const SizedBox(height: NourishlySpace.s3),
              _ExplainRow(
                label: 'Score',
                value: component.wasExcluded
                    ? 'Not scored'
                    : '${component.score!.round()} / 100',
              ),
              _ExplainRow(
                label: 'Weight in the ruleset',
                value: '${(component.weight * 100).round()}%',
              ),
              _ExplainRow(
                label: 'Weight applied today',
                value: component.wasExcluded
                    ? '0% — excluded'
                    : '${(component.appliedWeight * 100).round()}%',
              ),
              const SizedBox(height: NourishlySpace.s3),
              Text(
                component.wasExcluded
                    ? _exclusionExplanation(component.exclusion!)
                    : _componentExplanation(component.key),
                style: text.caption.copyWith(color: colors.ink3, height: 1.5),
              ),
            ],
          ),
        ),
      );
    },
  );
}

String _componentExplanation(ScoreComponentKey key) => switch (key) {
  ScoreComponentKey.energyAdherence =>
    'Energy is scored against a range, not a point: eating well under the '
        'band costs points just as eating well over it does.',
  ScoreComponentKey.macroBalance =>
    'Protein, fibre, fat and carbohydrate, weighted within this component. '
        'Each is capped at its target — exceeding one cannot make up for '
        'missing another.',
  ScoreComponentKey.micronutrientCoverage =>
    'The average of the micronutrients that enough of the day reported. '
        'Ones below the coverage threshold are left out rather than guessed '
        'at.',
  ScoreComponentKey.limitNutrients =>
    'Sodium, added sugar and saturated fat. Full credit up to the limit, '
        'decaying above it.',
  ScoreComponentKey.hydration =>
    'Water against your daily target. More than the target earns no extra '
        'credit.',
};

String _exclusionExplanation(ScoreExclusion exclusion) => switch (exclusion) {
  ScoreExclusion.insufficientCoverage =>
    'Too little of what you logged reports these nutrients to say anything '
        'useful, so this component was left out and its weight was shared '
        'across the others.',
  ScoreExclusion.noTarget =>
    'There is no target to measure this against yet. Its weight was shared '
        'across the components that do have one.',
  ScoreExclusion.noData =>
    'Nothing logged today carries this, so there was nothing to score. Its '
        'weight was shared across the others.',
};

/// FR-D-03 for a nutrient: the foods that supplied it, largest first.
void _explainNutrient(
  BuildContext context,
  WidgetRef ref,
  SummaryNutrient nutrient,
) {
  final date = ref.read(selectedDateProvider);
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _NutrientSheet(nutrient: nutrient, date: date),
  );
}

class _NutrientSheet extends ConsumerWidget {
  const _NutrientSheet({required this.nutrient, required this.date});

  final SummaryNutrient nutrient;
  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    final contributors = ref.watch(
      nutrientContributorsProvider((
        date: date,
        nutrientId: nutrient.nutrientId,
      )),
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          NourishlySpace.s4,
          0,
          NourishlySpace.s4,
          NourishlySpace.s6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(nutrient.displayName, style: text.heading),
            const SizedBox(height: NourishlySpace.s3),
            _ExplainRow(
              label: 'Logged',
              value: nutrient.hasData
                  ? '${_round(nutrient.amount)} ${nutrient.unit}'
                  : 'Not enough data',
            ),
            if (nutrient.targetAmount != null)
              _ExplainRow(
                label: 'Target',
                value: '${_round(nutrient.targetAmount!)} ${nutrient.unit}',
              ),
            _ExplainRow(
              label: 'Coverage',
              value:
                  '${(nutrient.coverage * 100).round()}% of the day\u2019s energy',
            ),
            const SizedBox(height: NourishlySpace.s4),
            Text(
              'Where it came from',
              style: text.caption.copyWith(
                color: colors.ink3,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: NourishlySpace.s2),
            contributors.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(NourishlySpace.s3),
                child: LinearProgressIndicator(),
              ),
              error: (error, _) => Text('$error', style: text.caption),
              data: (rows) => rows.isEmpty
                  ? Text(
                      'Nothing logged today reports this nutrient.',
                      style: text.caption.copyWith(color: colors.ink3),
                    )
                  : Column(
                      children: [
                        for (final row in rows.take(8))
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(row.foodName, style: text.body),
                                      Text(
                                        '${row.mealName} \u00b7 '
                                        '${row.gramsConsumed.round()} g',
                                        style: text.caption.copyWith(
                                          color: colors.ink3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${_round(row.amount)} ${nutrient.unit}',
                                  style: text.body.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static String _round(double v) =>
      v >= 10 ? formatThousands(v) : v.toStringAsFixed(1);
}

class _ExplainRow extends StatelessWidget {
  const _ExplainRow({required this.label, required this.value});

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
              textAlign: TextAlign.right,
              style: text.body.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
