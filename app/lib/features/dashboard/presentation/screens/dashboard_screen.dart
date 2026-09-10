import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nourishly_data/nourishly_data.dart';
import 'package:nourishly_ui/nourishly_ui.dart';

import '../../../../app/providers.dart';

/// The daily dashboard (prototype screen 3, option A — ring-led).
///
/// Energy targets, macro targets and the daily score all come from Phase
/// 3's target derivation and scoring engine, which do not exist yet. Until
/// they do this screen shows what it genuinely knows — what was logged
/// today — and says so, rather than inventing a target to draw a ring
/// against (AP-4: unknown is never zero, and never a made-up number).
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(todayFoodLogProvider);
    final waterMl = ref.watch(todayWaterTotalProvider);
    final today = ref.watch(todayProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: entriesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _ErrorBody(error: error),
          data: (entries) => ListView(
            padding: const EdgeInsets.fromLTRB(
              NourishlySpace.s4,
              NourishlySpace.s2,
              NourishlySpace.s4,
              NourishlySpace.s7,
            ),
            children: [
              _DayHeader(date: today),
              const SizedBox(height: NourishlySpace.s4),
              _EnergyCard(entries: entries),
              const SizedBox(height: NourishlySpace.s3),
              _WaterCard(totalMl: waterMl),
              const NourishlySectionHeader(label: 'Meals'),
              _MealsCard(entries: entries),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.date});

  final DateTime date;

  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_weekdays[date.weekday - 1]}, ${date.day} ${_months[date.month - 1]}',
                style: text.caption.copyWith(color: colors.ink3),
              ),
              const SizedBox(height: 2),
              Text('Today', style: text.title),
            ],
          ),
        ),
        const SizedBox(width: NourishlySpace.s2),
        // The daily score needs the scoring engine (Phase 3); until then
        // the slot says so rather than showing a number nothing computed.
        const Flexible(
          child: StatusChip(
            label: 'Not scored yet',
            status: NourishlyStatus.unknown,
          ),
        ),
      ],
    );
  }
}

class _EnergyCard extends StatelessWidget {
  const _EnergyCard({required this.entries});

  final List<LoggedFood> entries;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    final grams = entries.fold<double>(
      0,
      (sum, e) => sum + e.entry.gramsConsumed,
    );

    return NourishlyCard(
      child: Row(
        children: [
          Container(
            width: 96,
            height: 96,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.surface2,
              shape: BoxShape.circle,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${entries.length}',
                  style: text.numeral.copyWith(height: 1),
                ),
                const SizedBox(height: 2),
                Text(
                  entries.length == 1 ? 'item' : 'items',
                  style: text.caption.copyWith(color: colors.ink3, height: 1),
                ),
              ],
            ),
          ),
          const SizedBox(width: NourishlySpace.s4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _KeyValue(
                  label: 'Logged',
                  value: '${grams.toStringAsFixed(0)} g',
                ),
                const SizedBox(height: NourishlySpace.s2),
                Text(
                  'Energy and macro targets arrive with Phase 3 scoring. '
                  'Nothing here is estimated in the meantime.',
                  style: text.caption.copyWith(color: colors.ink3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KeyValue extends StatelessWidget {
  const _KeyValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: text.caption.copyWith(color: colors.ink3)),
        Text(value, style: text.body.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _WaterCard extends ConsumerWidget {
  const _WaterCard({required this.totalMl});

  final double totalMl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;

    return NourishlyCard(
      child: Column(
        children: [
          Row(
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
                      '${(totalMl / 1000).toStringAsFixed(2)} L',
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
                child: const Text('Open'),
              ),
            ],
          ),
          const SizedBox(height: NourishlySpace.s3),
          Row(
            children: [
              Expanded(
                child: QuickAddButton(
                  label: '+250 ml',
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
            ],
          ),
        ],
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

class _MealsCard extends StatelessWidget {
  const _MealsCard({required this.entries});

  final List<LoggedFood> entries;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;

    if (entries.isEmpty) {
      return NourishlyCard(
        padding: const EdgeInsets.symmetric(
          horizontal: NourishlySpace.s4,
          vertical: NourishlySpace.s7,
        ),
        child: Column(
          children: [
            Icon(Icons.restaurant_rounded, color: colors.ink3, size: 26),
            const SizedBox(height: NourishlySpace.s3),
            Text(
              'Nothing logged yet',
              style: text.body.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: NourishlySpace.s1),
            Text(
              'Tap + to add your first food or drink.',
              textAlign: TextAlign.center,
              style: text.caption.copyWith(color: colors.ink3),
            ),
          ],
        ),
      );
    }

    // Group by meal slot, preserving the order the slots were logged in.
    final bySlot = <String, List<LoggedFood>>{};
    for (final logged in entries) {
      (bySlot[logged.mealSlotName] ??= []).add(logged);
    }

    return NourishlyCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final slot in bySlot.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                NourishlySpace.s4,
                NourishlySpace.s3,
                NourishlySpace.s4,
                NourishlySpace.s1,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    slot.key,
                    style: text.overline.copyWith(color: colors.ink3),
                  ),
                  Text(
                    '${slot.value.length} ${slot.value.length == 1 ? 'item' : 'items'}',
                    style: text.caption.copyWith(color: colors.ink3),
                  ),
                ],
              ),
            ),
            for (final logged in slot.value) _LoggedFoodRow(logged: logged),
          ],
        ],
      ),
    );
  }
}

/// One logged food, with the two corrections FR-M-05 requires: swipe to
/// remove (with inline undo, UX-7 — never a confirmation dialog), or tap
/// to change the portion and meal.
class _LoggedFoodRow extends ConsumerWidget {
  const _LoggedFoodRow({required this.logged});

  final LoggedFood logged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    final quantity = logged.entry.quantity;

    return Dismissible(
      key: ValueKey(logged.entry.id),
      direction: DismissDirection.endToStart,
      background: ColoredBox(
        color: colors.dangerSoft,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: NourishlySpace.s4),
          child: Align(
            alignment: Alignment.centerRight,
            child: Icon(Icons.delete_outline_rounded, color: colors.danger),
          ),
        ),
      ),
      onDismissed: (_) => _remove(context, ref),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _edit(context, ref),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              NourishlySpace.s4,
              NourishlySpace.s2,
              NourishlySpace.s4,
              NourishlySpace.s2,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    logged.foodName,
                    style: text.body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: NourishlySpace.s2),
                Text(
                  '${quantity.toStringAsFixed(quantity % 1 == 0 ? 0 : 1)}× · '
                  '${logged.entry.gramsConsumed.toStringAsFixed(0)} g',
                  style: text.caption.copyWith(color: colors.ink3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final dao = ref.read(foodLoggingDaoProvider);
    await dao.deleteEntry(logged.entry.id);
    messenger.showSnackBar(
      SnackBar(
        content: Text('Removed ${logged.foodName}'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => dao.restore(logged.entry.id),
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _EditEntrySheet(logged: logged),
    );
  }
}

class _EditEntrySheet extends ConsumerStatefulWidget {
  const _EditEntrySheet({required this.logged});

  final LoggedFood logged;

  @override
  ConsumerState<_EditEntrySheet> createState() => _EditEntrySheetState();
}

class _EditEntrySheetState extends ConsumerState<_EditEntrySheet> {
  late double _quantity = widget.logged.entry.quantity;
  late String _mealSlotId = widget.logged.entry.mealSlotId;
  bool _saving = false;

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    await ref
        .read(foodLoggingDaoProvider)
        .updateEntry(
          entryId: widget.logged.entry.id,
          quantity: _quantity,
          mealSlotId: _mealSlotId,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    final gramsPerUnit = widget.logged.entry.quantity == 0
        ? 0.0
        : widget.logged.entry.gramsConsumed / widget.logged.entry.quantity;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          NourishlySpace.s4,
          0,
          NourishlySpace.s4,
          NourishlySpace.s4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.logged.foodName,
              style: text.heading,
              textAlign: TextAlign.center,
            ),
            const NourishlySectionHeader(label: 'Quantity'),
            Row(
              children: [
                IconButton(
                  onPressed: _quantity > 0.5
                      ? () => setState(() => _quantity -= 0.5)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                  iconSize: 30,
                  color: colors.accent,
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        _quantity.toStringAsFixed(_quantity % 1 == 0 ? 0 : 1),
                        style: text.display.copyWith(height: 1),
                      ),
                      const SizedBox(height: NourishlySpace.s1),
                      Text(
                        '${(gramsPerUnit * _quantity).toStringAsFixed(0)} g',
                        style: text.caption.copyWith(color: colors.ink3),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _quantity += 0.5),
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  iconSize: 30,
                  color: colors.accent,
                ),
              ],
            ),
            const NourishlySectionHeader(label: 'Meal'),
            ref
                .watch(mealSlotsProvider)
                .when(
                  loading: () => const LinearProgressIndicator(),
                  error: (error, _) => Text('$error', style: text.caption),
                  data: (slots) => Wrap(
                    spacing: NourishlySpace.s2,
                    runSpacing: NourishlySpace.s2,
                    children: [
                      for (final slot in slots)
                        ChoiceChip(
                          label: Text(slot.displayName),
                          selected: _mealSlotId == slot.id,
                          onSelected: (_) =>
                              setState(() => _mealSlotId = slot.id),
                        ),
                    ],
                  ),
                ),
            const SizedBox(height: NourishlySpace.s5),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save changes'),
            ),
          ],
        ),
      ),
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
