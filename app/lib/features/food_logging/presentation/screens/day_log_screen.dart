import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nourishly_data/nourishly_data.dart';
import 'package:nourishly_ui/nourishly_ui.dart';

import '../../../../app/providers.dart';
import '../../../../shared/formatting.dart';
import '../../../meal_templates/data/meal_template_providers.dart';

/// Today's entries in the order they were logged (design option C, chosen
/// 2026-09-17) — not in the original 13-screen set. The dashboard's meal
/// rows only open the search flow; this is the missing surface for seeing
/// and changing what is already logged.
///
/// Reads the live [todayFoodLogProvider] stream rather than the
/// materialised [DaySummary] (§27.2 reserves that for the dashboard): a
/// screen whose whole job is per-entry edits needs the entries themselves.
class DayLogScreen extends ConsumerStatefulWidget {
  const DayLogScreen({super.key});

  @override
  ConsumerState<DayLogScreen> createState() => _DayLogScreenState();
}

class _DayLogScreenState extends ConsumerState<DayLogScreen> {
  bool _groupByMeal = false;

  @override
  Widget build(BuildContext context) {
    final date = ref.watch(todayProvider);
    final loggedAsync = ref.watch(todayFoodLogProvider);
    // Read here, not just inside the .when() below, so the action is
    // available regardless of the By-time/By-meal toggle — "Save as
    // template" used to only exist inside the By-meal view, which a
    // first-timer on the default By-time view had no reason to find.
    final entries = loggedAsync.value ?? const <LoggedFood>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(formatLongDate(date)),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_add_outlined),
            tooltip: 'Save a meal as a template',
            onPressed: entries.isEmpty
                ? null
                : () => _pickMealToSaveAsTemplate(context, ref, entries),
          ),
        ],
      ),
      body: loggedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (entries) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                NourishlySpace.s4,
                NourishlySpace.s3,
                NourishlySpace.s4,
                0,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _GroupingToggle(
                  groupByMeal: _groupByMeal,
                  onChanged: (value) => setState(() => _groupByMeal = value),
                ),
              ),
            ),
            Expanded(
              child: entries.isEmpty
                  ? const _EmptyLog()
                  : (_groupByMeal
                        ? _ByMealList(entries: entries)
                        : _TimelineList(entries: entries)),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupingToggle extends StatelessWidget {
  const _GroupingToggle({required this.groupByMeal, required this.onChanged});

  final bool groupByMeal;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(NourishlyRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ToggleSegment(
              label: 'By time',
              selected: !groupByMeal,
              onTap: () => onChanged(false),
            ),
            _ToggleSegment(
              label: 'By meal',
              selected: groupByMeal,
              onTap: () => onChanged(true),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleSegment extends StatelessWidget {
  const _ToggleSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    return Material(
      color: selected ? colors.accent : Colors.transparent,
      borderRadius: BorderRadius.circular(NourishlyRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(NourishlyRadius.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            label,
            style: text.label.copyWith(
              color: selected ? colors.accentInk : colors.ink3,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyLog extends StatelessWidget {
  const _EmptyLog();

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(NourishlySpace.s6),
        child: Text(
          'Nothing logged yet today.',
          style: text.body.copyWith(color: colors.ink3),
        ),
      ),
    );
  }
}

/// Earliest first — "the day as it happened" reads top to bottom, and
/// [FoodLoggingDao.watchToday] hands back newest-first for the dashboard's
/// "what's most recent" use, which is the opposite of what a diary wants.
class _TimelineList extends StatelessWidget {
  const _TimelineList({required this.entries});

  final List<LoggedFood> entries;

  @override
  Widget build(BuildContext context) {
    final ordered = entries.reversed.toList();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        NourishlySpace.s4,
        NourishlySpace.s3,
        NourishlySpace.s4,
        NourishlySpace.s7,
      ),
      itemCount: ordered.length,
      itemBuilder: (context, index) => _TimelineRow(
        food: ordered[index],
        isLast: index == ordered.length - 1,
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.food, required this.isLast});

  final LoggedFood food;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            child: Padding(
              padding: const EdgeInsets.only(top: 15),
              child: Text(
                formatTime(food.entry.loggedAt),
                textAlign: TextAlign.right,
                style: text.caption.copyWith(color: colors.ink3),
              ),
            ),
          ),
          const SizedBox(width: NourishlySpace.s2),
          Column(
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 17),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.accent,
                ),
              ),
              if (!isLast)
                Expanded(child: Container(width: 2, color: colors.line)),
            ],
          ),
          const SizedBox(width: NourishlySpace.s3),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: NourishlySpace.s4),
              child: _EntryCard(food: food),
            ),
          ),
        ],
      ),
    );
  }
}

/// Grouped in the app's fixed slot order (§22.5), like the dashboard and
/// the report — an empty slot still gets a row rather than disappearing,
/// so "did I forget dinner" is answered by looking, not by its absence.
class _ByMealList extends ConsumerWidget {
  const _ByMealList({required this.entries});

  final List<LoggedFood> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slotsAsync = ref.watch(mealSlotsProvider);
    return slotsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('$error')),
      data: (slots) => ListView(
        padding: const EdgeInsets.fromLTRB(
          NourishlySpace.s4,
          NourishlySpace.s3,
          NourishlySpace.s4,
          NourishlySpace.s7,
        ),
        children: [
          for (final slot in slots) ...[
            Builder(
              builder: (context) {
                final slotEntries = entries
                    .where((e) => e.entry.mealSlotId == slot.id)
                    .toList();
                return NourishlySectionHeader(
                  label: slot.displayName,
                  actionLabel: slotEntries.isEmpty ? null : 'Save as template',
                  onActionPressed: slotEntries.isEmpty
                      ? null
                      : () => _saveAsTemplate(context, ref, slot, slotEntries),
                );
              },
            ),
            for (final food in entries.where(
              (e) => e.entry.mealSlotId == slot.id,
            ))
              Padding(
                padding: const EdgeInsets.only(bottom: NourishlySpace.s3),
                child: _EntryCard(food: food, showMealChip: false),
              ),
            if (!entries.any((e) => e.entry.mealSlotId == slot.id))
              Padding(
                padding: const EdgeInsets.only(bottom: NourishlySpace.s3),
                child: Text(
                  'Nothing logged',
                  style: context.nourishlyText.caption.copyWith(
                    color: context.nourishlyColors.ink3,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// One logged entry: the meal chip (tap to move it to another meal) above
/// a row that opens edit/delete. Two siblings, not one nested tap target,
/// so the chip's tap never fights the row's.
class _EntryCard extends ConsumerWidget {
  const _EntryCard({required this.food, this.showMealChip = true});

  final LoggedFood food;
  final bool showMealChip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return NourishlyCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showMealChip)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                NourishlySpace.s4,
                NourishlySpace.s3,
                NourishlySpace.s4,
                0,
              ),
              child: _MealChip(food: food),
            ),
          NourishlyListRow(
            title: food.foodName,
            subtitle: '${food.entry.gramsConsumed.round()} g',
            value: '${formatThousands(food.energyKcal)} kcal',
            onTap: () => _showEntryActions(context, ref, food),
          ),
        ],
      ),
    );
  }
}

class _MealChip extends ConsumerWidget {
  const _MealChip({required this.food});

  final LoggedFood food;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    return Material(
      color: colors.accentSoft,
      borderRadius: BorderRadius.circular(NourishlyRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(NourishlyRadius.pill),
        onTap: () => _reassignMeal(context, ref, food),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Text(
            food.mealSlotName,
            style: text.label.copyWith(color: colors.accentSoftInk),
          ),
        ),
      ),
    );
  }
}

Future<void> _reassignMeal(
  BuildContext context,
  WidgetRef ref,
  LoggedFood food,
) async {
  final slots = await ref.read(mealSlotsProvider.future);
  if (!context.mounted) return;
  final chosen = await showNourishlyOptions<String>(
    context: context,
    title: 'Move to meal',
    selected: food.entry.mealSlotId,
    options: [
      for (final slot in slots)
        NourishlyOption(value: slot.id, label: slot.displayName),
    ],
  );
  if (chosen == null || chosen == food.entry.mealSlotId) return;
  await ref
      .read(foodLoggingDaoProvider)
      .updateEntry(entryId: food.entry.id, mealSlotId: chosen);
}

Future<void> _showEntryActions(
  BuildContext context,
  WidgetRef ref,
  LoggedFood food,
) async {
  final colors = context.nourishlyColors;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: colors.surface,
    builder: (sheetContext) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          NourishlySpace.s4,
          0,
          NourishlySpace.s4,
          NourishlySpace.s4,
        ),
        child: NourishlyRowGroup(
          children: [
            NourishlyListRow(
              title: 'Edit portion',
              subtitle: food.foodName,
              style: NourishlyRowStyle.accent,
              showChevron: false,
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.push(
                  '/log/food/${food.entry.foodId}?entryId=${food.entry.id}',
                );
              },
            ),
            NourishlyListRow(
              title: 'Delete entry',
              style: NourishlyRowStyle.danger,
              showChevron: false,
              onTap: () {
                Navigator.of(sheetContext).pop();
                _deleteEntry(context, ref, food);
              },
            ),
          ],
        ),
      ),
    ),
  );
}

/// The AppBar action's entry point — available in both the By-time and
/// By-meal views. Picks a meal slot from today's entries (mirroring
/// [_reassignMeal]'s slot-picker sheet), then hands off to
/// [_saveAsTemplate] exactly as the By-meal view's inline action does.
Future<void> _pickMealToSaveAsTemplate(
  BuildContext context,
  WidgetRef ref,
  List<LoggedFood> entries,
) async {
  final slots = await ref.read(mealSlotsProvider.future);
  final withEntries = [
    for (final slot in slots)
      if (entries.any((e) => e.entry.mealSlotId == slot.id)) slot,
  ];
  if (withEntries.isEmpty || !context.mounted) return;

  final chosen = await showNourishlyOptions<String>(
    context: context,
    title: 'Save which meal as a template?',
    options: [
      for (final slot in withEntries)
        NourishlyOption(value: slot.id, label: slot.displayName),
    ],
  );
  if (chosen == null || !context.mounted) return;

  final slot = withEntries.firstWhere((s) => s.id == chosen);
  final slotEntries = entries
      .where((e) => e.entry.mealSlotId == chosen)
      .toList();
  await _saveAsTemplate(context, ref, slot, slotEntries);
}

Future<void> _saveAsTemplate(
  BuildContext context,
  WidgetRef ref,
  MealSlot slot,
  List<LoggedFood> entries,
) async {
  final name = await showNourishlyPrompt(
    context: context,
    title: 'Save as template',
    message:
        '${entries.length} item${entries.length == 1 ? '' : 's'} from '
        '${slot.displayName} will be saved as "${slot.displayName}" — you '
        'can rename it.',
    initialValue: slot.displayName,
    label: 'Template name',
  );
  if (name == null || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  final ownerId = await ref.read(defaultOwnerProvider.future);
  await ref
      .read(mealTemplateDaoProvider)
      .createFromEntries(
        ownerId: ownerId,
        name: name,
        defaultMealSlotId: slot.id,
        items: [
          for (final food in entries)
            MealTemplateItemInput(
              foodId: food.entry.foodId,
              servingSizeId: food.entry.servingSizeId,
              quantity: food.entry.quantity,
            ),
        ],
      );
  ref.read(mealTemplateRevisionProvider.notifier).bump();
  if (!context.mounted) return;
  showNourishlySnackOn(messenger, 'Saved "$name" as a template.');
}

Future<void> _deleteEntry(
  BuildContext context,
  WidgetRef ref,
  LoggedFood food,
) async {
  final confirmed = await showNourishlyConfirm(
    context: context,
    title: 'Delete this entry?',
    message: '${food.foodName} will be removed from today’s log.',
    confirmLabel: 'Delete',
    danger: true,
  );
  if (!confirmed || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  final dao = ref.read(foodLoggingDaoProvider);
  await dao.deleteEntry(food.entry.id);
  showNourishlySnackOn(
    messenger,
    'Removed ${food.foodName}',
    actionLabel: 'Undo',
    onAction: () => dao.restore(food.entry.id),
  );
}
