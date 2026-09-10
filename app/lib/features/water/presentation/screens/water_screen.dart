import 'package:flutter/material.dart';

import '../../../../app/widgets/feature_placeholder.dart';

/// Hydration detail and history (§27.7). Has its own tab because water is
/// the highest-frequency logging action and works standalone with zero
/// nutrition setup (§28.3, Persona 4). Lands in Phase 2 with logging.
class WaterScreen extends StatelessWidget {
  const WaterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      title: 'Water',
      subtitle: 'Hydration tracking lands here alongside food logging.',
    );
  }
}
