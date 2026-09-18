import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nourishly_data/nourishly_data.dart';
import 'package:nourishly_ui/nourishly_ui.dart';

import '../../../../app/providers.dart';
import '../../../../shared/formatting.dart';
import '../../../meal_templates/data/meal_template_providers.dart';
import '../../data/meal_plan_providers.dart';
import '../widgets/plan_projection_card.dart';

/// Screen 14 — the week plan (design option B, chosen 2026-09-18).
///
/// A rail of day chips for orientation, one day's meal slots in full
/// underneath. The two rejected layouts are in the proposal: a 7×4 grid,
/// which cannot carry a dish called "methi na gota", and a continuous
/// scroll, which has nowhere to put the per-day projection — and that
/// projection is the reason the screen exists. Seeing on Sunday that
/// Tuesday lands 40% short on iron is the whole point; a list of what you
/// intend to cook is just a note.
///
/// Pushed over the shell like `/recipes` and `/templates` rather than made
/// a fifth tab: [NourishlyBottomNav] is four destinations around the
/// centre action by construction (prototype screen 3), and a fifth is a
/// redesign of an approved screen, not a side effect of a feature.
class WeekPlanScreen extends ConsumerWidget {
  const WeekPlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekStart = ref.watch(planWeekStartProvider);
    final selectedDay = ref.watch(planSelectedDayProvider);
    final entriesAsync = ref.watch(planWeekEntriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Week plan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            tooltip: 'Previous week',
            onPressed: () =>
                ref.read(planWeekStartProvider.notifier).shiftBy(-1),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            tooltip: 'Next week',
            onPressed: () =>
                ref.read(planWeekStartProvider.notifier).shiftBy(1),
          ),
        ],
      ),
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (entries) => ListView(
          padding: const EdgeInsets.fromLTRB(
            NourishlySpace.s4,
            NourishlySpace.s3,
            NourishlySpace.s4,
            NourishlySpace.s7,
          ),
          children: [
            _WeekHeader(weekStart: weekStart, entries: entries),
            const SizedBox(height: NourishlySpace.s3),
            _DayRail(
              weekStart: weekStart,
              selectedDay: selectedDay,
              entries: entries,
              onSelect: (date) =>
                  ref.read(planSelectedDayProvider.notifier).select(date),
            ),
            const SizedBox(height: NourishlySpace.s4),
            _DayAgenda(date: selectedDay, entries: entries),
            const SizedBox(height: NourishlySpace.s3),
            PlanProjectionCard(date: selectedDay),
          ],
        ),
      ),
    );
  }
}

/// The week's range, how much of it is filled, and the one-tap start.
class _WeekHeader extends ConsumerWidget {
  const _WeekHeader({required this.weekStart, required this.entries});

  final DateTime weekStart;
  final List<PlannedFood> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    final weekEnd = weekStart.add(const Duration(days: 6));
    final plannedDays = {
      for (final e in entries)
        if (e.isPlanned) e.entry.logDate,
    }.length;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${monthAbbreviation(weekStart.month)} ${weekStart.day} – '
                '${monthAbbreviation(weekEnd.month)} ${weekEnd.day}',
                style: text.title,
              ),
              const SizedBox(height: 2),
              Text(
                plannedDays == 0
                    ? 'Nothing planned yet'
                    : '$plannedDays of 7 days planned',
                style: text.caption.copyWith(color: colors.ink3),
              ),
            ],
          ),
        ),
        TextButton.icon(
          icon: const Icon(Icons.content_copy_rounded, size: 18),
          label: const Text('Copy last week'),
          onPressed: () => _copyLastWeek(context, ref, weekStart),
        ),
      ],
    );
  }

  Future<void> _copyLastWeek(
    BuildContext context,
    WidgetRef ref,
    DateTime weekStart,
  ) async {
    final ownerId = await ref.read(defaultOwnerProvider.future);
    final written = await ref
        .read(mealPlanDaoProvider)
        .copyWeek(
          ownerId: ownerId,
          fromWeekStart: weekStart.subtract(const Duration(days: 7)),
          toWeekStart: weekStart,
        );
    if (!context.mounted) return;
    showNourishlySnack(
      context,
      // Specific about *why* nothing happened: "0 copied" leaves you
      // guessing between an empty source week and a target week that was
      // deliberately left alone.
      written == 0
          ? 'Nothing to copy — last week is empty, or these days are '
                'already planned'
          : 'Planned $written ${written == 1 ? 'meal' : 'meals'} from last week',
    );
  }
}

/// Seven chips, each saying what state its day is in without relying on
/// colour to say it: the dot is paired with the day number, and the
/// semantics label spells the state out.
class _DayRail extends StatelessWidget {
  const _DayRail({
    required this.weekStart,
    required this.selectedDay,
    required this.entries,
    required this.onSelect,
  });

  final DateTime weekStart;
  final DateTime selectedDay;
  final List<PlannedFood> entries;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < 7; i++) ...[
          if (i > 0) const SizedBox(width: NourishlySpace.s1 + 2),
          Expanded(
            child: _DayChip(
              date: weekStart.add(Duration(days: i)),
              selected: _isSameDay(
                weekStart.add(Duration(days: i)),
                selectedDay,
              ),
              entries: entries,
              onTap: onSelect,
            ),
          ),
        ],
      ],
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.date,
    required this.selected,
    required this.entries,
    required this.onTap,
  });

  final DateTime date;
  final bool selected;
  final List<PlannedFood> entries;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    final forDay = [
      for (final e in entries)
        if (_isSameDay(e.entry.logDate, date)) e,
    ];
    final hasPlanned = forDay.any((e) => e.isPlanned);
    final hasEaten = forDay.any((e) => e.isEaten);

    final (dotColor, state) = switch ((hasEaten, hasPlanned)) {
      (true, true) => (colors.statusOk, 'part eaten, part planned'),
      (true, false) => (colors.statusOk, 'eaten'),
      (false, true) => (colors.accent, 'planned'),
      _ => (colors.line, 'nothing planned'),
    };

    return Semantics(
      button: true,
      selected: selected,
      label: '${weekdayName(date.weekday)} ${date.day}, $state',
      excludeSemantics: true,
      child: Material(
        color: selected ? colors.accent : colors.surface,
        borderRadius: BorderRadius.circular(NourishlyRadius.md),
        child: InkWell(
          onTap: () => onTap(date),
          borderRadius: BorderRadius.circular(NourishlyRadius.md),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(NourishlyRadius.md),
              border: Border.all(
                color: selected ? colors.accent : colors.line,
                width: NourishlyStroke.hairline,
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: NourishlySpace.s2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  weekdayInitial(date.weekday),
                  style: text.overline.copyWith(
                    color: selected ? colors.accentInk : colors.ink3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${date.day}',
                  style: text.label.copyWith(
                    color: selected ? colors.accentInk : colors.ink,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: NourishlySpace.s1),
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? colors.accentInk : dotColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One day's meal slots, in slot order, each either holding its foods or
/// offering the two ways to fill it.
class _DayAgenda extends ConsumerWidget {
  const _DayAgenda({required this.date, required this.entries});

  final DateTime date;
  final List<PlannedFood> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slots = ref.watch(mealSlotsProvider).value ?? const <MealSlot>[];
    final forDay = [
      for (final e in entries)
        if (_isSameDay(e.entry.logDate, date)) e,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final slot in slots) ...[
          _SlotCard(
            date: date,
            slot: slot,
            items: [
              for (final e in forDay)
                if (e.mealSlotId == slot.id && !e.isSkipped) e,
            ],
          ),
          const SizedBox(height: NourishlySpace.s3),
        ],
      ],
    );
  }
}

class _SlotCard extends ConsumerWidget {
  const _SlotCard({
    required this.date,
    required this.slot,
    required this.items,
  });

  final DateTime date;
  final MealSlot slot;
  final List<PlannedFood> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    final energy = items.fold<double?>(null, (sum, item) {
      final kcal = item.energyKcal;
      return kcal == null ? sum : (sum ?? 0) + kcal;
    });

    return NourishlyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  slot.displayName,
                  style: text.overline.copyWith(color: colors.ink3),
                ),
              ),
              if (energy != null)
                Text(
                  '${formatThousands(energy.round())} kcal',
                  style: text.caption.copyWith(
                    color: colors.ink3,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: NourishlySpace.s3),
              child: Wrap(
                spacing: NourishlySpace.s2,
                runSpacing: NourishlySpace.s2,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.bookmark_outline_rounded, size: 18),
                    label: const Text('From a template'),
                    onPressed: () => _fillFromTemplate(context, ref),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.search_rounded, size: 18),
                    label: const Text('Search food'),
                    onPressed: () => _planFood(context),
                  ),
                ],
              ),
            )
          else ...[
            for (final item in items) _PlannedRow(item: item),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add to this meal'),
                onPressed: () => _planFood(context),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _planFood(BuildContext context) {
    // The ordinary logging flow, told where the entry belongs: same
    // screen, same search, different destination.
    context.push('/log?meal=${slot.id}&plan=${_isoDate(date)}');
  }

  Future<void> _fillFromTemplate(BuildContext context, WidgetRef ref) async {
    final templates = await ref.read(mealTemplatesProvider.future);
    if (!context.mounted) return;
    if (templates.isEmpty) {
      showNourishlySnack(
        context,
        'No templates yet — save a meal as one from the day log',
      );
      return;
    }
    final chosen = await showModalBottomSheet<SavedMealTemplate>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final template in templates)
              ListTile(
                title: Text(template.name),
                subtitle: Text(
                  template.items.map((i) => i.foodName).join(', '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => Navigator.of(context).pop(template),
              ),
          ],
        ),
      ),
    );
    if (chosen == null || !context.mounted) return;

    final ownerId = await ref.read(defaultOwnerProvider.future);
    final planned = await ref
        .read(mealTemplateDaoProvider)
        .applyTemplate(
          templateId: chosen.id,
          ownerId: ownerId,
          logDate: date,
          mealSlotId: slot.id,
          status: logStatusPlanned,
        );
    if (!context.mounted) return;
    showNourishlySnack(
      context,
      planned == 0
          ? 'Nothing planned — that template has no portions recorded'
          : 'Planned $planned ${planned == 1 ? 'item' : 'items'} '
                'for ${slot.displayName.toLowerCase()}',
    );
  }
}

class _PlannedRow extends ConsumerWidget {
  const _PlannedRow({required this.item});

  final PlannedFood item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    final serving = item.servingLabel;
    final quantity = item.entry.quantity;

    return Padding(
      padding: const EdgeInsets.only(top: NourishlySpace.s3),
      child: Row(
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
                      : '${_quantityLabel(quantity)} × $serving',
                  style: text.caption.copyWith(color: colors.ink3),
                ),
              ],
            ),
          ),
          const SizedBox(width: NourishlySpace.s2),
          // Plain chips for the same reason as on the dashboard card:
          // "planned" and "eaten" are states of an entry, not statuses of
          // a nutrient, and StatusChip's palette belongs to the latter.
          NourishlyChip(label: item.isPlanned ? 'Planned' : 'Eaten'),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            tooltip: 'Remove from the plan',
            onPressed: item.isPlanned ? () => _remove(context, ref) : null,
          ),
        ],
      ),
    );
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    await ref.read(foodLoggingDaoProvider).deleteEntry(item.entry.id);
    if (!context.mounted) return;
    showNourishlySnack(
      context,
      'Removed ${item.foodName} from the plan',
      actionLabel: 'Undo',
      onAction: () => ref.read(foodLoggingDaoProvider).restore(item.entry.id),
    );
  }
}

String _quantityLabel(double quantity) => quantity == quantity.roundToDouble()
    ? quantity.round().toString()
    : quantity.toStringAsFixed(1);

String _isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
