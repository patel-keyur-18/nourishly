import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nourishly_ui/nourishly_ui.dart';
import 'package:nutrition_core/nutrition_core.dart';

import '../../../../app/providers.dart';
import '../../../../shared/formatting.dart';
import '../../../dashboard/presentation/widgets/day_header.dart';
import '../../../profile/data/profile_providers.dart';
import '../../data/report_providers.dart';
import '../widgets/period_widgets.dart';

/// The Insights tab: the way in to the three reports (prototype screens
/// 9-11).
///
/// The week and the month are pushed inside this branch rather than over
/// the whole shell, which is what the prototype draws — the bottom nav
/// stays visible on 10A and 11A, and only the daily report (9C) covers it.
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  static const _daysShown = 7;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider);
    final days = [
      for (var back = 0; back < _daysShown; back++)
        today.subtract(Duration(days: back)),
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            NourishlySpace.s4,
            NourishlySpace.s4,
            NourishlySpace.s4,
            NourishlySpace.s7,
          ),
          children: [
            Text('Insights', style: context.nourishlyText.title),
            const NourishlySectionHeader(label: 'Reports'),
            const _PeriodLinks(),
            const NourishlySectionHeader(label: 'The last seven days'),
            NourishlyCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [for (final day in days) _DayRow(date: day)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayRow extends ConsumerWidget {
  const _DayRow({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    final summaryAsync = ref.watch(daySummaryProvider(date));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          ref.read(selectedDateProvider.notifier).setTo(date);
          context.go('/today/report');
        },
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
                    Text(
                      relativeDayLabel(date),
                      style: text.body.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      formatLongDate(date),
                      style: text.caption.copyWith(color: colors.ink3),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: NourishlySpace.s2),
              summaryAsync.when(
                loading: () => const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (_, _) => const SizedBox.shrink(),
                data: (summary) => Row(
                  children: [
                    if (summary.entryCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(
                          right: NourishlySpace.s2,
                        ),
                        child: Text(
                          '${formatThousands(summary.totalEnergyKcal)} kcal',
                          style: text.caption.copyWith(color: colors.ink3),
                        ),
                      ),
                    ScoreChip(score: summary.score),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.ink3, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// The week and the month, each with the one number that says whether
/// there is anything in it yet (§25.6: the denominator, before the
/// content).
class _PeriodLinks extends ConsumerWidget {
  const _PeriodLinks();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.nourishlyColors;
    final today = ref.watch(todayProvider);
    final weekStart = ref.watch(selectedWeekStartProvider);
    final month = ref.watch(selectedMonthProvider);

    return NourishlyCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _PeriodRow(
            title: formatWeekRange(
              weekStart,
              weekStart.add(const Duration(days: 6)),
            ),
            summaryAsync: ref.watch(weekSummaryProvider(weekStart)),
            noun: 'week',
            onTap: () => context.go('/insights/week'),
          ),
          Divider(height: 1, thickness: 1, color: colors.line),
          _PeriodRow(
            title: formatMonthTitle(month, today: today),
            summaryAsync: ref.watch(monthSummaryProvider(month)),
            noun: 'month',
            onTap: () => context.go('/insights/month'),
          ),
        ],
      ),
    );
  }
}

class _PeriodRow extends StatelessWidget {
  const _PeriodRow({
    required this.title,
    required this.summaryAsync,
    required this.noun,
    required this.onTap,
  });

  final String title;
  final AsyncValue<PeriodSummary> summaryAsync;
  final String noun;
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
                    Text(
                      title,
                      style: text.body.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(switch (summaryAsync) {
                      AsyncData(:final value) =>
                        '${value.loggedDayCount} of '
                            '${value.calendarDayCount} days logged',
                      AsyncError() => 'Could not be loaded',
                      _ => 'Counting the $noun\u2026',
                    }, style: text.caption.copyWith(color: colors.ink3)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.ink3, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
