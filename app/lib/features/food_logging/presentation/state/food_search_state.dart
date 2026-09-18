import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nourishly_data/nourishly_data.dart';

import '../../../../app/providers.dart';
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
  // Both of these reorder and neither filters: FR-U-16 for the stated
  // preference, and §27.4's rule that a search must never silently omit
  // what you typed.
  // Awaited rather than read optimistically: resolving it later would
  // reorder results under the reader's finger, and it is one cheap query
  // that Riverpod then caches.
  final preferredCuisines = await ref.watch(preferredCuisinesProvider.future);
  return dao.search(
    query,
    preference: ref.watch(dietaryPreferenceProvider),
    preferredCuisines: preferredCuisines,
  );
});

/// The cuisines this profile eats often enough for the app to believe it
/// (§0.8 of the catalog spec, `CuisineDao.frequentCuisines`).
///
/// Read from the log rather than asked for: a household that eats Gujarati
/// food and types "dal" means Gujarati dal, and it should not have to say
/// so in a setting. Empty until there is real evidence — a new profile, or
/// a catalog whose seed predates cuisine tags — and empty leaves search
/// ordered exactly as it was.
final preferredCuisinesProvider = FutureProvider.autoDispose<Set<String>>((
  ref,
) async {
  await ref.watch(catalogReadyProvider.future);
  final ownerId = await ref.watch(defaultOwnerProvider.future);
  final cuisines = await CuisineDao(ref.watch(nourishlyDatabaseProvider))
      .frequentCuisines(ownerId, now: ref.watch(clockProvider).now());
  return cuisines.toSet();
});

/// Every cuisine the catalog can offer, biggest first — the browse shelf
/// shown when nobody has typed anything.
///
/// At 441 foods across seven cuisines, "search for a food" assumes you
/// remember what is in there. This is the other half of UX-6: an empty
/// search box should be a way in, not a blank.
final catalogCuisinesProvider = FutureProvider<List<CuisineCount>>((ref) async {
  await ref.watch(catalogReadyProvider.future);
  return CuisineDao(ref.watch(nourishlyDatabaseProvider)).cuisinesInCatalog();
});

/// The cuisine being browsed, or null while searching normally.
class BrowsedCuisineNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? cuisine) => state = cuisine;
}

final browsedCuisineProvider =
    NotifierProvider.autoDispose<BrowsedCuisineNotifier, String?>(
      BrowsedCuisineNotifier.new,
    );

/// The foods in the cuisine being browsed.
final browsedFoodsProvider = FutureProvider.autoDispose<List<FoodItem>>((
  ref,
) async {
  final cuisine = ref.watch(browsedCuisineProvider);
  if (cuisine == null) return const [];
  await ref.watch(catalogReadyProvider.future);
  return CuisineDao(ref.watch(nourishlyDatabaseProvider))
      .foodsInCuisine(cuisine);
});
