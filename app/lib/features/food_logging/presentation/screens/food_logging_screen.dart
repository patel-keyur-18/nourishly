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
          onPressed: () => context.pop(),
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
                  return const _Message(
                    icon: Icons.search_rounded,
                    title: 'Search for a food to log',
                    subtitle:
                        'Recents, favourites and meal templates arrive in a '
                        'later phase.',
                  );
                }
                return _Results(query: query, results: results);
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Results grouped by source (prototype screen 5, option A). Everything in
/// the bundled catalog is one group today; user-created foods and recents
/// become their own groups once those features exist.
class _Results extends StatelessWidget {
  const _Results({required this.query, required this.results});

  final String query;
  final List<FoodItem> results;

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
                    onTap: () => context.push('/log/food/${results[i].id}'),
                  ),
                ],
              ],
            ),
          ),
        ],
        const NourishlySectionHeader(label: 'Not finding it?'),
        _CreateCustomFoodRow(query: query),
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
  const _CreateCustomFoodRow({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    return NourishlyCard(
      onTap: () => context.push(
        '/log/new?name=${Uri.encodeQueryComponent(query.trim())}',
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
