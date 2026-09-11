import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nourishly_ui/nourishly_ui.dart';

import '../../../../app/providers.dart';
import '../../../../shared/formatting.dart';
import '../../../dashboard/presentation/widgets/day_header.dart';
import '../../../profile/data/profile_providers.dart';

/// The Insights tab (prototype screens 9-11).
///
/// Phase 3 delivers the daily report; the weekly and monthly views are
/// Phase 4, and §25.6's honesty rules mean they need a logged-day
/// denominator before they can average anything anyway. So this lists the
/// recent days with their scores and opens each one's report — useful now,
/// and the shape the weekly view slots into.
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
            const NourishlySectionHeader(label: 'The last seven days'),
            NourishlyCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [for (final day in days) _DayRow(date: day)],
              ),
            ),
            const NourishlySectionHeader(label: 'Coming in Phase 4'),
            const _ComingSoonCard(),
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

class _ComingSoonCard extends StatelessWidget {
  const _ComingSoonCard();

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    return NourishlyCard(
      child: Text(
        'Weekly and monthly views, with the logged-day denominator every '
        'average is stated against.',
        style: text.caption.copyWith(color: colors.ink3, height: 1.5),
      ),
    );
  }
}
