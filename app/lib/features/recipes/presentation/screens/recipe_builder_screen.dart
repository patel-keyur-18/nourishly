import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nourishly_data/nourishly_data.dart';
import 'package:nourishly_ui/nourishly_ui.dart';
import 'package:nutrition_core/nutrition_core.dart';

import '../../../../app/providers.dart';
import '../../../../shared/formatting.dart';
import '../../../food_catalog/data/food_catalog_providers.dart';
import '../../../profile/data/profile_providers.dart';
import '../../data/recipe_providers.dart';

/// Build or edit a recipe (§19.10).
///
/// The screen's whole job is getting three things out of a cook: what went
/// in, what came out of the pot, and what one serving of it is. The
/// arithmetic — sum the ingredients, divide by the cooked weight — lives
/// in `nutrition_core`, and the preview at the bottom recomputes as the
/// numbers change so nobody has to save to find out what they made.
///
/// No prototype screen exists for this; see [RecipesScreen] for why.
class RecipeBuilderScreen extends ConsumerStatefulWidget {
  const RecipeBuilderScreen({super.key, this.foodId, this.forkFromId});

  /// Null to build a new one.
  final String? foodId;

  /// Start a **new** recipe from an existing one's ingredients — "make
  /// this our version" on a catalog dish.
  ///
  /// Deliberately separate from [foodId]: the two look alike and mean
  /// opposite things. Editing changes the recipe you opened; forking
  /// leaves it untouched and creates your own, so the catalog's estimate
  /// of how a dish is generally made stays put while your kitchen's
  /// version stands beside it.
  final String? forkFromId;

  @override
  ConsumerState<RecipeBuilderScreen> createState() =>
      _RecipeBuilderScreenState();
}

class _RecipeBuilderScreenState extends ConsumerState<RecipeBuilderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _servingLabel = TextEditingController(text: '1 katori');
  final _servingGrams = TextEditingController();
  final _cookedGrams = TextEditingController();

  final _ingredients = <RecipeIngredient>[];
  CookingMethod _method = CookingMethod.none;
  bool _saving = false;
  bool _loaded = false;

  /// The live preview.
  ///
  /// Held here rather than read from a provider family keyed on the
  /// ingredient list: the list is mutated in place, so a family would
  /// treat a changed recipe as the same key and hand back the previous
  /// answer. Recomputing explicitly on every change is both correct and
  /// simpler.
  RecipeNutrition? _preview;
  int _previewGeneration = 0;

  Future<void> _recompute() async {
    final generation = ++_previewGeneration;
    if (_ingredients.isEmpty) {
      setState(() => _preview = null);
      return;
    }
    final nutrition = await ref
        .read(recipeDaoProvider)
        .computeFor(
          ingredients: List.of(_ingredients),
          cookedGrams: _number(_cookedGrams),
          method: _method,
        );
    // A slower recompute must not overwrite a newer one.
    if (!mounted || generation != _previewGeneration) return;
    setState(() => _preview = nutrition);
  }

  @override
  void dispose() {
    for (final c in [_name, _servingLabel, _servingGrams, _cookedGrams]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _number(TextEditingController c) {
    final raw = c.text.trim();
    return raw.isEmpty ? null : double.tryParse(raw);
  }

  /// Fills the form from a saved recipe, once.
  ///
  /// [asFork] starts a new recipe from this one's ingredients rather than
  /// editing it. Only the name differs — everything else is copied exactly,
  /// because the point of a fork is to change one or two numbers, not to
  /// start again.
  void _loadOnce(SavedRecipe recipe, {bool asFork = false}) {
    if (_loaded) return;
    _loaded = true;
    _name.text = asFork ? '${recipe.name} (our version)' : recipe.name;
    _servingLabel.text = recipe.servingLabel;
    _servingGrams.text = recipe.servingGrams.toStringAsFixed(0);
    _cookedGrams.text = recipe.cookedGrams.toStringAsFixed(0);
    _ingredients
      ..clear()
      ..addAll(recipe.ingredients);
    WidgetsBinding.instance.addPostFrameCallback((_) => _recompute());
  }

  /// Offers a halved amount for each cooking fat, one line at a time.
  ///
  /// Every suggestion is shown against the original and accepted or
  /// skipped individually, which is not politeness — it is the only
  /// correct behaviour available. Catalog spec §0.6 separates pan oil from
  /// the oil a fried food absorbs, and that distinction does not survive
  /// into a stored recipe: both are the same ingredient row by then. A
  /// puri fried in half the oil absorbs about the same, so halving
  /// everything would claim a reduction that never happened. Asking is the
  /// honest substitute for knowing (see `cooking_fat.dart`).
  Future<void> _cookLighter() async {
    final suggestions = fatSuggestions(_ingredients);
    if (suggestions.isEmpty) {
      showNourishlySnack(context, 'No cooking fat in this recipe to reduce.');
      return;
    }

    final accepted = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _LighterFatSheet(suggestions: suggestions),
    );
    if (accepted == null || accepted.isEmpty) return;

    setState(() {
      for (final suggestion in suggestions) {
        if (!accepted.contains(suggestion.index)) continue;
        final original = _ingredients[suggestion.index];
        _ingredients[suggestion.index] = RecipeIngredient(
          foodId: original.foodId,
          name: original.name,
          grams: suggestion.suggestedGrams,
        );
      }
    });
    await _recompute();
  }

  Future<void> _addIngredient() async {
    final added = await showModalBottomSheet<RecipeIngredient>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => const _IngredientPicker(),
    );
    if (added == null) return;
    setState(() => _ingredients.add(added));
    await _recompute();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false) || _saving) return;
    if (_ingredients.isEmpty) {
      showNourishlySnack(
        context,
        'Add at least one ingredient — that is the recipe.',
      );
      return;
    }
    setState(() => _saving = true);

    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    // Captured before the write: an error message is styled from the theme,
    // and reaching for a BuildContext after an await is how that goes wrong.
    final colors = context.nourishlyColors;
    try {
      final ownerId = await ref.read(defaultOwnerProvider.future);
      await ref
          .read(recipeDaoProvider)
          .saveRecipe(
            ownerId: ownerId,
            foodId: widget.foodId,
            name: _name.text.trim(),
            ingredients: _ingredients,
            servingGrams: _number(_servingGrams)!,
            servingLabel: _servingLabel.text.trim().isEmpty
                ? '1 serving'
                : _servingLabel.text.trim(),
            cookedGrams: _number(_cookedGrams),
            method: _method,
          );
      ref.read(recipeRevisionProvider.notifier).bump();
      if (!mounted) return;
      router.pop();
      showNourishlySnackOn(messenger, 'Recipe saved.');
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      showNourishlySnackOn(
        messenger,
        'Could not save that recipe: $error',
        isError: true,
        colors: colors,
      );
    }
  }

  Future<void> _delete() async {
    final confirmed = await showNourishlyConfirm(
      context: context,
      title: 'Delete this recipe?',
      message:
          'Meals you have already logged from it are not affected — they '
          'keep their own numbers.',
      confirmLabel: 'Delete',
      icon: Icons.delete_outline_rounded,
      danger: true,
    );
    if (!confirmed || !mounted) return;

    final router = GoRouter.of(context);
    await ref.read(recipeDaoProvider).deleteRecipe(widget.foodId!);
    ref.read(recipeRevisionProvider.notifier).bump();
    if (!mounted) return;
    router.pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    final isEditing = widget.foodId != null;
    final sourceId = widget.foodId ?? widget.forkFromId;

    if (sourceId != null) {
      final existing = ref.watch(recipeProvider(sourceId)).value;
      if (existing == null && !_loaded) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (existing != null) _loadOnce(existing, asFork: !isEditing);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing
              ? 'Edit recipe'
              : widget.forkFromId != null
              ? 'Your version'
              : 'New recipe',
        ),
        actions: [
          if (isEditing)
            IconButton(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'Delete',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
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
                  _Field(
                    controller: _name,
                    label: 'Name',
                    hint: "Mummy's dal",
                    textCapitalization: TextCapitalization.sentences,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Give it a name you will recognise later.'
                        : null,
                  ),
                  NourishlySectionHeader(
                    label: 'What went in',
                    actionLabel: 'Add',
                    onActionPressed: _addIngredient,
                  ),
                  if (_ingredients.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _cookLighter,
                        icon: const Icon(Icons.water_drop_outlined, size: 18),
                        label: const Text('Use less oil'),
                      ),
                    ),
                  _IngredientList(
                    ingredients: _ingredients,
                    onRemove: (index) {
                      setState(() => _ingredients.removeAt(index));
                      _recompute();
                    },
                    onChangeGrams: (index, grams) {
                      setState(
                        () => _ingredients[index] = RecipeIngredient(
                          foodId: _ingredients[index].foodId,
                          name: _ingredients[index].name,
                          grams: grams,
                        ),
                      );
                      _recompute();
                    },
                  ),
                  const NourishlySectionHeader(label: 'What came out'),
                  Text(
                    'Weigh the finished dish if you can — a dal that takes '
                    'on water is not as rich per spoon as its ingredients '
                    'suggest, and this is the number that gets that right.',
                    style: text.caption.copyWith(
                      color: colors.ink3,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: NourishlySpace.s3),
                  _Field(
                    controller: _cookedGrams,
                    label: 'Cooked weight (g)',
                    hint: 'Optional',
                    numeric: true,
                    onChanged: (_) {
                      setState(() {});
                      _recompute();
                    },
                  ),
                  const SizedBox(height: NourishlySpace.s3),
                  _MethodPicker(
                    method: _method,
                    enabled: _number(_cookedGrams) == null,
                    onChanged: (method) {
                      setState(() => _method = method);
                      _recompute();
                    },
                  ),
                  const NourishlySectionHeader(label: 'One serving'),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: _Field(
                          controller: _servingLabel,
                          label: 'Called',
                          hint: '1 katori',
                        ),
                      ),
                      const SizedBox(width: NourishlySpace.s3),
                      Expanded(
                        flex: 2,
                        child: _Field(
                          controller: _servingGrams,
                          label: 'Weighs (g)',
                          hint: '150',
                          numeric: true,
                          onChanged: (_) => setState(() {}),
                          validator: (v) {
                            final grams = double.tryParse(v?.trim() ?? '');
                            return grams == null || grams <= 0
                                ? 'Required'
                                : null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const NourishlySectionHeader(label: 'What that makes'),
                  _Preview(
                    nutrition: _preview,
                    hasIngredients: _ingredients.isNotEmpty,
                    statedCookedGrams: _number(_cookedGrams),
                    servingGrams: _number(_servingGrams),
                  ),
                ],
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(
                  top: BorderSide(
                    color: colors.line,
                    width: NourishlyStroke.hairline,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(NourishlySpace.s4),
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'Saving…' : 'Save recipe'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IngredientList extends StatelessWidget {
  const _IngredientList({
    required this.ingredients,
    required this.onRemove,
    required this.onChangeGrams,
  });

  final List<RecipeIngredient> ingredients;
  final void Function(int index) onRemove;
  final void Function(int index, double grams) onChangeGrams;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;

    if (ingredients.isEmpty) {
      return NourishlyCard(
        child: Text(
          'Nothing yet. Add the things that go in the pot, in the raw '
          'weights you use.',
          style: text.caption.copyWith(color: colors.ink3, height: 1.5),
        ),
      );
    }

    return NourishlyCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < ingredients.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: colors.line),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: NourishlySpace.s4,
                vertical: NourishlySpace.s2,
              ),
              child: Row(
                children: [
                  Expanded(child: Text(ingredients[i].name, style: text.body)),
                  SizedBox(
                    width: 72,
                    child: _GramsField(
                      key: ValueKey(ingredients[i].foodId),
                      grams: ingredients[i].grams,
                      onChanged: (grams) => onChangeGrams(i, grams),
                    ),
                  ),
                  IconButton(
                    onPressed: () => onRemove(i),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    tooltip: 'Remove ${ingredients[i].name}',
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GramsField extends StatefulWidget {
  const _GramsField({super.key, required this.grams, required this.onChanged});

  final double grams;
  final void Function(double) onChanged;

  @override
  State<_GramsField> createState() => _GramsFieldState();
}

class _GramsFieldState extends State<_GramsField> {
  late final _controller = TextEditingController(text: _format(widget.grams));

  /// Whole grams read as whole grams; a half gram keeps its half.
  ///
  /// This used to be `toStringAsFixed(0)`, which showed 4.5 g as "5" — a
  /// number the recipe did not contain. It matters now that something
  /// other than typing can set the value: halving 9 g of oil gives 4.5.
  static String _format(double grams) =>
      grams == grams.roundToDouble() ? grams.toStringAsFixed(0) : '$grams';

  /// Follows a change made from outside the field — "use less oil" edits
  /// the ingredient list directly, and without this the number on screen
  /// would still read 8 while the recipe was built from 4.
  ///
  /// Guarded twice so it never fights the person typing: only when the
  /// incoming value actually changed, and only when it disagrees with
  /// what is in the box.
  @override
  void didUpdateWidget(covariant _GramsField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.grams == oldWidget.grams) return;
    if (double.tryParse(_controller.text.trim()) == widget.grams) return;
    _controller.text = _format(widget.grams);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      textAlign: TextAlign.right,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
      decoration: const InputDecoration(
        isDense: true,
        suffixText: 'g',
        border: InputBorder.none,
      ),
      onChanged: (value) {
        final grams = double.tryParse(value.trim());
        if (grams != null) widget.onChanged(grams);
      },
    );
  }
}

/// The cooking-method fallback, offered only when there is no weighed
/// cooked weight to use instead. Disabled rather than hidden, so it is
/// clear why it stopped mattering.
class _MethodPicker extends StatelessWidget {
  const _MethodPicker({
    required this.method,
    required this.enabled,
    required this.onChanged,
  });

  final CookingMethod method;
  final bool enabled;
  final void Function(CookingMethod) onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            enabled
                ? 'No cooked weight? Pick how it was cooked and an estimate '
                      'is used instead.'
                : 'The cooked weight above is used, so this estimate is not '
                      'needed.',
            style: text.caption.copyWith(color: colors.ink3, height: 1.5),
          ),
          const SizedBox(height: NourishlySpace.s2),
          Wrap(
            spacing: NourishlySpace.s2,
            children: [
              for (final option in CookingMethod.values)
                ChoiceChip(
                  label: Text(
                    '${option.label} '
                    '×${option.yieldFactor.toStringAsFixed(2)}',
                  ),
                  selected: method == option,
                  onSelected: enabled ? (_) => onChanged(option) : null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Live nutrition for what is on the screen right now.
class _Preview extends ConsumerWidget {
  const _Preview({
    required this.nutrition,
    required this.hasIngredients,
    required this.statedCookedGrams,
    required this.servingGrams,
  });

  final RecipeNutrition? nutrition;
  final bool hasIngredients;
  final double? statedCookedGrams;
  final double? servingGrams;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;

    if (!hasIngredients) {
      return NourishlyCard(
        child: Text(
          'Add an ingredient and the numbers appear here.',
          style: text.caption.copyWith(color: colors.ink3),
        ),
      );
    }
    if (nutrition case final nutrition?) {
      final labels = ref.watch(nutrientLabelsProvider).value ?? const {};
      final servings = servingGrams == null || servingGrams! <= 0
          ? null
          : nutrition.cookedGrams / servingGrams!;

      return NourishlyCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${nutrition.rawGrams.round()} g in, '
              '${nutrition.cookedGrams.round()} g out '
              '(\u00d7${nutrition.yieldFactor.toStringAsFixed(2)})'
              '${servings == null ? '' : ' \u00b7 ${servings.toStringAsFixed(servings % 1 == 0 ? 0 : 1)} servings'}',
              style: text.caption.copyWith(color: colors.ink3),
            ),
            if (nutrition.basis == YieldBasis.cookingMethod)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  statedCookedGrams == null
                      ? 'Estimated from the cooking method.'
                      : 'That cooked weight looks like a slip, so the '
                            'cooking-method estimate is used instead.',
                  style: text.caption.copyWith(
                    fontSize: 10.5,
                    color: colors.statusUnknown,
                  ),
                ),
              ),
            const SizedBox(height: NourishlySpace.s3),
            for (final id in const [
              'energy',
              'protein',
              'carbs',
              'fat',
              'fibre',
            ])
              if (nutrition.per100g[id] case final per100g?)
                _PreviewRow(
                  label: shortNutrientName(labels[id]?.displayName ?? id),
                  perServing: servingGrams == null
                      ? null
                      : per100g * servingGrams! / 100,
                  per100g: per100g,
                  unit: labels[id]?.canonicalUnit ?? '',
                  coverage: nutrition.coverageOf(id),
                ),
            const SizedBox(height: NourishlySpace.s2),
            Text(
              _coverageNote(nutrition),
              style: text.caption.copyWith(
                fontSize: 10.5,
                color: colors.ink3,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }
    return const NourishlyCard(
      child: Center(child: CircularProgressIndicator()),
    );
  }

  /// §19.11: say how good the number is. A nutrient only some of the
  /// ingredients report is computed from part of the dish, and one hardly
  /// any of them report is dropped rather than stored looking whole.
  static String _coverageNote(RecipeNutrition nutrition) {
    final partial = nutrition.coverage.entries
        .where((e) => e.value < 0.999)
        .toList();
    if (partial.isEmpty) {
      return 'Every ingredient reports every nutrient shown.';
    }
    final dropped = partial
        .where((e) => e.value < RecipeDao.minComponentCoverage)
        .length;
    return 'Some nutrients are computed from part of the dish, because not '
        'every ingredient reports them. '
        '${dropped == 0 ? 'All of them still cover most of it.' : '$dropped '
                  '${dropped == 1 ? 'covers' : 'cover'} too little of it to be '
                  'worth storing, and will be left out.'}';
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.label,
    required this.perServing,
    required this.per100g,
    required this.unit,
    required this.coverage,
  });

  final String label;
  final double? perServing;
  final double per100g;
  final String unit;
  final double coverage;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    final isPartial = coverage < 0.999;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: text.caption)),
          if (isPartial)
            Padding(
              padding: const EdgeInsets.only(right: NourishlySpace.s2),
              child: Text(
                '${(coverage * 100).round()}% of the dish',
                style: text.caption.copyWith(
                  fontSize: 10,
                  color: coverage < RecipeDao.minComponentCoverage
                      ? colors.statusHigh
                      : colors.ink3,
                ),
              ),
            ),
          Text(
            perServing == null
                ? '${per100g.toStringAsFixed(unit == 'kcal' ? 0 : 1)} $unit / 100 g'
                : '${perServing!.toStringAsFixed(unit == 'kcal' ? 0 : 1)} $unit',
            style: text.caption.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Search the catalog for something to put in the pot.
class _IngredientPicker extends ConsumerStatefulWidget {
  const _IngredientPicker();

  @override
  ConsumerState<_IngredientPicker> createState() => _IngredientPickerState();
}

class _IngredientPickerState extends ConsumerState<_IngredientPicker> {
  final _query = TextEditingController();
  List<FoodItem> _results = const [];

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search(String value) async {
    final results = await ref
        .read(foodSearchDaoProvider)
        .search(value, preference: ref.read(dietaryPreferenceProvider));
    if (!mounted) return;
    setState(() => _results = results);
  }

  Future<void> _pick(FoodItem food) async {
    final entered = await showNourishlyPrompt(
      context: context,
      title: 'How much ${food.canonicalName}?',
      label: 'Raw weight',
      suffix: 'g',
      helper: 'What goes in the pot, before cooking.',
      confirmLabel: 'Add',
      numeric: true,
      validator: (value) {
        final grams = double.tryParse(value);
        return grams != null && grams > 0;
      },
    );
    final grams = double.tryParse(entered ?? '');
    if (grams == null || !mounted) return;
    Navigator.of(context).pop(
      RecipeIngredient(foodId: food.id, name: food.canonicalName, grams: grams),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;

    // Sized from the space that is actually left, not from the screen.
    //
    // This sheet used to ask for a flat `0.7 × screenHeight` and then add
    // the keyboard inset underneath it — a height that takes no account of
    // what is left to put it in. Its search field is autofocused, so the
    // keyboard is always up, and on a short phone the two together come to
    // more than the screen: what survives is then whatever the parent's
    // constraints clamp it to, which is not a decision anyone made.
    //
    // Reported as the picker "overflowing in mobile screen". The exact
    // overflow has not been reproduced in a widget test — the layout is
    // covered at 360 × 640 with a keyboard and at 200% type, and neither
    // throws — so this is the sizing being made deliberate rather than a
    // confirmed fix for that report.
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final available =
        media.size.height - media.padding.top - keyboard - NourishlySpace.s8;
    final cap = media.size.height * 0.7;
    // Written out rather than clamped: `clamp` asserts when the lower limit
    // is above the upper one, which is reachable on a short screen with a
    // tall keyboard — the exact case this is here to survive.
    var height = available < cap ? available : cap;
    if (height < 160) height = 160;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                NourishlySpace.s4,
                0,
                NourishlySpace.s4,
                NourishlySpace.s3,
              ),
              child: TextField(
                // Keyed so a test can reach this box rather than the
                // builder's own fields behind the sheet.
                key: const Key('ingredient-search'),
                controller: _query,
                autofocus: true,
                onChanged: _search,
                decoration: const InputDecoration(
                  hintText: 'Search for an ingredient',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            Expanded(
              child: _results.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(NourishlySpace.s6),
                        child: Text(
                          _query.text.trim().isEmpty
                              ? 'Search for the things that go in.'
                              : 'Nothing matched. A recipe can only be built '
                                    'from foods the app already knows — add '
                                    'it as a custom food first.',
                          textAlign: TextAlign.center,
                          style: text.caption.copyWith(color: colors.ink3),
                        ),
                      ),
                    )
                  : ListView.builder(
                      // Padded for the keyboard-free case too: the last row
                      // of a long list should not sit against the edge.
                      padding: const EdgeInsets.only(bottom: NourishlySpace.s4),
                      itemCount: _results.length,
                      itemBuilder: (context, index) => ListTile(
                        title: Text(
                          _results[index].canonicalName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: _results[index].brand == null
                            ? null
                            : Text(
                                _results[index].brand!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                        onTap: () => _pick(_results[index]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.numeric = false,
    this.validator,
    this.onChanged,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool numeric;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    return TextFormField(
      controller: controller,
      validator: validator,
      onChanged: onChanged,
      textCapitalization: textCapitalization,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      inputFormatters: numeric
          ? [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))]
          : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: colors.surface2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NourishlyRadius.md),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

/// One line per cooking fat, each accepted or skipped on its own.
///
/// The per-line choice is the whole design. A single "halve everything"
/// button would be quicker and would sometimes be wrong in a way nobody
/// could see: the oil a puri absorbs is not a dial the cook turns, and
/// once a recipe is stored, absorbed oil and pan oil are the same
/// ingredient row (catalog spec §0.6, `cooking_fat.dart`). Showing each
/// line lets the person who cooked it say which is which.
class _LighterFatSheet extends StatefulWidget {
  const _LighterFatSheet({required this.suggestions});

  final List<FatSuggestion> suggestions;

  @override
  State<_LighterFatSheet> createState() => _LighterFatSheetState();
}

class _LighterFatSheetState extends State<_LighterFatSheet> {
  late final Set<int> _accepted = {
    for (final suggestion in widget.suggestions) suggestion.index,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    final saved = widget.suggestions
        .where((s) => _accepted.contains(s.index))
        .fold<double>(0, (a, s) => a + s.gramsSaved);

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Use less oil', style: text.title),
            const SizedBox(height: NourishlySpace.s2),
            Text(
              'Half of what the recipe says, for each cooking fat. Untick '
              'anything that is deep-frying — a puri fried in less oil '
              'soaks up about the same.',
              style: text.caption.copyWith(color: colors.ink3, height: 1.5),
            ),
            const SizedBox(height: NourishlySpace.s3),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final suggestion in widget.suggestions)
                    CheckboxListTile(
                      value: _accepted.contains(suggestion.index),
                      onChanged: (on) => setState(() {
                        if (on ?? false) {
                          _accepted.add(suggestion.index);
                        } else {
                          _accepted.remove(suggestion.index);
                        }
                      }),
                      contentPadding: EdgeInsets.zero,
                      title: Text(suggestion.name, style: text.body),
                      subtitle: Text(
                        '${_grams(suggestion.grams)} g  →  '
                        '${_grams(suggestion.suggestedGrams)} g',
                        style: text.caption.copyWith(color: colors.ink3),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: NourishlySpace.s2),
            Text(
              saved <= 0
                  ? 'Nothing selected.'
                  : '${_grams(saved)} g less fat in the pot.',
              style: text.caption.copyWith(color: colors.ink2),
            ),
            const SizedBox(height: NourishlySpace.s3),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(_accepted),
                child: const Text('Apply'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _grams(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}
