import 'package:flutter/material.dart';

import '../../../../app/widgets/feature_placeholder.dart';

/// Derived targets, per-nutrient overrides, and goal management (§27.12).
/// Nested under the Profile tab at `/profile/goals` (§28.5). Lands in
/// Phase 3, once target derivation exists.
class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      title: 'Goals & targets',
      subtitle:
          'Derived targets and per-nutrient overrides land here in Phase 3.',
    );
  }
}
