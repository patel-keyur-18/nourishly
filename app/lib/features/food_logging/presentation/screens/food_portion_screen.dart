import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nourishly_data/nourishly_data.dart';
import 'package:nourishly_ui/nourishly_ui.dart';

import '../../../../app/providers.dart';
import '../../../../shared/formatting.dart';
import '../../../food_catalog/data/food_catalog_providers.dart';
import '../../../profile/data/profile_providers.dart';

/// Serving picker, quantity stepper, and meal slot (prototype screen 6,
/// option A — serving chips + stepper) for one food, reached via
/// `/log/food/:foodId`. Saves a real `FoodLogEntry`, the write path §14.9
/// calls the highest-value thing to get right.
///
/// The same screen edits an existing entry when [entryId] is given
/// (FR-M-05) — the day log's edit action opens this rather than a bare
/// grams prompt, so changing what you logged looks exactly like logging
/// it did. [FoodLoggingDao.updateEntry] rescales the frozen nutrient
/// snapshot by the grams ratio, which is exact regardless of which
/// serving produced the grams, so every downstream screen (all of them
/// read through drift's reactive streams on the same tables) picks up
/// the change with no extra invalidation.
class FoodPortionScreen extends ConsumerStatefulWidget {
  const FoodPortionScreen({
    super.key,
    required this.foodId,
    this.initialMealSlotId,
    this.entryId,
    this.planDate,
  });

  final String foodId;

  /// Preselected when the flow started from a meal row on the dashboard,
  /// so "Add breakfast" does not ask which meal at the end of it.
  final String? initialMealSlotId;

  /// Present when editing an already-logged entry rather than adding a
  /// new one.
  final String? entryId;

  /// Set when the flow started from the week plan: the entry is written
  /// against this date and marked planned, so it is an intention rather
  /// than something eaten. The screen is otherwise identical — one flow,
  /// two destinations.
  final DateTime? planDate;

  @override
  ConsumerState<FoodPortionScreen> createState() => _FoodPortionScreenState();
}

class _FoodPortionScreenState extends ConsumerState<FoodPortionScreen>
    with RestorationMixin {
  late final Future<(FoodItem, List<ServingSize>, List<FoodNutrientValue>)>
  _food = _load();
  final RestorableDouble _quantity = RestorableDouble(1);
  final RestorableStringN _servingId = RestorableStringN(null);
  final RestorableStringN _mealSlotId = RestorableStringN(null);

  /// When the food was eaten, as minutes since midnight on the log date.
  /// Null until the first build fills it in with the current time.
  final RestorableIntN _minutes = RestorableIntN(null);
  bool _saving = false;

  bool get _editing => widget.entryId != null;
  bool get _planning => widget.planDate != null;

  @override
  String? get restorationId => 'food_portion_${widget.foodId}';

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_quantity, 'quantity');
    registerForRestoration(_servingId, 'servingId');
    registerForRestoration(_mealSlotId, 'mealSlotId');
    registerForRestoration(_minutes, 'minutes');
    // `initialRestore` is true on every fresh State object, restored or
    // not (Flutter tracks it per-instance, not per-bucket) — it cannot
    // tell "brand new" apart from "recreated with real prior data" here.
    // `??=` is what actually does the right thing in both cases: a
    // restored non-null selection is left alone, and only a genuinely
    // empty one falls back to the widget's preselected slot.
    _mealSlotId.value ??= widget.initialMealSlotId;
  }

  @override
  void dispose() {
    _quantity.dispose();
    _servingId.dispose();
    _mealSlotId.dispose();
    _minutes.dispose();
    super.dispose();
  }

  Future<(FoodItem, List<ServingSize>, List<FoodNutrientValue>)> _load() async {
    final db = ref.read(nourishlyDatabaseProvider);
    final food = await (db.select(
      db.foodItems,
    )..where((f) => f.id.equals(widget.foodId))).getSingle();
    final servings =
        await (db.select(db.servingSizes)
              ..where((s) => s.foodId.equals(widget.foodId))
              ..orderBy([(s) => OrderingTerm.asc(s.sortOrder)]))
            .get();
    final nutrientValues = await (db.select(
      db.foodNutrientValues,
    )..where((v) => v.foodId.equals(widget.foodId))).get();
    final entryId = widget.entryId;
    if (entryId != null) {
      final entry = await (db.select(
        db.foodLogEntries,
      )..where((e) => e.id.equals(entryId))).getSingle();
      _quantity.value = entry.quantity;
      _servingId.value = entry.servingSizeId;
      _mealSlotId.value = entry.mealSlotId;
      _minutes.value = entry.loggedAt.hour * 60 + entry.loggedAt.minute;
    }
    return (food, servings, nutrientValues);
  }

  /// The log date this entry belongs to, and the moment within it the user
  /// has picked.
  DateTime get _logDate => widget.planDate ?? ref.read(todayProvider);

  DateTime? get _loggedAt {
    // A planned entry's `loggedAt` means "when the plan was made" and is
    // rewritten on confirmation, so there is nothing for the user to set.
    if (_planning) return null;
    final minutes = _minutes.value;
    if (minutes == null) return null;
    return momentOnLogDate(
      _logDate,
      minutes,
      rolloverMinutes: ref.read(dayRolloverMinutesProvider),
    );
  }

  Future<void> _pickTime() async {
    final minutes = _minutes.value ?? 0;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
      helpText: 'When did you eat this?',
    );
    if (picked == null) return;
    setState(() => _minutes.value = picked.hour * 60 + picked.minute);
  }

  Future<void> _save() async {
    if (_servingId.value == null || _mealSlotId.value == null || _saving) {
      return;
    }
    setState(() => _saving = true);

    final dao = ref.read(foodLoggingDaoProvider);
    final entryId = widget.entryId;
    if (entryId != null) {
      await dao.updateEntry(
        entryId: entryId,
        quantity: _quantity.value,
        servingId: _servingId.value,
        mealSlotId: _mealSlotId.value,
        loggedAt: _loggedAt,
      );
    } else {
      final ownerId = await ref.read(defaultOwnerProvider.future);
      await dao.logFood(
        ownerId: ownerId,
        foodId: widget.foodId,
        servingId: _servingId.value!,
        quantity: _quantity.value,
        mealSlotId: _mealSlotId.value!,
        logDate: _logDate,
        loggedAt: _loggedAt,
        status: _planning ? logStatusPlanned : logStatusLogged,
        source: _planning ? 'plan' : 'manual',
      );
    }

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (_editing) {
      // Reached directly from wherever the entry was listed (the day
      // log), not through the `/log` search flow — one pop returns to
      // that screen so the edit is immediately visible, rather than
      // unwinding past it to the dashboard.
      context.pop();
    } else if (_planning) {
      // Exactly the two routes this flow pushed — the portion screen and
      // the `/log` modal — so the user lands back on the week plan they
      // came from. Unwinding to the shell here would answer "add a meal
      // to Thursday" by closing the plan.
      for (var i = 0; i < 2 && context.canPop(); i++) {
        context.pop();
      }
    } else {
      // Pop back through the portion screen and the /log modal to
      // wherever the user was (§28.4: logging is a task, not a place).
      // The loop stops at the shell, which is the one route with nothing
      // under it — which is also why the flow has to be *pushed* over
      // the shell rather than replacing it.
      while (context.canPop()) {
        context.pop();
      }
    }
    showNourishlySnackOn(messenger, switch ((_editing, _planning)) {
      (true, _) => 'Changes saved.',
      (false, true) => 'Added to your plan.',
      (false, false) => 'Added to your log.',
    });
  }

  /// A catalog recipe can be forked into one of your own; your own
  /// recipes and plain ingredients cannot.
  ///
  /// `ownerId == null` is what makes a food the bundled catalog's rather
  /// than this profile's (§22.5), and `kind == 'recipe'` is what gives it
  /// the ingredient list there is any point editing.
  static bool _canFork(FoodItem food) =>
      food.kind == 'recipe' && food.ownerId == null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit entry' : 'Add to log')),
      body: FutureBuilder(
        future: _food,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Could not load: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final (food, servings, nutrientValues) = snapshot.data!;
          _servingId.value ??= servings.firstOrNull?.id;
          // Logging as you eat is the common case, so "now" is the
          // default and the picker is there for the evening catch-up.
          if (_minutes.value == null) {
            final now = ref.read(clockProvider).now();
            _minutes.value = now.hour * 60 + now.minute;
          }
          final serving = servings
              .where((s) => s.id == _servingId.value)
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
                    _NutrientPreview(
                      values: nutrientValues,
                      grams: (serving?.grams ?? 0) * _quantity.value,
                    ),
                    const NourishlySectionHeader(label: 'Serving'),
                    _ServingChips(
                      servings: servings,
                      selectedId: _servingId.value,
                      onSelected: (id) => setState(() => _servingId.value = id),
                    ),
                    const NourishlySectionHeader(label: 'Quantity'),
                    _QuantityStepper(
                      quantity: _quantity.value,
                      unitLabel: serving?.label ?? 'serving',
                      grams: (serving?.grams ?? 0) * _quantity.value,
                      onChanged: (q) => setState(() => _quantity.value = q),
                    ),
                    const NourishlySectionHeader(label: 'Meal'),
                    _MealChips(
                      selectedId: _mealSlotId.value,
                      onSelected: (id) =>
                          setState(() => _mealSlotId.value = id),
                      // Through setState, not a bare `??=`: the save bar
                      // reads `_mealSlotId` to decide whether it is
                      // enabled, and the chips fall back to the first
                      // slot from a post-frame callback. Assigning
                      // silently left the button greyed out until the
                      // user tapped a meal — on the one route that does
                      // not preselect one, the nav bar's centre action.
                      onDefault: (id) {
                        if (_mealSlotId.value != null || !mounted) return;
                        setState(() => _mealSlotId.value = id);
                      },
                    ),
                    if (!_planning) ...[
                      const NourishlySectionHeader(label: 'Time'),
                      _TimeRow(
                        minutes: _minutes.value,
                        onPressed: _pickTime,
                      ),
                    ],
                    if (_canFork(food)) ...[
                      const SizedBox(height: NourishlySpace.s5),
                      _ForkPrompt(food: food),
                    ],
                  ],
                ),
              ),
              _SaveBar(
                enabled:
                    !_saving &&
                    _servingId.value != null &&
                    _mealSlotId.value != null,
                saving: _saving,
                editing: _editing,
                planning: _planning,
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
      ],
    );
  }
}

/// The four core macros plus energy, computed for the currently selected
/// serving × quantity (AP-4: a nutrient with no [FoodNutrientValue] row
/// for this food renders as "—", never 0 — mirrors
/// `daily_report_screen.dart`'s `_NutrientRow`).
class _NutrientPreview extends ConsumerWidget {
  const _NutrientPreview({required this.values, required this.grams});

  final List<FoodNutrientValue> values;
  final double grams;

  static const _tracked = ['energy', 'protein', 'carbs', 'fat', 'fibre'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    final labelsAsync = ref.watch(nutrientLabelsProvider);
    final labels = labelsAsync.value ?? const <String, Nutrient>{};
    final byNutrient = {for (final v in values) v.nutrientId: v};

    return NourishlyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final id in _tracked)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    labels[id]?.displayName ?? id,
                    style: text.caption.copyWith(color: colors.ink3),
                  ),
                  Text(
                    _amount(byNutrient[id], labels[id], grams),
                    style: text.body.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _amount(
    FoodNutrientValue? value,
    Nutrient? nutrient,
    double grams,
  ) {
    if (value == null) return '—';
    final amount = value.amountPer100g * grams / 100;
    final unit = nutrient?.canonicalUnit ?? '';
    final precision = nutrient?.displayPrecision ?? 0;
    return '${amount.toStringAsFixed(precision)} $unit'.trim();
  }
}

/// The offer to record how this kitchen actually cooks the dish.
///
/// A catalog row is a reasonable estimate of how a dish is generally made
/// (catalog spec §0.3). This household cooks most things in about half the
/// oil, and that difference is real — a katori of sabzi with 4 g of oil
/// instead of 8 is some 36 kcal lighter, three or four times a week.
///
/// Forking is the honest way to record it: the copy is recomputed from its
/// own ingredients by the same arithmetic as the original, so nothing is
/// asserted that was not summed. Editing the catalog row in place would be
/// the alternative, and it would quietly restate how everyone cooks the
/// dish on the strength of one kitchen.
class _ForkPrompt extends StatelessWidget {
  const _ForkPrompt({required this.food});

  final FoodItem food;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;

    return NourishlyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cook it differently?',
            style: text.body.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: NourishlySpace.s2),
          Text(
            'Make your own version of this recipe — less oil, or whatever '
            'else your kitchen does — and it becomes a food you can log '
            'like any other. Meals you have already logged do not change.',
            style: text.caption.copyWith(color: colors.ink3, height: 1.5),
          ),
          const SizedBox(height: NourishlySpace.s3),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => context.push('/recipes/new?from=${food.id}'),
              icon: const Icon(Icons.edit_note_rounded, size: 18),
              label: const Text('Make this our version'),
            ),
          ),
        ],
      ),
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

/// When the food was eaten, which is not always when it was typed in.
///
/// A row rather than a set of chips: the answer is usually the default and
/// wants confirming at a glance, and the rare correction is worth a
/// picker. Logging a whole day at bedtime otherwise stamps every meal with
/// the same timestamp, which makes the day log's timeline meaningless and
/// hides which meal actually ran late.
class _TimeRow extends StatelessWidget {
  const _TimeRow({required this.minutes, required this.onPressed});

  final int? minutes;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    return NourishlyCard(
      padding: EdgeInsets.zero,
      child: NourishlyListRow(
        title: 'Eaten at',
        subtitle: 'Change it if you are logging later',
        value: minutes == null ? '—' : formatMinutesOfDay(minutes!),
        leading: Icon(
          Icons.schedule_rounded,
          size: 20,
          color: colors.accent,
        ),
        onTap: onPressed,
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
    required this.editing,
    required this.planning,
    required this.onPressed,
  });

  final bool enabled;
  final bool saving;
  final bool editing;
  final bool planning;
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
            child: Text(
              saving
                  ? 'Saving…'
                  : switch ((editing, planning)) {
                      (true, _) => 'Save changes',
                      (false, true) => 'Add to plan',
                      (false, false) => 'Add to log',
                    },
            ),
          ),
        ),
      ),
    );
  }
}
