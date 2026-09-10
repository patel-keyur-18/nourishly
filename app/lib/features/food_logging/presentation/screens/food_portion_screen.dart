import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nourishly_data/nourishly_data.dart';
import 'package:nourishly_ui/nourishly_ui.dart';

import '../../../../app/providers.dart';
import '../../../food_catalog/data/food_catalog_providers.dart';

/// Serving picker, quantity stepper, and meal slot (prototype screen 6,
/// option A — serving chips + stepper) for one food, reached via
/// `/log/food/:foodId`. Saves a real `FoodLogEntry`, the write path §14.9
/// calls the highest-value thing to get right.
class FoodPortionScreen extends ConsumerStatefulWidget {
  const FoodPortionScreen({super.key, required this.foodId});

  final String foodId;

  @override
  ConsumerState<FoodPortionScreen> createState() => _FoodPortionScreenState();
}

class _FoodPortionScreenState extends ConsumerState<FoodPortionScreen> {
  late final Future<(FoodItem, List<ServingSize>)> _food = _load();
  double _quantity = 1;
  String? _servingId;
  String? _mealSlotId;
  bool _saving = false;

  Future<(FoodItem, List<ServingSize>)> _load() async {
    final db = ref.read(nourishlyDatabaseProvider);
    final food = await (db.select(
      db.foodItems,
    )..where((f) => f.id.equals(widget.foodId))).getSingle();
    final servings =
        await (db.select(db.servingSizes)
              ..where((s) => s.foodId.equals(widget.foodId))
              ..orderBy([(s) => OrderingTerm.asc(s.sortOrder)]))
            .get();
    return (food, servings);
  }

  Future<void> _save() async {
    if (_servingId == null || _mealSlotId == null || _saving) return;
    setState(() => _saving = true);

    final ownerId = await ref.read(defaultOwnerProvider.future);
    await ref
        .read(foodLoggingDaoProvider)
        .logFood(
          ownerId: ownerId,
          foodId: widget.foodId,
          servingId: _servingId!,
          quantity: _quantity,
          mealSlotId: _mealSlotId!,
          logDate: ref.read(todayProvider),
        );

    if (!mounted) return;
    // Pop back through the portion screen and the /log modal to wherever
    // the user was (§28.4: logging is a task, not a place).
    while (context.canPop()) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add to log')),
      body: FutureBuilder(
        future: _food,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Could not load: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final (food, servings) = snapshot.data!;
          _servingId ??= servings.firstOrNull?.id;
          final serving = servings
              .where((s) => s.id == _servingId)
              .firstOrNull;

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    NourishlySpace.s4,
                    NourishlySpace.s4,
                    NourishlySpace.s4,
                    NourishlySpace.s6,
                  ),
                  children: [
                    _FoodHeader(food: food),
                    const NourishlySectionHeader(label: 'Serving'),
                    _ServingChips(
                      servings: servings,
                      selectedId: _servingId,
                      onSelected: (id) => setState(() => _servingId = id),
                    ),
                    const NourishlySectionHeader(label: 'Quantity'),
                    _QuantityStepper(
                      quantity: _quantity,
                      unitLabel: serving?.label ?? 'serving',
                      grams: (serving?.grams ?? 0) * _quantity,
                      onChanged: (q) => setState(() => _quantity = q),
                    ),
                    const NourishlySectionHeader(label: 'Meal'),
                    _MealChips(
                      selectedId: _mealSlotId,
                      onSelected: (id) => setState(() => _mealSlotId = id),
                      onDefault: (id) => _mealSlotId ??= id,
                    ),
                  ],
                ),
              ),
              _SaveBar(
                enabled: !_saving && _servingId != null && _mealSlotId != null,
                saving: _saving,
                onPressed: _save,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FoodHeader extends StatelessWidget {
  const _FoodHeader({required this.food});

  final FoodItem food;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(food.canonicalName, style: text.title),
        const SizedBox(height: NourishlySpace.s2),
        Row(
          children: [
            StatusChip(
              label: switch (food.qualityTier) {
                'verified' => 'Lab-measured',
                'derived' => 'Calculated from ingredients',
                'label' => 'From the label',
                _ => food.qualityTier,
              },
              status: food.qualityTier == 'verified'
                  ? NourishlyStatus.ok
                  : NourishlyStatus.unknown,
            ),
          ],
        ),
        const SizedBox(height: NourishlySpace.s2),
        Text(
          'Per-serving nutrients arrive with Phase 3 aggregation — this '
          'screen records what you ate, exactly as logged.',
          style: text.caption.copyWith(color: colors.ink3),
        ),
      ],
    );
  }
}

class _ServingChips extends StatelessWidget {
  const _ServingChips({
    required this.servings,
    required this.selectedId,
    required this.onSelected,
  });

  final List<ServingSize> servings;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final text = context.nourishlyText;
    if (servings.isEmpty) {
      return Text('No servings recorded for this food.', style: text.caption);
    }
    return Wrap(
      spacing: NourishlySpace.s2,
      runSpacing: NourishlySpace.s2,
      children: [
        for (final serving in servings)
          ChoiceChip(
            label: Text(
              '${serving.label} · ${serving.grams.toStringAsFixed(0)} g',
            ),
            selected: selectedId == serving.id,
            onSelected: (_) => onSelected(serving.id),
          ),
      ],
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.quantity,
    required this.unitLabel,
    required this.grams,
    required this.onChanged,
  });

  final double quantity;
  final String unitLabel;
  final double grams;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    return NourishlyCard(
      child: Row(
        children: [
          IconButton(
            onPressed: quantity > 0.5 ? () => onChanged(quantity - 0.5) : null,
            icon: const Icon(Icons.remove_circle_outline_rounded),
            iconSize: 30,
            color: colors.accent,
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  quantity.toStringAsFixed(quantity % 1 == 0 ? 0 : 1),
                  style: text.display.copyWith(height: 1),
                ),
                const SizedBox(height: NourishlySpace.s1),
                Text(
                  '× $unitLabel · ${grams.toStringAsFixed(0)} g',
                  style: text.caption.copyWith(color: colors.ink3),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => onChanged(quantity + 0.5),
            icon: const Icon(Icons.add_circle_outline_rounded),
            iconSize: 30,
            color: colors.accent,
          ),
        ],
      ),
    );
  }
}

class _MealChips extends ConsumerWidget {
  const _MealChips({
    required this.selectedId,
    required this.onSelected,
    required this.onDefault,
  });

  final String? selectedId;
  final ValueChanged<String> onSelected;
  final ValueChanged<String> onDefault;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = context.nourishlyText;
    return ref
        .watch(mealSlotsProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) =>
              Text('Could not load meal slots: $error', style: text.caption),
          data: (slots) {
            final first = slots.firstOrNull;
            if (first != null && selectedId == null) {
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => onDefault(first.id),
              );
            }
            return Wrap(
              spacing: NourishlySpace.s2,
              runSpacing: NourishlySpace.s2,
              children: [
                for (final slot in slots)
                  ChoiceChip(
                    label: Text(slot.displayName),
                    selected: selectedId == slot.id,
                    onSelected: (_) => onSelected(slot.id),
                  ),
              ],
            );
          },
        );
  }
}

class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.enabled,
    required this.saving,
    required this.onPressed,
  });

  final bool enabled;
  final bool saving;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.line, width: NourishlyStroke.hairline),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(NourishlySpace.s4),
          child: FilledButton(
            onPressed: enabled ? onPressed : null,
            child: Text(saving ? 'Saving…' : 'Add to log'),
          ),
        ),
      ),
    );
  }
}
