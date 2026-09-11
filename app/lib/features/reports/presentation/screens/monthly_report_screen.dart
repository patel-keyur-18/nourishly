import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nourishly_data/nourishly_data.dart'
    hide DailyScore, NutrientTarget;
import 'package:nourishly_ui/nourishly_ui.dart';
import 'package:nutrition_core/nutrition_core.dart';

import '../../../../app/providers.dart';
import '../../../../shared/formatting.dart';
import '../../../profile/data/profile_providers.dart';
import '../../data/report_providers.dart';
import '../widgets/period_widgets.dart';

/// The monthly report (prototype screen 11, option A — trend line).
///
/// Daily nutrition is noisy, so the smoothed line is the signal (§27.11):
/// the month leads with the score trend and its 7-day average, then the
/// month at a glance, then what was chronically short and chronically
/// over. The comparison against last month appears only when both months
/// clear §25.6's logging threshold, and says why when it does not.
class MonthlyReportScreen extends ConsumerWidget {
  const MonthlyReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final today = ref.watch(todayProvider);
    final summaryAsync = ref.watch(monthSummaryProvider(month));
    final isCurrentMonth =
        month.year == today.year && month.month == today.month;
    final previous = DateTime(month.year, month.month - 1);

    return Scaffold(
      appBar: AppBar(
        title: Text(formatMonthTitle(month, today: today)),
        actions: [
          TextButton(
            onPressed: () =>
                ref.read(selectedMonthProvider.notifier).shiftBy(-1),
            child: Text(monthAbbreviation(previous.month)),
          ),
          if (!isCurrentMonth)
            TextButton(
              onPressed: () =>
                  ref.read(selectedMonthProvider.notifier).shiftBy(1),
              child: const Text('Next'),
            ),
        ],
      ),
      body: summaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(NourishlySpace.s6),
            child: Text('$error', textAlign: TextAlign.center),
          ),
        ),
        data: (summary) => _MonthBody(summary: summary, month: month),
      ),
    );
  }
}

class _MonthBody extends ConsumerWidget {
  const _MonthBody({required this.summary, required this.month});

  final PeriodSummary summary;
  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showScore = ref.watch(showScoreProvider);
    final labels = ref.watch(nutrientLabelsProvider).value ?? const {};
    final curves =
        ref.watch(targetsForDateProvider(summary.end)).value ?? const {};

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        NourishlySpace.s4,
        NourishlySpace.s3,
        NourishlySpace.s4,
        NourishlySpace.s7,
      ),
      children: [
        if (showScore) _ScoreTrendCard(summary: summary, month: month),
        const NourishlySectionHeader(label: 'Month at a glance'),
        _GlanceCard(summary: summary, month: month, showScore: showScore),
        if (summary.meetsLoggingThreshold) ...[
          const NourishlySectionHeader(label: 'Targets met'),
          _GoalConsistencyCard(summary: summary, labels: labels),
        ],
        if (_chronic(summary.chronicallyLow, curves, canBeShort) case final low
            when low.isNotEmpty) ...[
          const NourishlySectionHeader(label: 'Consistently short'),
          _ChronicCard(
            nutrients: low,
            labels: labels,
            status: NourishlyStatus.low,
          ),
        ],
        if (_chronic(summary.chronicallyHigh, curves, canBeOver) case final high
            when high.isNotEmpty) ...[
          const NourishlySectionHeader(label: 'Consistently over'),
          _ChronicCard(
            nutrients: high,
            labels: labels,
            status: NourishlyStatus.high,
          ),
        ],
        const NourishlySectionHeader(label: 'Days logged'),
        _MonthConsistencyCard(summary: summary),
      ],
    );
  }

  /// Only nutrients the finding can honestly be made about, capped.
  ///
  /// [suits] is [canBeShort] or [canBeOver]: a range target — energy, and
  /// the macros derived as a share of it — is neither short nor over, and
  /// listing energy as "consistently short" directly contradicts the
  /// energy average two cards up. The cap is because a callout listing
  /// everything is not a callout.
  static List<ChronicNutrient> _chronic(
    List<ChronicNutrient> all,
    Map<String, NutrientTarget> curves,
    bool Function(TargetCurveType?) suits,
  ) =>
      all.where((n) => suits(curves[n.nutrientId]?.curveType)).take(4).toList();
}

/// §27.10's 30-day trend with a 7-day moving average, and the comparison
/// against the previous month underneath it.
class _ScoreTrendCard extends ConsumerWidget {
  const _ScoreTrendCard({required this.summary, required this.month});

  final PeriodSummary summary;
  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    final scored = summary.days.where((d) => d.score != null).toList();
    final comparison = ref.watch(monthComparisonProvider(month)).value;
    final previousName = monthName(DateTime(month.year, month.month - 1).month);

    if (scored.isEmpty) {
      return ChartCard(
        title: 'Daily score',
        note: 'No days scored',
        child: Text(
          'Scores appear here once days in this month have been logged and '
          'have rolled over.',
          style: text.caption.copyWith(color: colors.ink3, height: 1.5),
        ),
      );
    }

    final lowest = scored.map((d) => d.score!).reduce((a, b) => a < b ? a : b);
    final highest = scored.map((d) => d.score!).reduce((a, b) => a > b ? a : b);

    return NourishlyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  'Daily score',
                  style: text.caption.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '7-day average',
                style: text.caption.copyWith(
                  fontSize: 10.5,
                  color: colors.ink3,
                ),
              ),
            ],
          ),
          const SizedBox(height: NourishlySpace.s2),
          Sparkline(
            values: [for (final point in summary.scoreSeries) point.score],
            smoothed: [
              for (final point in summary.movingAverage()) point.score,
            ],
            // A month of scores inside a couple of points of each other
            // is a flat month, and should look like one.
            minimumSpan: 20,
            semanticsLabel:
                'Daily score, ${lowest.round()} to ${highest.round()} over '
                '${scored.length} scored days, with a 7-day average',
          ),
          _Comparison(comparison: comparison, previousMonthName: previousName),
        ],
      ),
    );
  }
}

/// The prototype's `.cmp` row, gated per §25.6.
class _Comparison extends StatelessWidget {
  const _Comparison({
    required this.comparison,
    required this.previousMonthName,
  });

  final PeriodComparison? comparison;
  final String previousMonthName;

  @override
  Widget build(BuildContext context) {
    if (comparison == null) {
      return const SizedBox.shrink();
    }
    if (comparison!.score case final delta?) {
      final rounded = delta.delta.abs().round();
      // "-0" is not a delta. When the movement rounds away the row shows a
      // level 0 and the note underneath carries both months' actual
      // numbers.
      final sign = rounded == 0
          ? ''
          : delta.delta > 0
          ? '+'
          : '−';
      return PeriodComparisonRow(
        label: 'vs $previousMonthName',
        delta: '$sign$rounded',
        direction: switch (delta.direction) {
          TrendDirection.up => PeriodTrend.up,
          TrendDirection.down => PeriodTrend.down,
          TrendDirection.flat => PeriodTrend.flat,
        },
        // Both bases named, never a bare delta (§27.11).
        note:
            '${delta.current.round()} this month, '
            '${delta.previous.round()} in $previousMonthName'
            '${delta.direction == TrendDirection.flat ? ' — too small a change to call a trend' : ''}',
      );
    }
    return PeriodComparisonRow(
      label: 'vs $previousMonthName',
      note:
          comparison!.withheldReason?.message ??
          'Not enough scored days to compare.',
    );
  }
}

/// §27.10's monthly averages, each against its denominator.
class _GlanceCard extends ConsumerWidget {
  const _GlanceCard({
    required this.summary,
    required this.month,
    required this.showScore,
  });

  final PeriodSummary summary;
  final DateTime month;
  final bool showScore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hideEnergy = ref.watch(hideEnergyProvider);
    final comparison = ref.watch(monthComparisonProvider(month)).value;
    final previousName = monthName(DateTime(month.year, month.month - 1).month);

    final rows = <Widget>[
      PeriodAverageRow(
        label: 'Days logged',
        value: '${summary.loggedDayCount}',
        // §25.6: a day held out of the averages is said out loud, whether
        // it was held out for looking partly logged or for still running.
        note: switch (summary.loggedDayCount - summary.averagedDayCount) {
          0 => 'of ${summary.calendarDayCount} days in the month',
          final held =>
            'of ${summary.calendarDayCount} days in the month \u00b7 $held '
                '${held == 1 ? 'day is still running or looks' : 'days are still running or look'} '
                'partly logged, and left out of the averages',
        },
        showDivider: false,
      ),
    ];

    if (!summary.meetsLoggingThreshold) {
      return Column(
        children: [
          NourishlyCard(child: rows.first),
          const SizedBox(height: NourishlySpace.s3),
          NotEnoughDaysCard(summary: summary, periodNoun: 'month'),
        ],
      );
    }

    if (!hideEnergy) {
      if (summary.averageEnergyKcal case final energy?) {
        final target = summary.nutrientAverage('energy')?.targetAmount;
        rows.add(
          PeriodAverageRow(
            label: 'Avg energy',
            value: formatThousands(energy),
            note: target == null
                ? daysDenominator(summary.averagedDayCount)
                : '${daysDenominator(summary.averagedDayCount)} · target '
                      '${formatThousands(target)}',
            showDivider: false,
          ),
        );
      }
    }

    if (showScore) {
      if (summary.averageScore case final score?) {
        final previous = comparison?.score?.previous;
        rows.add(
          PeriodAverageRow(
            label: 'Avg score',
            value: '${score.round()}',
            note: previous == null
                ? 'over ${summary.scoredDayCount} scored days'
                : 'over ${summary.scoredDayCount} scored days · '
                      '$previousName ${previous.round()}',
            showDivider: false,
          ),
        );
      }
    }

    return NourishlyCard(
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                color: context.nourishlyColors.line,
              ),
            rows[i],
          ],
        ],
      ),
    );
  }
}

/// §27.10's goal-consistency percentages: how much of the month each
/// headline target was met on, with the count it is a percentage of.
///
/// The percentage never appears on its own — "79%" over four logged days
/// and "79%" over twenty-four are different claims (§25.6).
class _GoalConsistencyCard extends ConsumerWidget {
  const _GoalConsistencyCard({required this.summary, required this.labels});

  final PeriodSummary summary;
  final Map<String, Nutrient> labels;

  static const _headline = ['protein', 'fibre'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focus = ref.watch(focusNutrientIdsProvider);
    final rows = <Widget>[];

    for (final id in {..._headline, ...focus}) {
      final average = summary.nutrientAverage(id);
      if (average == null || average.targetAmount == null) continue;
      final nutrient = labels[id];
      final share = ((average.shareMet ?? 0) * 100).round();
      rows.add(
        PeriodAverageRow(
          label: shortNutrientName(nutrient?.displayName ?? id),
          value: '$share%',
          note: metDenominator(
            average.daysMet,
            average.daysAveraged,
            isLimit: nutrient?.isLimitNutrient ?? false,
          ),
          showDivider: false,
        ),
      );
    }

    if (rows.isEmpty) {
      return NourishlyCard(
        child: Text(
          'No nutrient in this month has a target to measure against.',
          style: context.nourishlyText.caption.copyWith(
            color: context.nourishlyColors.ink3,
          ),
        ),
      );
    }

    return NourishlyCard(
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                color: context.nourishlyColors.line,
              ),
            rows[i],
          ],
        ],
      ),
    );
  }
}

/// §27.10's chronically low and chronically high chips, each carrying the
/// count it is based on rather than only a colour.
class _ChronicCard extends StatelessWidget {
  const _ChronicCard({
    required this.nutrients,
    required this.labels,
    required this.status,
  });

  final List<ChronicNutrient> nutrients;
  final Map<String, Nutrient> labels;
  final NourishlyStatus status;

  @override
  Widget build(BuildContext context) {
    return NourishlyCard(
      child: Wrap(
        spacing: NourishlySpace.s2,
        runSpacing: NourishlySpace.s2,
        children: [
          for (final nutrient in nutrients)
            StatusChip(
              status: status,
              label:
                  '${shortNutrientName(labels[nutrient.nutrientId]?.displayName ?? nutrient.nutrientId)} '
                  '· ${nutrient.days} of ${nutrient.outOf} days',
            ),
        ],
      ),
    );
  }
}

/// A month of logging consistency, one cell per day, with each logged day
/// tappable through to its own report (§27.10: drill into a day).
class _MonthConsistencyCard extends ConsumerWidget {
  const _MonthConsistencyCard({required this.summary});

  final PeriodSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;

    return NourishlyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConsistencyStrip(
            semanticsLabel:
                '${summary.loggedDayCount} of ${summary.calendarDayCount} '
                'days logged this month',
            cells: [
              for (final day in summary.days)
                switch (day.completeness) {
                  DayCompleteness.complete => ConsistencyCell.logged,
                  DayCompleteness.looksIncomplete ||
                  DayCompleteness.inProgress =>
                    day.wasLogged
                        ? ConsistencyCell.partial
                        : ConsistencyCell.none,
                  DayCompleteness.empty => ConsistencyCell.none,
                },
            ],
          ),
          const SizedBox(height: NourishlySpace.s3),
          Text(
            '${summary.loggedDayCount} of ${summary.calendarDayCount} days '
            'logged.',
            style: text.caption.copyWith(color: colors.ink3),
          ),
          if (summary.loggedDayCount > 0) ...[
            const SizedBox(height: NourishlySpace.s3),
            // §27.10: drill into a day. The strip's own cells are a
            // thirtieth of the width and nowhere near a 48dp touch
            // target, so the days are offered as chips — the same
            // affordance the weekly screen uses, scrolled because a
            // well-logged month has thirty of them.
            SizedBox(
              height: NourishlyTarget.minTouch,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final day in summary.days)
                    if (day.wasLogged)
                      Padding(
                        padding: const EdgeInsets.only(
                          right: NourishlySpace.s2,
                        ),
                        child: ActionChip(
                          label: Text('${day.date.day}'),
                          tooltip: formatLongDate(day.date),
                          onPressed: () {
                            ref
                                .read(selectedDateProvider.notifier)
                                .setTo(day.date);
                            context.go('/today/report');
                          },
                        ),
                      ),
                ],
              ),
            ),
          ],
          const SizedBox(height: NourishlySpace.s2),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () {
                // §27.10: drill into a week.
                ref
                    .read(selectedWeekStartProvider.notifier)
                    .setTo(
                      summary.days
                          .lastWhere(
                            (d) => d.wasLogged,
                            orElse: () => summary.days.first,
                          )
                          .date,
                    );
                context.go('/insights/week');
              },
              child: const Text('Open the latest logged week'),
            ),
          ),
        ],
      ),
    );
  }
}
