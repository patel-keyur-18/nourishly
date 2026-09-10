import 'package:flutter/material.dart';

import '../../../../app/widgets/feature_placeholder.dart';

/// The single-promise onboarding screen and profile setup (§27.1). Routed
/// at `/onboarding` but not yet wired as a startup gate — deciding "has
/// this device seen a profile before" is a Phase 2 concern once
/// [nourishly_data]'s DAOs exist to answer it. The app starts at `/today`
/// for now.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      title: 'Welcome to Nourishly',
      subtitle: 'Profile setup and derived targets land here in Phase 2/3.',
    );
  }
}
