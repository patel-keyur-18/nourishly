import 'package:flutter/material.dart';

import '../../../../app/widgets/feature_placeholder.dart';

/// The daily dashboard (§27.2) — the app's most-viewed screen once it's
/// built: energy ring, macro bars, water, focus nutrients, and the day's
/// meals. Phase 3 onward, once targets and summaries exist to show.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      title: 'Today',
      subtitle:
          'Your daily dashboard lands here once logging and targets exist.',
    );
  }
}
