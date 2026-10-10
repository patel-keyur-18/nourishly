import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nourishly_data/nourishly_data.dart';
import 'package:nourishly_ui/nourishly_ui.dart';

import '../state/food_search_state.dart';
import '../widgets/food_search_result_tile.dart';

/// The logging flow, opened modally from the bottom nav's centre action
/// (prototype screens 4 and 5 — full screen, search first; results grouped
/// by source so provenance stays visible, §19.11).
class FoodLoggingScreen extends ConsumerStatefulWidget {
  const FoodLoggingScreen({super.key, this.mealSlotId, this.planDate});

  /// The slot the user came in through, when they came in through one —
  /// "Add breakfast" on the dashboard rather than the nav bar's centre
  /// action. Passed down to the portion screen so the meal is already
  /// chosen there.
  final String? mealSlotId;

  /// Set when the flow started from the week plan, and carried through to
  /// the portion screen so the entry lands on that date as an intention
  /// rather than on today as intake.
  final String? planDate;

  @override
  ConsumerState<FoodLoggingScreen> createState() => _FoodLoggingScreenState();
}

/// The `?meal=…&plan=…` suffix every push out of this screen carries.
///
/// One function rather than a concatenation at each call site: the flow
/// has three ways into the portion screen, and a destination that silently
/// drops the plan date on one of them writes the meal into today.
String foodFlowQuery({String? mealSlotId, String? planDate}) {
  final parts = [
    if (mealSlotId != null) 'meal=$mealSlotId',
    if (planDate != null) 'plan=$planDate',
  ];
  return parts.isEmpty ? '' : '?${parts.join('&')}';
}

class _FoodLoggingScreenState extends ConsumerState<FoodLoggingScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    // §14.7: search is debounced ~120 ms and cancels in-flight queries on
    // new keystrokes.
    _debounce = Timer(NourishlyMotion.fast, () {
      ref.read(searchQueryProvider.notifier).update(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final query = ref.watch(searchQueryProvider);
    final resultsAsync = ref.watch(foodSearchResultsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add food'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Close',
          // Never a dead end: if this screen was somehow opened without
          // anything under it, closing still goes home rather than doing
          // nothing. That state used to be reachable from the dashboard's
          // meal rows, and the app could not be navigated afterwards.
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/today'),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              NourishlySpace.s4,
              NourishlySpace.s2,
              NourishlySpace.s4,
              NourishlySpace.s3,
            ),
            child: TextField(
              controller: _controller,
              autofocus: true,
              onChanged: _onChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search foods',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        tooltip: 'Clear search',
                        onPressed: () {
                          _controller.clear();
                          _onChanged('');
                        },
                      ),
                filled: true,
                fillColor: colors.surface2,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(NourishlyRadius.md),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: NourishlySpace.s3,
                ),
              ),
            ),
          ),
          Expanded(
            child: resultsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => _Message(
                icon: Icons.error_outline_rounded,
                title: 'Something went wrong searching.',
              ),
              data: (results) {
                if (query.trim().isEmpty) {
                  return _BrowseByCuisine(
                    mealSlotId: widget.mealSlotId,
                    planDate: widget.planDate,
                  );
                }
                return _Results(
                  query: query,
                  results: results,
                  mealSlotId: widget.mealSlotId,
                  planDate: widget.planDate,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// What an empty search box offers instead of nothing: the cuisines in the
/// catalog, and the foods inside whichever one is picked.
///
/// UX-6 made custom-food creation one tap from a failed search, which was
/// the right answer for a catalog small enough to hold in your head. At
/// 441 foods across seven cuisines it no longer is — "search for a food"
/// now assumes knowledge the person does not have. Browsing is the other
/// half of that.
///
/// It shows nothing at all when the catalog carries no cuisine tags, which
/// is what a seed built before §0.8 looks like. An empty shelf would be
/// worse than no shelf.
class _BrowseByCuisine extends ConsumerWidget {
  const _BrowseByCuisine({required this.mealSlotId, required this.planDate});

  final String? mealSlotId;
  final String? planDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    final cuisines = ref.watch(catalogCuisinesProvider).value ?? const [];
    final selected = ref.watch(effectiveBrowsedCuisineProvider);

    if (cuisines.isEmpty) {
      return const _Message(
        icon: Icons.search_rounded,
        title: 'Search for a food to log',
        subtitle: 'Recents and favourites arrive in a later phase.',
      );
    }

    final foods = ref.watch(browsedFoodsProvider).value ?? const <FoodItem>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: NourishlySpace.s4),
          child: NourishlyCard(
            onTap: () => context.push('/templates'),
            padding: const EdgeInsets.symmetric(
              horizontal: NourishlySpace.s4,
              vertical: NourishlySpace.s3,
            ),
            child: Row(
              children: [
                Icon(Icons.repeat_rounded, color: colors.accent, size: 20),
                const SizedBox(width: NourishlySpace.s3),
                Expanded(
                  child: Text(
                    'Log from a saved meal template',
                    style: text.label.copyWith(color: colors.accent),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colors.accent,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            NourishlySpace.s4,
            NourishlySpace.s4,
            NourishlySpace.s4,
            NourishlySpace.s2,
          ),
          child: Text(
            'Or browse by cuisine',
            style: text.caption.copyWith(color: colors.ink3),
          ),
        ),
        // One line that scrolls sideways, rather than a Wrap. Seven
        // cuisines wrapped to three or four rows on a phone, and those
        // rows pushed the foods — the thing the screen is for — off the
        // bottom. A SingleChildScrollView rather than a fixed-height
        // list so the strip still grows with the text scale (NFR-A-03).
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: NourishlySpace.s4),
          child: Row(
            children: [
              for (var i = 0; i < cuisines.length; i++) ...[
                if (i > 0) const SizedBox(width: NourishlySpace.s2),
                ChoiceChip(
                  selected: selected == cuisines[i].cuisine,
                  label: Text(
                    '${FoodSearchResultTile.cuisineLabel(cuisines[i].cuisine)} '
                    '· ${cuisines[i].count}',
                  ),
                  // Always selects, never toggles off. A cuisine is
                  // always showing now, so a chip that cleared itself
                  // would blank the list under the user's finger.
                  onSelected: (_) => ref
                      .read(browsedCuisineProvider.notifier)
                      .select(cuisines[i].cuisine),
                ),
              ],
            ],
          ),
        ),
        // Everything left over goes to the foods, in one grouped card
        // like the search results use.
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              NourishlySpace.s4,
              NourishlySpace.s3,
              NourishlySpace.s4,
              NourishlySpace.s9,
            ),
            children: [
              if (foods.isNotEmpty)
                NourishlyCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < foods.length; i++) ...[
                        if (i > 0)
                          Divider(height: 1, thickness: 1, color: colors.line),
                        FoodSearchResultTile(
                          food: foods[i],
                          onTap: () => context.push(
                            '/log/food/${foods[i].id}'
                            '${foodFlowQuery(mealSlotId: mealSlotId, planDate: planDate)}',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Results grouped by source (prototype screen 5, option A). Everything in
/// the bundled catalog is one group today; user-created foods and recents
/// become their own groups once those features exist.
class _Results extends StatelessWidget {
  const _Results({
    required this.query,
    required this.results,
    required this.mealSlotId,
    required this.planDate,
  });

  final String query;
  final List<FoodItem> results;
  final String? mealSlotId;
  final String? planDate;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        NourishlySpace.s4,
        0,
        NourishlySpace.s4,
        NourishlySpace.s7,
      ),
      children: [
        if (results.isNotEmpty) ...[
          const NourishlySectionHeader(label: 'Food catalog'),
          NourishlyCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < results.length; i++) ...[
                  if (i > 0)
                    Divider(height: 1, thickness: 1, color: colors.line),
                  FoodSearchResultTile(
                    food: results[i],
                    onTap: () => context.push(
                      '/log/food/${results[i].id}'
                      '${foodFlowQuery(mealSlotId: mealSlotId, planDate: planDate)}',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        const NourishlySectionHeader(label: 'Not finding it?'),
        _CreateCustomFoodRow(
          query: query,
          mealSlotId: mealSlotId,
          planDate: planDate,
        ),
        const SizedBox(height: NourishlySpace.s2),
        const _BuildRecipeRow(),
      ],
    );
  }
}

/// `Create "<query>" as a custom food` — always available, so a failed
/// search is never a dead end (UX-6). Creation itself lands with custom
/// foods in a later phase.
class _CreateCustomFoodRow extends StatelessWidget {
  const _CreateCustomFoodRow({
    required this.query,
    required this.mealSlotId,
    required this.planDate,
  });

  final String query;
  final String? mealSlotId;
  final String? planDate;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    return NourishlyCard(
      onTap: () => context.push(
        '/log/new?name=${Uri.encodeQueryComponent(query.trim())}'
        '${mealSlotId == null ? '' : '&meal=$mealSlotId'}'
        '${planDate == null ? '' : '&plan=$planDate'}',
      ),
      child: Row(
        children: [
          Icon(
            Icons.add_circle_outline_rounded,
            color: colors.accent,
            size: 20,
          ),
          const SizedBox(width: NourishlySpace.s3),
          Expanded(
            child: Text(
              'Create "$query" as a custom food',
              style: text.label.copyWith(color: colors.accent),
            ),
          ),
        ],
      ),
    );
  }
}

/// The other way out of a failed search: a dish the catalog does not have
/// as a dish, but does have as its ingredients (§19.10).
class _BuildRecipeRow extends StatelessWidget {
  const _BuildRecipeRow();

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    return NourishlyCard(
      onTap: () => context.push('/recipes/new'),
      child: Row(
        children: [
          Icon(Icons.blender_outlined, color: colors.accent, size: 20),
          const SizedBox(width: NourishlySpace.s3),
          Expanded(
            child: Text(
              'Build it as a recipe, from its ingredients',
              style: text.label.copyWith(color: colors.accent),
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, this.subtitle});

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(NourishlySpace.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: colors.ink3, size: 26),
            const SizedBox(height: NourishlySpace.s3),
            Text(
              title,
              textAlign: TextAlign.center,
              style: text.body.copyWith(color: colors.ink2),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: NourishlySpace.s2),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: text.caption.copyWith(color: colors.ink3),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
