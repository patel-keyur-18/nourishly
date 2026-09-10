import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nourishly_ui/nourishly_ui.dart';

import '../state/food_search_state.dart';
import '../widgets/food_search_result_tile.dart';

/// The logging flow, opened modally from the bottom nav's centre action
/// (§27.3, §28.4) and dismissed back to wherever the user was.
///
/// A search field with live, debounced results (§27.4, NFR-P-03) that
/// pushes to [FoodPortionScreen] on selection, which does the actual
/// write. Recents/Favourites/Templates tabs (§27.3's default view) and
/// custom food creation are still a follow-up.
class FoodLoggingScreen extends ConsumerStatefulWidget {
  const FoodLoggingScreen({super.key});

  @override
  ConsumerState<FoodLoggingScreen> createState() => _FoodLoggingScreenState();
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
    // §14.7: "Search is debounced ~120 ms and cancels in-flight queries on
    // new keystrokes."
    _debounce = Timer(NourishlyMotion.fast, () {
      ref.read(searchQueryProvider.notifier).update(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    final query = ref.watch(searchQueryProvider);
    final resultsAsync = ref.watch(foodSearchResultsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Log food or water'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(NourishlySpace.s4),
            child: TextField(
              controller: _controller,
              autofocus: true,
              onChanged: _onChanged,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Search foods',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          Expanded(
            child: resultsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(
                child: Text(
                  'Something went wrong searching.',
                  style: text.body.copyWith(color: colors.ink3),
                ),
              ),
              data: (results) {
                if (query.trim().isEmpty) {
                  // §27.3: recents/favourites are the default view, not a
                  // keyboard — not yet built, so this is a plain prompt.
                  return Center(
                    child: Text(
                      'Search for a food to log.',
                      style: text.body.copyWith(color: colors.ink3),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: results.length + 1,
                  itemBuilder: (context, index) {
                    if (index == results.length) {
                      return _CreateCustomFoodRow(query: query);
                    }
                    final food = results[index];
                    return FoodSearchResultTile(
                      food: food,
                      onTap: () => context.push('/log/food/${food.id}'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// `Create "<query>" as a custom food`, always pinned at the bottom of
/// results (UX-6: nothing is unloggable). Creation itself isn't built yet.
class _CreateCustomFoodRow extends StatelessWidget {
  const _CreateCustomFoodRow({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    return ListTile(
      leading: Icon(Icons.add_circle_outline_rounded, color: colors.accent),
      title: Text(
        'Create "$query" as a custom food',
        style: TextStyle(color: colors.accent),
      ),
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Custom food creation is coming soon.')),
        );
      },
    );
  }
}
