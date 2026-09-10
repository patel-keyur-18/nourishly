import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nourishly_ui/nourishly_ui.dart';

import '../../../../app/providers.dart';

/// A plain list of what's been logged today — not §27.2's real dashboard
/// (rings, macro bars, targets), which needs `nutrition_core`'s
/// aggregation and Phase 3's scoring engine. This exists so Phase 2's
/// logging is actually verifiable in the app rather than write-only.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    final entriesAsync = ref.watch(todayFoodLogProvider);
    final waterMl = ref.watch(todayWaterTotalProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Today')),
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('$error')),
        data: (entries) {
          return ListView(
            padding: const EdgeInsets.all(NourishlySpace.s4),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(NourishlySpace.s4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Water', style: text.body),
                      Text(
                        '${(waterMl / 1000).toStringAsFixed(2)} L',
                        style: text.heading,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: NourishlySpace.s4),
              Text('Meals', style: text.label.copyWith(color: colors.ink3)),
              const SizedBox(height: NourishlySpace.s2),
              if (entries.isEmpty)
                Text(
                  'Nothing logged yet — add something?',
                  style: text.body.copyWith(color: colors.ink3),
                ),
              for (final logged in entries)
                Card(
                  child: ListTile(
                    title: Text(logged.foodName),
                    subtitle: Text(
                      '${logged.mealSlotName} · ${logged.entry.quantity}× · ${logged.entry.gramsConsumed.toStringAsFixed(0)} g',
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
