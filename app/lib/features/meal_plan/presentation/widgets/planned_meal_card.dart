import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nourishly_data/nourishly_data.dart';
import 'package:nourishly_ui/nourishly_ui.dart';

import '../../../../app/providers.dart';
import '../../../profile/data/profile_providers.dart';
import '../../data/meal_plan_providers.dart';

/// Screen 15 — confirming the plan, inline on Today (design option A,
/// chosen 2026-09-18).
///
/// One card per meal slot that still has something planned, sitting in the
/// day where the meal belongs, dashed until confirmed. The rejected
/// alternative was a single end-of-day sheet: cheaper to build, but it
/// asks you to remember a portion nine hours later, which is the recall
/// problem the whole app exists to remove. A portion confirmed at the
/// table is a portion you can still see.
class PlannedMealsSection extends ConsumerWidget {
  const PlannedMealsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planned = ref.watch(todayPlannedProvider).value ?? const [];
    if (planned.isEmpty) return const SizedBox.shrink();

    final bySlot = <String, List<PlannedFood>>{};
    for (final item in planned) {
      bySlot.putIfAbsent(item.mealSlotId, () => []).add(item);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in bySlot.entries) ...[
          _PlannedMealCard(items: entry.value),
          const SizedBox(height: NourishlySpace.s3),
        ],
      ],
    );
  }
}

class _PlannedMealCard extends ConsumerWidget {
  const _PlannedMealCard({required this.items});

  final List<PlannedFood> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    final slotName = items.first.mealSlotName;
    final energy = items.fold<double?>(null, (sum, item) {
      final kcal = item.energyKcal;
      return kcal == null ? sum : (sum ?? 0) + kcal;
    });

    // A dashed edge, the word "Planned", and a dot — three independent
    // signals for one state (NFR-A-04). The card is deliberately not a
    // different colour from every other card on the screen.
    return CustomPaint(
      painter: _DashedBorderPainter(color: colors.accent),
      child: Padding(
        padding: const EdgeInsets.all(NourishlySpace.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    slotName,
                    style: text.overline.copyWith(color: colors.ink3),
                  ),
                ),
                // A plain chip, not a StatusChip: ok/low/high/unknown and
                // the score's accent all mean something specific about a
                // nutrient, and "planned" is not one of them. The dashed
                // edge carries the colour; the word carries the meaning.
                const NourishlyChip(label: 'Planned'),
              ],
            ),
            for (final item in items) ...[
              const SizedBox(height: NourishlySpace.s3),
              _PlannedItemRow(item: item),
            ],
            const SizedBox(height: NourishlySpace.s3),
            Row(
              children: [
                Expanded(
                  child: Text(
                    energy == null
                        ? 'Not counted yet'
                        : '${energy.round()} kcal, not counted yet',
                    style: text.caption.copyWith(color: colors.ink3),
                  ),
                ),
              ],
            ),
            const SizedBox(height: NourishlySpace.s2),
            Wrap(
              spacing: NourishlySpace.s2,
              runSpacing: NourishlySpace.s2,
              children: [
                FilledButton(
                  onPressed: () => _confirmAll(context, ref),
                  child: Text(items.length == 1 ? 'Ate it' : 'Ate all of it'),
                ),
                OutlinedButton(
                  onPressed: () => _changeFirst(context),
                  child: const Text('Change'),
                ),
                TextButton(
                  onPressed: () => _skipAll(context, ref),
                  child: const Text('Skip'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAll(BuildContext context, WidgetRef ref) async {
    final dao = ref.read(foodLoggingDaoProvider);
    final ids = [for (final item in items) item.entry.id];
    for (final id in ids) {
      await dao.confirmEntry(id);
    }
    ref.read(summaryRevisionProvider.notifier).bump();
    if (!context.mounted) return;
    showNourishlySnack(
      context,
      '${items.first.mealSlotName} logged',
      actionLabel: 'Undo',
      onAction: () async {
        for (final id in ids) {
          await dao.unconfirmEntry(id);
        }
        ref.read(summaryRevisionProvider.notifier).bump();
      },
    );
  }

  Future<void> _skipAll(BuildContext context, WidgetRef ref) async {
    final dao = ref.read(foodLoggingDaoProvider);
    final ids = [for (final item in items) item.entry.id];
    for (final id in ids) {
      await dao.skipEntry(id);
    }
    ref.read(summaryRevisionProvider.notifier).bump();
    if (!context.mounted) return;
    showNourishlySnack(
      context,
      '${items.first.mealSlotName} skipped',
      actionLabel: 'Undo',
      onAction: () async {
        for (final id in ids) {
          await dao.unconfirmEntry(id);
        }
        ref.read(summaryRevisionProvider.notifier).bump();
      },
    );
  }

  void _changeFirst(BuildContext context) {
    // The portion screen, on the entry itself. It edits the plan in place
    // — rescaling the frozen snapshot, never re-reading the catalog — and
    // confirming afterwards is still one tap.
    final item = items.first;
    context.push(
      '/log/food/${item.entry.foodId}?entryId=${item.entry.id}'
      '&meal=${item.mealSlotId}',
    );
  }
}

class _PlannedItemRow extends ConsumerWidget {
  const _PlannedItemRow({required this.item});

  final PlannedFood item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    final serving = item.servingLabel;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.foodName, style: text.body),
              const SizedBox(height: 2),
              Text(
                serving == null
                    ? '${item.entry.gramsConsumed.round()} g'
                    : '${_quantityLabel(item.entry.quantity)} × $serving'
                          ' · ${item.entry.gramsConsumed.round()} g',
                style: text.caption.copyWith(color: colors.ink3),
              ),
            ],
          ),
        ),
        if (item.energyKcal case final kcal?)
          Text(
            '${kcal.round()} kcal',
            style: text.caption.copyWith(
              color: colors.ink3,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
      ],
    );
  }
}

String _quantityLabel(double quantity) => quantity == quantity.roundToDouble()
    ? quantity.round().toString()
    : quantity.toStringAsFixed(1);

/// [NourishlyCard]'s shape, drawn with a dashed edge.
///
/// Not a variant of the card component: this is the only place in the app
/// that draws one, and a `dashed` flag on a shared component would invite
/// a second.
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(NourishlyRadius.lg),
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (final metric in (Path()..addRRect(rect)).computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + 5).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + 4;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}
