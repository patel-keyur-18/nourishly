import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nourishly_data/nourishly_data.dart';
import 'package:nourishly_ui/nourishly_ui.dart';

import '../../../food_catalog/data/food_catalog_providers.dart';
import '../../../../app/providers.dart';

/// Serving picker, quantity stepper, and meal slot (§27.5) for one food,
/// reached via `/log/food/:foodId`. Saves a real [FoodLogEntry] — the
/// write path §14.9 calls the highest-value thing to get right, since
/// everything downstream (search, catalog, DAOs) exists to feed this one
/// action.
class FoodPortionScreen extends ConsumerStatefulWidget {
  const FoodPortionScreen({super.key, required this.foodId});

  final String foodId;

  @override
  ConsumerState<FoodPortionScreen> createState() => _FoodPortionScreenState();
}

class _FoodPortionScreenState extends ConsumerState<FoodPortionScreen> {
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
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    final mealSlotsAsync = ref.watch(mealSlotsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Add to log')),
      body: FutureBuilder(
        future: _load(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final (food, servings) = snapshot.data!;
          _servingId ??= servings.firstOrNull?.id;

          return ListView(
            padding: const EdgeInsets.all(NourishlySpace.s4),
            children: [
              Text(food.canonicalName, style: text.title),
              const SizedBox(height: NourishlySpace.s5),

              Text('Serving', style: text.label.copyWith(color: colors.ink3)),
              const SizedBox(height: NourishlySpace.s2),
              Wrap(
                spacing: NourishlySpace.s2,
                children: [
                  for (final serving in servings)
                    ChoiceChip(
                      label: Text(
                        '${serving.label} (${serving.grams.toStringAsFixed(0)} g)',
                      ),
                      selected: _servingId == serving.id,
                      onSelected: (_) =>
                          setState(() => _servingId = serving.id),
                    ),
                ],
              ),
              const SizedBox(height: NourishlySpace.s5),

              Text('Quantity', style: text.label.copyWith(color: colors.ink3)),
              const SizedBox(height: NourishlySpace.s2),
              Row(
                children: [
                  IconButton(
                    onPressed: _quantity > 0.5
                        ? () => setState(() => _quantity -= 0.5)
                        : null,
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                  ),
                  Text(
                    _quantity.toStringAsFixed(_quantity % 1 == 0 ? 0 : 1),
                    style: text.numeral,
                  ),
                  IconButton(
                    onPressed: () => setState(() => _quantity += 0.5),
                    icon: const Icon(Icons.add_circle_outline_rounded),
                  ),
                ],
              ),
              const SizedBox(height: NourishlySpace.s5),

              Text('Meal', style: text.label.copyWith(color: colors.ink3)),
              const SizedBox(height: NourishlySpace.s2),
              mealSlotsAsync.when(
                data: (slots) {
                  _mealSlotId ??= slots.firstOrNull?.id;
                  return Wrap(
                    spacing: NourishlySpace.s2,
                    children: [
                      for (final slot in slots)
                        ChoiceChip(
                          label: Text(slot.displayName),
                          selected: _mealSlotId == slot.id,
                          onSelected: (_) =>
                              setState(() => _mealSlotId = slot.id),
                        ),
                    ],
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (error, stackTrace) =>
                    Text('Could not load meal slots: $error'),
              ),
              const SizedBox(height: NourishlySpace.s7),

              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving…' : 'Save'),
              ),
            ],
          );
        },
      ),
    );
  }
}
