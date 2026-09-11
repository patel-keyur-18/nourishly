import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nourishly_data/nourishly_data.dart';

import '../../../app/providers.dart';
import '../../food_catalog/data/food_catalog_providers.dart';
import '../../profile/data/profile_providers.dart';

final recipeDaoProvider = Provider<RecipeDao>((ref) {
  return RecipeDao(ref.watch(nourishlyDatabaseProvider));
});

/// The profile's own recipes, newest first.
final recipesProvider = FutureProvider<List<SavedRecipe>>((ref) async {
  ref.watch(recipeRevisionProvider);
  await ref.watch(catalogReadyProvider.future);
  final ownerId = await ref.watch(defaultOwnerProvider.future);
  return ref.watch(recipeDaoProvider).recipesFor(ownerId);
});

/// One recipe, for the builder to open in edit mode.
final recipeProvider = FutureProvider.family<SavedRecipe?, String>((
  ref,
  foodId,
) async {
  ref.watch(recipeRevisionProvider);
  await ref.watch(catalogReadyProvider.future);
  return ref.watch(recipeDaoProvider).recipe(foodId);
});

/// Bumped after a recipe is saved or deleted, so the list and any open
/// detail re-read. The same pattern as [summaryRevisionProvider], and for
/// the same reason: a recipe write touches four tables and drift's change
/// stream on any one of them is not the signal.
class RecipeRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final recipeRevisionProvider = NotifierProvider<RecipeRevision, int>(
  RecipeRevision.new,
);
