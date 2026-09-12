import 'package:flutter/material.dart';
import 'package:nourishly_data/nourishly_data.dart';
import 'package:nourishly_ui/nourishly_ui.dart';

/// One row in the search results list (§27.4).
///
/// Name, cuisine, kind and quality tier. Default serving and
/// energy-for-that-serving belong here too per §27.4, but need
/// `nutrition_core`'s aggregation (empty in Phase 1, §0.6) to compute.
/// Wiring that in is a follow-up once scoring is no longer provisional.
///
/// **The cuisine is not decoration.** Twelve display names in the catalog
/// are carried by two or three rows each — "Coconut rice" is a Tamil dish
/// and a Kannadiga dish and a pan-Indian one — and without it they render
/// as identical lines nobody can choose between. Catalog spec §0.6 keeps
/// them as separate foods deliberately; this is what tells them apart.
class FoodSearchResultTile extends StatelessWidget {
  const FoodSearchResultTile({
    super.key,
    required this.food,
    required this.onTap,
  });

  final FoodItem food;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;

    return ListTile(
      onTap: onTap,
      title: Text(food.canonicalName, style: text.body),
      subtitle: Text(
        [
          ?food.brand,
          ?cuisineLabel(food.cuisine),
          _kindLabel(food.kind),
        ].join(' · '),
        style: text.caption.copyWith(color: colors.ink3),
      ),
      trailing: _QualityBadge(tier: food.qualityTier),
    );
  }

  /// How a cuisine tag reads to a person. Null stays null — a food with
  /// no cuisine shows no cuisine rather than "Other", which would be a
  /// label pretending to be information.
  static String? cuisineLabel(String? cuisine) => switch (cuisine) {
    null => null,
    'pan-indian' => 'Pan-Indian',
    'gujarati' => 'Gujarati',
    'tamil' => 'Tamil',
    'kannadiga' => 'Kannadiga',
    'north-indian' => 'North Indian',
    'italian' => 'Italian',
    'modern' => 'Modern',
    // An unrecognised tag is shown as written rather than swallowed: it
    // means the pipeline learned a cuisine this screen has not, and
    // seeing it is how that gets noticed.
    _ => cuisine,
  };

  String _kindLabel(String kind) => switch (kind) {
    'ingredient' => 'Ingredient',
    'dish' => 'Dish',
    'branded' => 'Branded',
    'recipe' => 'Recipe',
    'user_custom' => 'Your food',
    _ => kind,
  };
}

/// Quality tier shown as a small badge so users can prefer verified data
/// (§19.11, §27.4).
class _QualityBadge extends StatelessWidget {
  const _QualityBadge({required this.tier});

  final String tier;

  /// The prototype's short provenance badges: measured lab data reads
  /// "Lab", a user's own food reads "You" (screen 5, option A).
  String get _label => switch (tier) {
    'verified' => 'Lab',
    'derived' => 'Calc',
    'label' => 'Label',
    'community' => 'Comm',
    'user' => 'You',
    _ => tier,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: NourishlySpace.s2,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(NourishlyRadius.pill),
      ),
      child: Text(
        _label,
        style: text.overline.copyWith(color: colors.ink2, letterSpacing: 0),
      ),
    );
  }
}
