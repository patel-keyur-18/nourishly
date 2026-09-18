import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nourishly_data/nourishly_data.dart';
import 'package:nourishly_ui/nourishly_ui.dart';

import '../../data/recipe_providers.dart';

/// The profile's own recipes (§19.10).
///
/// There is no prototype screen for this — the approved set covers the
/// thirteen screens of the logging and reporting flow, and recipes were
/// scoped into Phase 4 by §36 without a design pass. It is drawn in the
/// same idiom as the rest: section header, card, hairline-divided rows.
class RecipesScreen extends ConsumerWidget {
  const RecipesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    final recipesAsync = ref.watch(recipesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Your recipes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/recipes/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New recipe'),
      ),
      body: recipesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(NourishlySpace.s6),
            child: Text('$error', textAlign: TextAlign.center),
          ),
        ),
        data: (recipes) => ListView(
          padding: const EdgeInsets.fromLTRB(
            NourishlySpace.s4,
            NourishlySpace.s3,
            NourishlySpace.s4,
            NourishlySpace.s9,
          ),
          children: [
            if (recipes.isEmpty)
              NourishlyCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nothing here yet.',
                      style: text.body.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: NourishlySpace.s2),
                    Text(
                      'A recipe is a dish built from its ingredients. Once '
                      'you have saved one it behaves like any other food: '
                      'search for it, pick a portion, log it.',
                      style: text.caption.copyWith(
                        color: colors.ink3,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              )
            else
              NourishlyCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < recipes.length; i++) ...[
                      if (i > 0)
                        Divider(height: 1, thickness: 1, color: colors.line),
                      _RecipeRow(recipe: recipes[i]),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: NourishlySpace.s4),
            Text(
              'Editing a recipe never changes a meal you have already '
              'logged from it — those keep the numbers they were measured '
              'with.',
              style: text.caption.copyWith(color: colors.ink3, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecipeRow extends StatelessWidget {
  const _RecipeRow({required this.recipe});

  final SavedRecipe recipe;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    final count = recipe.ingredients.length;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/recipes/${recipe.foodId}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: NourishlySpace.s4,
            vertical: NourishlySpace.s3,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.name,
                      style: text.body.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '$count ${count == 1 ? 'ingredient' : 'ingredients'} '
                      '· makes ${_servings(recipe)}',
                      style: text.caption.copyWith(color: colors.ink3),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.ink3, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  static String _servings(SavedRecipe recipe) {
    final servings = recipe.servings;
    if (servings <= 0) return '${recipe.cookedGrams.round()} g';
    final rounded = servings.toStringAsFixed(servings % 1 == 0 ? 0 : 1);
    return '$rounded × ${recipe.servingLabel}';
  }
}
