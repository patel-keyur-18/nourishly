import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nourishly_data/nourishly_data.dart'
    hide DailyScore, NutrientTarget;
import 'package:nourishly_ui/nourishly_ui.dart';
import 'package:nutrition_core/nutrition_core.dart';

import '../../../../shared/formatting.dart';
import '../../../profile/data/profile_providers.dart';
import '../../data/report_providers.dart';
import '../widgets/period_widgets.dart';

/// One nutrient across one week — §27.9's "tap a nutrient for its weekly
/// detail".
///
/// The weekly report can only give a nutrient one line. This is the rest
/// of it: the day-by-day shape against the target that applied, the
/// average with its denominator, and — for a micronutrient — how much of
/// the week's food actually reported it, which is the difference between
/// a low figure and an incomplete one (§19.11, §20.8).
class WeeklyNutrientScreen extends ConsumerWidget {
  const WeeklyNutrientScreen({super.key, required this.nutrientId});

  final String nutrientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekStart = ref.watch(selectedWeekStartProvider);
    final summaryAsync = ref.watch(weekSummaryProvider(weekStart));
    final nutrient = ref.watch(nutrientLabelsProvider).value?[nutrientId];
    final title = shortNutrientName(nutrient?.displayName ?? nutrientId);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: summaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(NourishlySpace.s6),
            child: Text('$error', textAlign: TextAlign.center),
          ),
        ),
        data: (summary) =>
            _Body(summary: summary, nutrientId: nutrientId, nutrient: nutrient),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.summary,
    required this.nutrientId,
    required this.nutrient,
  });

  final PeriodSummary summary;
  final String nutrientId;
  final Nutrient? nutrient;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    final unit = nutrient?.canonicalUnit ?? '';
    final precision = nutrient?.displayPrecision ?? 0;
    final isLimit = nutrient?.isLimitNutrient ?? false;
    final average = summary.nutrientAverage(nutrientId);

    // The target that applied on the days of this week, not today's:
    // targets are effective-dated and never retroactive (I-3).
    final target = average?.targetAmount;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        NourishlySpace.s4,
        NourishlySpace.s3,
        NourishlySpace.s4,
        NourishlySpace.s7,
      ),
      children: [
        Text(
          formatWeekRange(summary.start, summary.end),
          style: text.caption.copyWith(color: colors.ink3),
        ),
        const SizedBox(height: NourishlySpace.s3),
        ChartCard(
          title: 'Each day',
          note: target == null
              ? null
              : '${isLimit ? 'Limit' : 'Target'} '
                    '${formatAmount(target, unit, precision)}',
          footnote: _footnote(),
          child: DayBarChart(
            target: target,
            semanticsLabel: _chartLabel(unit, precision, isLimit, target),
            bars: [
              for (final day in summary.days)
                DayBar(
                  label: weekdayInitial(day.date.weekday),
                  value: _valueOn(day),
                  semanticLabel: _dayLabel(day, unit, precision),
                ),
            ],
          ),
        ),
        const NourishlySectionHeader(label: 'Across the week'),
        if (average == null)
          NourishlyCard(
            child: Text(
              summary.meetsLoggingThreshold
                  ? 'Nothing logged this week reports '
                        '${shortNutrientName(nutrient?.displayName ?? nutrientId).toLowerCase()}. '
                        'That is not the same as none of it — it is not '
                        'recorded for the foods logged.'
                  : 'Averages need at least '
                        '${PeriodHonesty.minDaysForAverages} logged days. '
                        'The days themselves are below.',
              style: text.caption.copyWith(color: colors.ink3, height: 1.5),
            ),
          )
        else
          NourishlyCard(
            child: Column(
              children: [
                PeriodAverageRow(
                  label: 'Average',
                  value: formatAmount(average.average, unit, precision),
                  note: daysDenominator(average.daysAveraged),
                ),
                if (target != null)
                  PeriodAverageRow(
                    label: isLimit ? 'Under the limit' : 'Target met',
                    value: '${average.daysMet} of ${average.daysAveraged}',
                    note: metDenominator(
                      average.daysMet,
                      average.daysAveraged,
                      isLimit: isLimit,
                    ),
                  ),
                PeriodAverageRow(
                  label: 'Based on',
                  value: '${(average.averageCoverage * 100).round()}%',
                  // §20.8: a micronutrient average built from part of the
                  // day's food has to say so, or a low figure and an
                  // incomplete one look identical.
                  note: 'of the energy logged on those days reported it',
                  showDivider: false,
                ),
              ],
            ),
          ),
        // §25.6: the day list below shows more days than the average was
        // built from whenever one is still running or looks partly
        // logged. Unexplained, that reads as an arithmetic error.
        if (_heldOut().isNotEmpty) ...[
          const SizedBox(height: NourishlySpace.s2),
          Text(
            _heldOutNote(),
            style: text.caption.copyWith(color: colors.ink3, height: 1.4),
          ),
        ],
        const NourishlySectionHeader(label: 'Day by day'),
        _DayList(
          summary: summary,
          nutrientId: nutrientId,
          unit: unit,
          precision: precision,
        ),
      ],
    );
  }

  /// Days with a value that are nonetheless out of the average.
  List<PeriodDay> _heldOut() => summary.days
      .where(
        (day) =>
            day.wasLogged && !day.countsTowardAverages && _valueOn(day) != null,
      )
      .toList();

  String _heldOutNote() {
    final held = _heldOut();
    final names = [for (final day in held) weekdayName(day.date.weekday)];
    final list = names.length == 1
        ? names.single
        : '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
    final tail = held.length == 1
        ? 'that day is still running or looks partly logged'
        : 'those days are still running or look partly logged';
    return '$list ${held.length == 1 ? 'is' : 'are'} below but not in the '
        'average — $tail.';
  }

  double? _valueOn(PeriodDay day) {
    final value = day.nutrients[nutrientId];
    return value == null || !value.hasData ? null : value.amount;
  }

  String? _footnote() {
    final withoutData = summary.days
        .where((d) => d.wasLogged && _valueOn(d) == null)
        .length;
    if (withoutData == 0) return null;
    return '$withoutData logged ${withoutData == 1 ? 'day does' : 'days do'} '
        'not report it. Those are left blank rather than drawn as zero.';
  }

  String _chartLabel(String unit, int precision, bool isLimit, double? target) {
    final name = shortNutrientName(nutrient?.displayName ?? nutrientId);
    if (target == null) return '$name on each day of the week';
    return '$name each day against a '
        '${formatAmount(target, unit, precision)} '
        '${isLimit ? 'limit' : 'target'}';
  }

  String _dayLabel(PeriodDay day, String unit, int precision) {
    final name = weekdayName(day.date.weekday);
    final value = _valueOn(day);
    if (value == null) {
      return day.wasLogged
          ? '$name, not recorded for what was logged'
          : '$name, nothing logged';
    }
    return '$name, ${formatAmount(value, unit, precision)}';
  }
}

/// Every day of the week, tappable through to its own report — the same
/// drill-down the weekly screen offers, kept here so a nutrient's bad day
/// is one tap from what caused it.
class _DayList extends ConsumerWidget {
  const _DayList({
    required this.summary,
    required this.nutrientId,
    required this.unit,
    required this.precision,
  });

  final PeriodSummary summary;
  final String nutrientId;
  final String unit;
  final int precision;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;

    return NourishlyCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < summary.days.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: colors.line),
            () {
              final day = summary.days[i];
              final value = day.nutrients[nutrientId];
              final row = Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: NourishlySpace.s4,
                  vertical: NourishlySpace.s3,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${weekdayName(day.date.weekday)} ${day.date.day}',
                        style: text.body.copyWith(
                          color: day.wasLogged ? colors.ink : colors.ink3,
                        ),
                      ),
                    ),
                    Text(
                      // AP-4: an em dash, never a zero.
                      value == null || !value.hasData
                          ? '—'
                          : formatAmount(value.amount, unit, precision),
                      style: text.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: value == null || !value.hasData
                            ? colors.ink3
                            : colors.ink,
                      ),
                    ),
                    if (day.wasLogged) ...[
                      const SizedBox(width: NourishlySpace.s2),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: colors.ink3,
                        size: 20,
                      ),
                    ],
                  ],
                ),
              );

              if (!day.wasLogged) return row;
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    ref.read(selectedDateProvider.notifier).setTo(day.date);
                    context.go('/today/report');
                  },
                  child: row,
                ),
              );
            }(),
          ],
        ],
      ),
    );
  }
}
