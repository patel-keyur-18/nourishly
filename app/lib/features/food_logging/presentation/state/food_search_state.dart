import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nourishly_data/nourishly_data.dart';

import '../../../food_catalog/data/food_catalog_providers.dart';
import '../../../profile/data/profile_providers.dart';

/// The search box's current text — ephemeral UI state, scoped to the
/// screen and auto-disposed (§14.5). The screen debounces keystrokes
/// before calling [update] (§14.7: "debounced ~120 ms"); this notifier
/// itself doesn't debounce.
class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void update(String value) => state = value;
}

final searchQueryProvider =
    NotifierProvider.autoDispose<SearchQueryNotifier, String>(
      SearchQueryNotifier.new,
    );

/// Live search results for the current query (§27.4). Empty (not an
/// error) for an empty query — the search screen's default-empty state,
/// not a failed search.
///
/// Re-running this on every [searchQueryProvider] change is what gives
/// "cancels in-flight queries on new keystrokes" (§14.7) for free: Riverpod
/// only ever exposes the latest build's result to watchers, so a slower,
/// now-stale query can't overwrite a newer one.
final foodSearchResultsProvider = FutureProvider.autoDispose<List<FoodItem>>((
  ref,
) async {
  final query = ref.watch(searchQueryProvider).trim();
  if (query.isEmpty) return const [];

  final dao = ref.watch(foodSearchDaoProvider);
  // FR-U-16: the stated preference reorders results, never filters them.
  return dao.search(query, preference: ref.watch(dietaryPreferenceProvider));
});
