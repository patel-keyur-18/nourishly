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

  Future<void> _quickAdd(WidgetRef ref, double ml) async {
    final ownerId = await ref.read(defaultOwnerProvider.future);
    await ref
        .read(waterLogDaoProvider)
        .logWater(
          ownerId: ownerId,
          volumeMl: ml,
          logDate: ref.read(todayProvider),
        );
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
              Center(
                child: Column(
                  children: [
                    Text(
                      '${(totalMl / 1000).toStringAsFixed(2)} L',
                      style: text.display,
                    ),
                    Text(
                      'today',
                      style: text.caption.copyWith(color: colors.ink3),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: NourishlySpace.s5),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _quickAdd(ref, 250),
                      child: const Text('+250 ml'),
                    ),
                  ),
                  const SizedBox(width: NourishlySpace.s2),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _quickAdd(ref, 500),
                      child: const Text('+500 ml'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: NourishlySpace.s6),
              Text('Today', style: text.label.copyWith(color: colors.ink3)),
              const SizedBox(height: NourishlySpace.s2),
              if (entries.isEmpty)
                Text(
                  'Nothing logged yet.',
                  style: text.body.copyWith(color: colors.ink3),
                ),
              for (final entry in entries)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${entry.volumeMl.toStringAsFixed(0)} ml'),
                  subtitle: Text(_formatTime(entry.loggedAt)),
                  trailing: TextButton(
                    onPressed: () => dao.undo(entry.id),
                    child: const Text('Undo'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
