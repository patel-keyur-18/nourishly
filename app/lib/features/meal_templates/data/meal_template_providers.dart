import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nourishly_data/nourishly_data.dart';

import '../../../app/providers.dart';
import '../../food_catalog/data/food_catalog_providers.dart';

final mealTemplateDaoProvider = Provider<MealTemplateDao>((ref) {
  return MealTemplateDao(ref.watch(nourishlyDatabaseProvider));
});

/// The profile's saved templates, newest first.
final mealTemplatesProvider = FutureProvider<List<SavedMealTemplate>>((
  ref,
) async {
  ref.watch(mealTemplateRevisionProvider);
  final ownerId = await ref.watch(defaultOwnerProvider.future);
  return ref.watch(mealTemplateDaoProvider).templatesFor(ownerId);
});

/// Bumped after a template is created, applied, or deleted, matching
/// `RecipeRevision`'s pattern in `recipe_providers.dart`.
class MealTemplateRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final mealTemplateRevisionProvider =
    NotifierProvider<MealTemplateRevision, int>(MealTemplateRevision.new);
