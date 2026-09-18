import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nourishly_ui/nourishly_ui.dart';
import 'package:nutrition_core/nutrition_core.dart';

import '../../../food_logging/presentation/widgets/food_search_result_tile.dart';
import '../../data/report_providers.dart';

/// Two things a period report can say that no public nutrition app can,
/// because they both depend on knowing how one household cooks and eats.
///
/// Each renders nothing at all when there is nothing to say. A card that
/// appears every week reading "0 g saved" would train the reader to skip
/// that part of the report, and an empty cuisine mix is not a finding.

/// What cooking lighter saved over the period.
class OilSavedCard extends ConsumerWidget {
  const OilSavedCard({super.key, required this.summary});

  final PeriodSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    final savings = ref
        .watch(periodSavingsProvider((from: summary.start, to: summary.end)))
        .value;

    if (savings == null || savings.isEmpty || savings.fat <= 0) {
      return const SizedBox.shrink();
    }

    final meals = savings.entryCount == 1 ? 'meal' : 'meals';
    final dishes = savings.dishCount == 1 ? 'dish' : 'dishes';

    return NourishlyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cooking lighter',
            style: text.body.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: NourishlySpace.s2),
          Text(
            '${_grams(savings.fat)} g of fat and ${savings.energy.round()} '
            'kcal not eaten, across ${savings.entryCount} $meals.',
            style: text.body.copyWith(height: 1.5),
          ),
          const SizedBox(height: NourishlySpace.s2),
          Text(
            'Measured against the standard recipe for the $dishes you cook '
            'your own way — both worked out from their ingredients, so this '
            'is a difference, not an estimate.',
            style: text.caption.copyWith(color: colors.ink3, height: 1.5),
          ),
        ],
      ),
    );
  }

  static String _grams(double v) =>
      v >= 10 ? v.round().toString() : v.toStringAsFixed(1);
}

/// How the period's meals divided by cuisine.
class CuisineMixCard extends ConsumerWidget {
  const CuisineMixCard({super.key, required this.summary});

  final PeriodSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    final mix = ref
        .watch(cuisineMixProvider((from: summary.start, to: summary.end)))
        .value;

    // Two cuisines is the least that can be called a mix; one is just
    // what you eat, and the report already knows that.
    if (mix == null || mix.byCuisine.length < 2) return const SizedBox.shrink();

    final tagged = mix.byCuisine.fold<int>(0, (a, c) => a + c.count);
    if (tagged == 0) return const SizedBox.shrink();

    return NourishlyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What you ate',
            style: text.body.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: NourishlySpace.s3),
          for (final cuisine in mix.byCuisine.take(5)) ...[
            _CuisineBar(
              label:
                  FoodSearchResultTile.cuisineLabel(cuisine.cuisine) ??
                  cuisine.cuisine,
              share: cuisine.count / tagged,
            ),
            const SizedBox(height: NourishlySpace.s2),
          ],
          if (tagged < mix.totalEntries)
            Text(
              // Never rounded up into the shares: a percentage is only
              // meaningful against a known total, and a food nobody
              // classified belongs to no cuisine rather than to "other".
              'Based on $tagged of ${mix.totalEntries} entries — the rest '
              'are foods with no cuisine recorded.',
              style: text.caption.copyWith(color: colors.ink3, height: 1.5),
            ),
        ],
      ),
    );
  }
}

class _CuisineBar extends StatelessWidget {
  const _CuisineBar({required this.label, required this.share});

  final String label;
  final double share;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    return Row(
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: text.caption,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(NourishlyRadius.pill),
            child: LinearProgressIndicator(
              value: share,
              minHeight: 8,
              backgroundColor: colors.surface2,
            ),
          ),
        ),
        const SizedBox(width: NourishlySpace.s2),
        SizedBox(
          width: 40,
          child: Text(
            '${(share * 100).round()}%',
            style: text.caption.copyWith(color: colors.ink3),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
