import 'package:flutter/material.dart';
import 'package:nourishly_data/nourishly_data.dart';
import 'package:nourishly_ui/nourishly_ui.dart';

/// One row in the search results list (§27.4).
///
/// Only name, kind, and quality tier are shown — default serving and
/// energy-for-that-serving belong here too per §27.4, but need
/// `nutrition_core`'s aggregation (empty in Phase 1, §0.6) to compute.
/// Wiring that in is a follow-up once scoring is no longer provisional.
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
        [?food.brand, _kindLabel(food.kind)].join(' · '),
        style: text.caption.copyWith(color: colors.ink3),
      ),
      trailing: _QualityBadge(tier: food.qualityTier),
    );
  }

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
