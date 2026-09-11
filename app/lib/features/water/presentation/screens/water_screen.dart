import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nourishly_data/nourishly_data.dart';
import 'package:nourishly_ui/nourishly_ui.dart';

import '../../../../app/providers.dart';

/// Hydration logging (prototype screen 8, option A — fill visual).
///
/// Quick-add chips, a vessel that fills as you drink, and today's entries
/// with inline undo (UX-7). Works standalone with no nutrition setup
/// (Persona 4, §28.3).
class WaterScreen extends ConsumerWidget {
  const WaterScreen({super.key});

  /// A placeholder daily goal so the fill visual has a proportion to show.
  /// Real per-profile hydration targets are derived in Phase 3 (§27.12);
  /// this is labelled as a default in the UI rather than presented as a
  /// derived target.
  static const double defaultGoalMl = 2600;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    final entriesAsync = ref.watch(todayWaterLogProvider);
    final totalMl = ref.watch(todayWaterTotalProvider);
    final percent = ((totalMl / defaultGoalMl) * 100).clamp(0, 999).round();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: entriesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Padding(
              padding: const EdgeInsets.all(NourishlySpace.s6),
              child: Text(
                'Water log could not be loaded.\n$error',
                textAlign: TextAlign.center,
                style: text.caption.copyWith(color: colors.ink3),
              ),
            ),
          ),
          data: (entries) => ListView(
            padding: const EdgeInsets.fromLTRB(
              NourishlySpace.s4,
              NourishlySpace.s2,
              NourishlySpace.s4,
              NourishlySpace.s7,
            ),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text('Water', style: text.title)),
                  const SizedBox(width: NourishlySpace.s2),
                  Flexible(
                    child: StatusChip(
                      label: '$percent% of default',
                      status: percent >= 100
                          ? NourishlyStatus.ok
                          : NourishlyStatus.low,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: NourishlySpace.s4),
              NourishlyCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: NourishlySpace.s4,
                  vertical: NourishlySpace.s5,
                ),
                child: Column(
                  children: [
                    WaterVessel(totalMl: totalMl, goalMl: defaultGoalMl),
                    const SizedBox(height: NourishlySpace.s4),
                    Row(
                      children: [
                        Expanded(
                          child: QuickAddButton(
                            label: '+250 ml',
                            emphasised: true,
                            onPressed: () => _quickAdd(context, ref, 250),
                          ),
                        ),
                        const SizedBox(width: NourishlySpace.s2),
                        Expanded(
                          child: QuickAddButton(
                            label: '+500 ml',
                            onPressed: () => _quickAdd(context, ref, 500),
                          ),
                        ),
                        const SizedBox(width: NourishlySpace.s2),
                        Expanded(
                          child: QuickAddButton(
                            label: '+1 L',
                            onPressed: () => _quickAdd(context, ref, 1000),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const NourishlySectionHeader(label: 'Today'),
              if (entries.isEmpty)
                NourishlyCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: NourishlySpace.s4,
                    vertical: NourishlySpace.s6,
                  ),
                  child: Center(
                    child: Text(
                      'Nothing logged yet — tap a quick-add above.',
                      textAlign: TextAlign.center,
                      style: text.caption.copyWith(color: colors.ink3),
                    ),
                  ),
                )
              else
                NourishlyCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < entries.length; i++) ...[
                        if (i > 0)
                          Divider(height: 1, thickness: 1, color: colors.line),
                        _WaterRow(entry: entries[i]),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: NourishlySpace.s4),
              Text(
                'Chaas and tea count toward hydration. Coffee counts at a '
                'lower rate (FR-W-09).',
                style: text.caption.copyWith(color: colors.ink3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _quickAdd(BuildContext context, WidgetRef ref, double ml) async {
    final messenger = ScaffoldMessenger.of(context);
    final ownerId = await ref.read(defaultOwnerProvider.future);
    await ref
        .read(waterLogDaoProvider)
        .logWater(
          ownerId: ownerId,
          volumeMl: ml,
          logDate: ref.read(todayProvider),
        );
    messenger.showSnackBar(
      SnackBar(content: Text('Logged ${ml.toStringAsFixed(0)} ml')),
    );
  }
}

class _WaterRow extends ConsumerWidget {
  const _WaterRow({required this.entry});

  final WaterLogEntry entry;

  static String _formatTime(DateTime time) {
    final hour12 = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour12:$minute ${time.hour < 12 ? 'AM' : 'PM'}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        // Tap to correct the amount (FR-W-07).
        onTap: () => _edit(context, ref),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: NourishlySpace.s4,
            vertical: NourishlySpace.s3,
          ),
          child: Row(
            children: [
              Icon(Icons.water_drop_rounded, color: colors.accent, size: 18),
              const SizedBox(width: NourishlySpace.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${entry.volumeMl.toStringAsFixed(0)} ml',
                      style: text.body.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      _formatTime(entry.loggedAt),
                      style: text.caption.copyWith(color: colors.ink3),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _remove(context, ref),
                child: const Text('Remove'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final dao = ref.read(waterLogDaoProvider);
    await dao.undo(entry.id);
    messenger.showSnackBar(
      SnackBar(
        content: Text('Removed ${entry.volumeMl.toStringAsFixed(0)} ml'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => dao.restore(entry.id),
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final newVolume = await showDialog<double>(
      context: context,
      builder: (context) => _EditVolumeDialog(initialMl: entry.volumeMl),
    );
    if (newVolume == null) return;
    await ref
        .read(waterLogDaoProvider)
        .edit(entryId: entry.id, volumeMl: newVolume);
  }
}

class _EditVolumeDialog extends StatefulWidget {
  const _EditVolumeDialog({required this.initialMl});

  final double initialMl;

  @override
  State<_EditVolumeDialog> createState() => _EditVolumeDialogState();
}

class _EditVolumeDialogState extends State<_EditVolumeDialog> {
  late final _controller = TextEditingController(
    text: widget.initialMl.toStringAsFixed(0),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = double.tryParse(_controller.text.trim());
    if (value == null || value <= 0) return;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit amount'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onSubmitted: (_) => _submit(),
        decoration: const InputDecoration(
          labelText: 'Millilitres',
          suffixText: 'ml',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
