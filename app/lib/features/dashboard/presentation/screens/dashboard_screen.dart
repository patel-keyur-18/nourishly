import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nourishly_data/nourishly_data.dart';
import 'package:nourishly_ui/nourishly_ui.dart';

import '../../../../app/providers.dart';
import '../../../data_backup/presentation/widgets/export_prompt_banner.dart';
import '../../../profile/data/profile_providers.dart';
import '../widgets/day_header.dart';
import '../widgets/dashboard_cards.dart';

/// The daily dashboard (prototype screen 3, option A — ring-led).
///
/// Reads one [DaySummary] and nothing else: §27.2 forbids the most-viewed
/// screen in the app from aggregating log entries at render time, and the
/// summary is the materialised row that makes that possible.
///
/// The order of the cards is §27.2's priority order, and it is deliberate
/// — ring, macros, water, status chips, meals. Everything above the fold
/// answers "how am I doing"; the meals list answers "what next".
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(selectedDaySummaryProvider);
    final date = ref.watch(selectedDateProvider);
    final profileName = ref.watch(profileDisplayNameProvider).value;
    final showScore = ref.watch(showScoreProvider);
    final hideEnergy = ref.watch(hideEnergyProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: summaryAsync.when(
          loading: () => const _DashboardSkeleton(),
          error: (error, _) => _ErrorBody(error: error),
          data: (summary) => RefreshIndicator(
            onRefresh: () async =>
                ref.read(summaryRevisionProvider.notifier).bump(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                NourishlySpace.s4,
                NourishlySpace.s2,
                NourishlySpace.s4,
                NourishlySpace.s7,
              ),
              children: [
                DayHeader(
                  date: date,
                  score: summary.score,
                  profileName: profileName,
                  // §21.8: the score is fully dismissible, and a profile
                  // that hides it never sees it anywhere.
                  showScore: showScore,
                  onPreviousDay: () => _shiftDay(ref, -1),
                  onNextDay: date.isBefore(ref.read(todayProvider))
                      ? () => _shiftDay(ref, 1)
                      : null,
                ),
                const SizedBox(height: NourishlySpace.s4),
                // §0.5's monthly export prompt. Above the cards so it is
                // seen, below the day header so it never displaces what
                // the user opened the app for.
                const ExportPromptBanner(),
                if (!hideEnergy) ...[
                  EnergyCard(summary: summary),
                  const SizedBox(height: NourishlySpace.s3),
                ],
                MacroCard(summary: summary),
                const SizedBox(height: NourishlySpace.s3),
                WaterCard(summary: summary),
                const SizedBox(height: NourishlySpace.s3),
                FocusNutrientsCard(summary: summary),
                StatusChipRow(summary: summary),
                const SizedBox(height: NourishlySpace.s3),
                MealsCard(summary: summary),
                if (summary.hasAnything) ...[
                  const SizedBox(height: NourishlySpace.s3),
                  _ReportLink(summary: summary),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _shiftDay(WidgetRef ref, int days) {
    ref.read(selectedDateProvider.notifier).shiftBy(days);
  }
}

/// §27.2 item 8: late in the day, a way into the report. Present whenever
/// there is something to report on, rather than gated on a clock the user
/// cannot see.
class _ReportLink extends StatelessWidget {
  const _ReportLink({required this.summary});

  final DaySummary summary;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    return NourishlyCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: NourishlySpace.s4,
          vertical: NourishlySpace.s1,
        ),
        title: Text(
          'See the full day',
          style: text.body.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'Every nutrient against its target',
          style: text.caption.copyWith(color: colors.ink3),
        ),
        trailing: Icon(Icons.chevron_right_rounded, color: colors.ink3),
        onTap: () => context.go('/today/report'),
      ),
    );
  }
}

/// §27.14: skeletons for the dashboard, never a spinner. The shapes match
/// the cards that replace them so the screen does not jump.
class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        NourishlySpace.s4,
        NourishlySpace.s5,
        NourishlySpace.s4,
        NourishlySpace.s7,
      ),
      children: const [
        _SkeletonBlock(height: 44),
        SizedBox(height: NourishlySpace.s4),
        _SkeletonBlock(height: 150),
        SizedBox(height: NourishlySpace.s3),
        _SkeletonBlock(height: 168),
        SizedBox(height: NourishlySpace.s3),
        _SkeletonBlock(height: 120),
      ],
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.nourishlyColors.surface2,
        borderRadius: BorderRadius.circular(NourishlyRadius.lg),
      ),
      child: SizedBox(height: height, width: double.infinity),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.error});

  final Object error;

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
            Icon(Icons.error_outline_rounded, color: colors.danger, size: 28),
            const SizedBox(height: NourishlySpace.s3),
            Text(
              "Today's log could not be loaded.",
              style: text.body.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: NourishlySpace.s2),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: text.caption.copyWith(color: colors.ink3),
            ),
          ],
        ),
      ),
    );
  }
}
