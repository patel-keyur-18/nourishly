import 'package:flutter/material.dart';

import '../../../../app/widgets/feature_placeholder.dart';

/// Daily/weekly/monthly reports (prototype screens 9-11) — the "Insights"
/// tab. Depends on the scoring engine, which waits on the nutrition review
/// packet (§0.6); lands in Phase 3/4.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      title: 'Insights',
      subtitle:
          'Daily, weekly and monthly reports need the scoring engine — they '
          'arrive in Phase 3.',
    );
  }
}
