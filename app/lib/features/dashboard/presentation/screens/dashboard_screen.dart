import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: colors.accentSoft,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.water_drop_rounded,
                          color: colors.accentSoftInk,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: NourishlySpace.s3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${(waterMl / 1000).toStringAsFixed(2)} L',
                              style: text.heading,
                            ),
                            Text(
                              'Water today',
                              style: text.caption.copyWith(color: colors.ink3),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.go('/water'),
                        child: const Text('Log water'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: NourishlySpace.s6),
              Text('MEALS', style: text.overline.copyWith(color: colors.ink3)),
              const SizedBox(height: NourishlySpace.s2),
              if (entries.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(NourishlySpace.s5),
                  decoration: BoxDecoration(
                    border: Border.all(color: colors.lineStrong, style: BorderStyle.solid),
                    borderRadius: BorderRadius.circular(NourishlyRadius.md),
                  ),
                  child: Text(
                    'Nothing logged yet — tap + to add something.',
                    textAlign: TextAlign.center,
                    style: text.body.copyWith(color: colors.ink3),
                  ),
                )
              else
                Card(
                  child: Column(
                    children: [
                      for (final logged in entries)
                        ListTile(
                          title: Text(logged.foodName, style: text.body),
                          subtitle: Text(
                            '${logged.mealSlotName} · ${logged.entry.quantity}× · ${logged.entry.gramsConsumed.toStringAsFixed(0)} g',
                            style: text.caption.copyWith(color: colors.ink3),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
