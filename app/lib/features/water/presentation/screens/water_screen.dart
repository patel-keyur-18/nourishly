import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nourishly_ui/nourishly_ui.dart';

import '../../../../app/providers.dart';

String _formatTime(DateTime time) {
  final hour12 = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour12:$minute ${time.hour < 12 ? 'AM' : 'PM'}';
}

/// Hydration logging (§27.7) — quick-add chips, a running total, and
/// today's entries with inline undo (UX-7). No nutrition setup required;
/// works standalone (Persona 4, §28.3).
class WaterScreen extends ConsumerWidget {
  const WaterScreen({super.key});

  Future<void> _quickAdd(BuildContext context, WidgetRef ref, double ml) async {
    final ownerId = await ref.read(defaultOwnerProvider.future);
    await ref
        .read(waterLogDaoProvider)
        .logWater(
          ownerId: ownerId,
          volumeMl: ml,
          logDate: ref.read(todayProvider),
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logged ${ml.toStringAsFixed(0)} ml')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    final entriesAsync = ref.watch(todayWaterLogProvider);
    final totalMl = ref.watch(todayWaterTotalProvider);
    final dao = ref.watch(waterLogDaoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Water')),
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('$error')),
        data: (entries) {
          return ListView(
            padding: const EdgeInsets.all(NourishlySpace.s4),
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: NourishlySpace.s6),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(NourishlyRadius.lg),
                  border: Border.all(color: colors.line),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: colors.accentSoft,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          (totalMl / 1000).toStringAsFixed(2),
                          style: text.numeral.copyWith(color: colors.accentSoftInk),
                        ),
                      ),
                      const SizedBox(height: NourishlySpace.s3),
                      Text(
                        'litres today',
                        style: text.caption.copyWith(color: colors.ink3),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: NourishlySpace.s5),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _quickAdd(context, ref, 250),
                      child: const Text('+250 ml'),
                    ),
                  ),
                  const SizedBox(width: NourishlySpace.s2),
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: () => _quickAdd(context, ref, 500),
                      child: const Text('+500 ml'),
                    ),
                  ),
                  const SizedBox(width: NourishlySpace.s2),
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: () => _quickAdd(context, ref, 1000),
                      child: const Text('+1 L'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: NourishlySpace.s6),
              Text(
                'TODAY',
                style: text.overline.copyWith(color: colors.ink3),
              ),
              const SizedBox(height: NourishlySpace.s2),
              if (entries.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: NourishlySpace.s4),
                  child: Text(
                    'Nothing logged yet — tap a quick-add above.',
                    style: text.body.copyWith(color: colors.ink3),
                  ),
                )
              else
                Card(
                  child: Column(
                    children: [
                      for (final entry in entries)
                        ListTile(
                          leading: Icon(
                            Icons.water_drop_rounded,
                            color: colors.accent,
                            size: 20,
                          ),
                          title: Text(
                            '${entry.volumeMl.toStringAsFixed(0)} ml',
                            style: text.body,
                          ),
                          subtitle: Text(
                            _formatTime(entry.loggedAt),
                            style: text.caption.copyWith(color: colors.ink3),
                          ),
                          trailing: TextButton(
                            onPressed: () => dao.undo(entry.id),
                            child: const Text('Undo'),
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
