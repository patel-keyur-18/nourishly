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

/// The weekly report (prototype screen 10, option A — charts first).
///
/// Bars and the trend lead, findings sit underneath: the shape of the week
/// is what a single day cannot show, and it is what this screen exists
/// for. Every average below carries the number of logged days it was built
/// from, and under three of them there are no averages at all (§25.6).
class WeeklyReportScreen extends ConsumerWidget {
  const WeeklyReportScreen({super.key});

  /// The averages the prototype leads with, before the profile's own
  /// focus nutrients are added to them.
  static const _headlineNutrients = ['energy', 'protein', 'fibre'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekStart = ref.watch(selectedWeekStartProvider);
    final summaryAsync = ref.watch(weekSummaryProvider(weekStart));
    final today = ref.watch(todayProvider);
    final isCurrentWeek =
        weekStart == startOfWeek(today, ref.watch(weekStartDayProvider));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          formatWeekRange(weekStart, weekStart.add(const Duration(days: 6))),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                ref.read(selectedWeekStartProvider.notifier).shiftBy(-1),
            child: const Text('Prev'),
          ),
          if (!isCurrentWeek)
            TextButton(
              onPressed: () =>
                  ref.read(selectedWeekStartProvider.notifier).shiftBy(1),
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
        data: (summary) => _WeekBody(summary: summary),
      ),
    );
  }
}

class _WeekBody extends ConsumerWidget {
  const _WeekBody({required this.summary});

  final PeriodSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showScore = ref.watch(showScoreProvider);
    final labels = ref.watch(nutrientLabelsProvider).value ?? const {};
    final focus = ref.watch(focusNutrientIdsProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        NourishlySpace.s4,
        NourishlySpace.s3,
        NourishlySpace.s4,
        NourishlySpace.s7,
      ),
      children: [
        _EnergyChart(summary: summary),
        if (showScore) ...[
          const SizedBox(height: NourishlySpace.s3),
          _ScoreChart(summary: summary),
        ],
        const NourishlySectionHeader(label: 'Averages'),
        if (!summary.meetsLoggingThreshold)
          NotEnoughDaysCard(summary: summary, periodNoun: 'week')
        else
          _AveragesCard(
            summary: summary,
            labels: labels,
            nutrientIds: {
              ...WeeklyReportScreen._headlineNutrients,
              ...focus,
            }.toList(),
          ),
        const NourishlySectionHeader(label: 'Worth knowing'),
        _Findings(
          summary: summary,
          labels: labels,
          showScore: showScore,
          curves:
              ref.watch(targetsForDateProvider(summary.end)).value ?? const {},
        ),
        const NourishlySectionHeader(label: 'Days logged'),
        _ConsistencyCard(summary: summary),
      ],
    );
  }
}

/// §27.9's 7-bar energy chart with a target line, and §27.11's reason for
/// choosing it: the comparison of interest is day-to-target.
class _EnergyChart extends StatelessWidget {
  const _EnergyChart({required this.summary});

  final PeriodSummary summary;

  @override
  Widget build(BuildContext context) {
    // The target that applied on each day, not today's: they are
    // effective-dated (I-3). The line is drawn at the one most of the week
    // was measured against.
    final targets = [for (final day in summary.days) ?day.energyTargetKcal];
    final target = targets.isEmpty ? null : _mostCommon(targets);

    final unlogged = summary.days.where((d) => !d.wasLogged).toList();

    return ChartCard(
      title: 'Energy per day',
      note: target == null ? null : 'Target ${formatThousands(target)}',
      footnote: unlogged.isEmpty
          ? null
          : unlogged.length == summary.days.length
          ? 'Nothing logged this week'
          : '${_listDays(unlogged)} not logged',
      child: DayBarChart(
        target: target,
        semanticsLabel: target == null
            ? 'Energy logged on each day of the week'
            : 'Energy per day against a '
                  '${formatThousands(target)} kcal target',
        bars: [
          for (final day in summary.days)
            DayBar(
              label: weekdayInitial(day.date.weekday),
              value: day.entryCount > 0 ? day.totalEnergyKcal : null,
              semanticLabel: _barLabel(day, target),
            ),
        ],
      ),
    );
  }

  static String _barLabel(PeriodDay day, double? target) {
    final name = weekdayName(day.date.weekday);
    if (day.entryCount == 0) return '$name, no food logged';
    final energy = '${formatThousands(day.totalEnergyKcal)} kcal';
    if (target == null) return '$name, $energy';
    final side = day.totalEnergyKcal >= target ? 'over' : 'under';
    return '$name, $energy, $side the ${formatThousands(target)} target';
  }

  static String _listDays(List<PeriodDay> days) {
    final names = [for (final day in days) weekdayName(day.date.weekday)];
    if (names.length == 1) return names.single;
    if (names.length > 3) return '${names.length} days';
    return '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
  }

  static double _mostCommon(List<double> values) {
    final counts = <double, int>{};
    for (final value in values) {
      counts[value] = (counts[value] ?? 0) + 1;
    }
    return counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
  }
}

/// §27.9's score trend. §27.11: gaps stay gaps.
class _ScoreChart extends StatelessWidget {
  const _ScoreChart({required this.summary});

  final PeriodSummary summary;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    final scored = summary.days.where((d) => d.score != null).toList();

    if (scored.isEmpty) {
      return ChartCard(
        title: 'Daily score',
        note: 'No days scored',
        child: Text(
          'A day is scored once it is over and looks completely logged.',
          style: text.caption.copyWith(color: colors.ink3, height: 1.5),
        ),
      );
    }

    final lowest = scored.map((d) => d.score!).reduce((a, b) => a < b ? a : b);
    final highest = scored.map((d) => d.score!).reduce((a, b) => a > b ? a : b);

    return ChartCard(
      title: 'Daily score',
      note: '${scored.length} ${scored.length == 1 ? 'day' : 'days'} scored',
      child: Sparkline(
        values: [for (final point in summary.scoreSeries) point.score],
        semanticsLabel: scored.length == 1
            ? 'Daily score, ${lowest.round()} on the one scored day'
            : 'Daily score, ${lowest.round()} to ${highest.round()} '
                  'over ${scored.length} scored days',
      ),
    );
  }
}

/// §27.9's headline averages, each with its logged-day denominator.
class _AveragesCard extends ConsumerWidget {
  const _AveragesCard({
    required this.summary,
    required this.labels,
    required this.nutrientIds,
  });

  final PeriodSummary summary;
  final Map<String, Nutrient> labels;
  final List<String> nutrientIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hideEnergy = ref.watch(hideEnergyProvider);
    final rows = <Widget>[];

    for (final id in nutrientIds) {
      if (id == 'energy' && hideEnergy) continue;
      final average = summary.nutrientAverage(id);
      if (average == null) continue;
      final nutrient = labels[id];
      rows.add(
        PeriodAverageRow(
          label: shortNutrientName(nutrient?.displayName ?? id),
          value: formatAmount(
            average.average,
            nutrient?.canonicalUnit ?? '',
            nutrient?.displayPrecision ?? 0,
          ),
          note: average.targetAmount == null || id == 'energy'
              // Energy is a range, and "met" reads as an achievement
              // against a floor. The prototype states it as a plain
              // average over its logged days, and so does this.
              ? daysDenominator(average.daysAveraged)
              : metDenominator(
                  average.daysMet,
                  average.daysAveraged,
                  isLimit: nutrient?.isLimitNutrient ?? false,
                ),
          showDivider: false,
        ),
      );
    }

    if (_water(summary) case final water?) rows.add(water);

    if (rows.isEmpty) {
      return NotEnoughDaysCard(summary: summary, periodNoun: 'week');
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

  /// Water is not a food nutrient, so it never appears in
  /// [PeriodSummary.nutrientAverages] — it is counted here, against
  /// whichever target applied on each day.
  Widget? _water(PeriodSummary summary) {
    final days = summary.averagedDays.toList();
    if (days.isEmpty) return null;
    final total = days.fold<double>(0, (a, d) => a + d.waterMl);
    final withTarget = days.where((d) => d.waterTargetMl != null).toList();
    final met = withTarget.where((d) => d.waterMl >= d.waterTargetMl!).length;

    return PeriodAverageRow(
      label: 'Water',
      value: '${(total / days.length / 1000).toStringAsFixed(1)} L',
      note: withTarget.isEmpty
          ? daysDenominator(days.length)
          : metDenominator(met, withTarget.length),
      showDivider: false,
    );
  }
}

/// §27.9's best day, most-missed nutrients, and the note that says which
/// days were held out of the averages and why.
class _Findings extends StatelessWidget {
  const _Findings({
    required this.summary,
    required this.labels,
    required this.showScore,
    required this.curves,
  });

  final PeriodSummary summary;
  final Map<String, Nutrient> labels;
  final bool showScore;

  /// The targets in force at the end of the period, for their curve type.
  final Map<String, NutrientTarget> curves;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    final findings = <PeriodFinding>[];

    if (showScore) {
      if (summary.bestDay case final best? when best.score != null) {
        findings.add(
          PeriodFinding.good(
            'Best day was ${weekdayName(best.date.weekday)} '
            '(${best.score!.round()}).',
          ),
        );
      }
    }

    final missable = summary
        .mostMissed(limit: 6)
        .where((n) => canBeShort(curves[n.nutrientId]?.curveType))
        .take(2);
    for (final missed in missable) {
      final name = shortNutrientName(
        labels[missed.nutrientId]?.displayName ?? missed.nutrientId,
      );
      findings.add(
        PeriodFinding.short(
          '$name missed on ${missed.daysMissed} of '
          '${missed.daysAveraged} logged days.',
        ),
      );
    }

    final overs = summary.chronicallyHigh
        .where((n) => canBeOver(curves[n.nutrientId]?.curveType))
        .take(1);
    for (final over in overs) {
      final name = shortNutrientName(
        labels[over.nutrientId]?.displayName ?? over.nutrientId,
      );
      findings.add(
        PeriodFinding.over(
          '$name was above its limit on ${over.days} of '
          '${over.outOf} logged days.',
        ),
      );
    }

    for (final excluded in summary.daysExcludedAsIncomplete) {
      findings.add(
        PeriodFinding.note(
          '${weekdayName(excluded.date.weekday)} looks partly logged, so it '
          'is left out of the averages above.',
        ),
      );
    }

    if (findings.isEmpty) {
      return NourishlyCard(
        child: Text(
          summary.loggedDayCount == 0
              ? 'Log a few days and the patterns show up here.'
              : 'Nothing stands out this week.',
          style: text.caption.copyWith(color: colors.ink3, height: 1.5),
        ),
      );
    }

    return FindingsCard(findings: findings);
  }
}

/// §27.11's consistency strip: which days were logged, shown as a
/// denominator rather than as a streak to lose (§21.8).
class _ConsistencyCard extends ConsumerWidget {
  const _ConsistencyCard({required this.summary});

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
                'days logged this week',
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
            labels: [
              for (final day in summary.days) weekdayInitial(day.date.weekday),
            ],
          ),
          const SizedBox(height: NourishlySpace.s3),
          Text(
            '${summary.loggedDayCount} of ${summary.calendarDayCount} days '
            'logged.',
            style: text.caption.copyWith(color: colors.ink3),
          ),
          const SizedBox(height: NourishlySpace.s3),
          Wrap(
            spacing: NourishlySpace.s2,
            runSpacing: NourishlySpace.s2,
            children: [
              for (final day in summary.days)
                if (day.wasLogged)
                  ActionChip(
                    label: Text(
                      '${weekdayInitial(day.date.weekday)} ${day.date.day}',
                    ),
                    onPressed: () {
                      // §27.9: tap a day to open its daily report.
                      ref.read(selectedDateProvider.notifier).setTo(day.date);
                      context.go('/today/report');
                    },
                  ),
            ],
          ),
        ],
      ),
    );
  }
}
