import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nourishly_ui/nourishly_ui.dart';

/// Onboarding (prototype screen 1, option B — single promise screen).
///
/// One screen, one sentence, straight into setup. Not yet a startup gate:
/// profile setup itself (screen 2) needs Phase 3's profile model, so
/// "Set up my profile" goes to the app for now rather than to a form that
/// cannot save anything.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  static const _promises = [
    (Icons.wifi_off_rounded, 'Works with no signal'),
    (Icons.restaurant_menu_rounded, 'Knows Gujarati, Tamil and Kannadiga food'),
    (Icons.lock_outline_rounded, 'No account, no ads'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(NourishlySpace.s6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.accent,
                  borderRadius: BorderRadius.circular(NourishlyRadius.lg),
                ),
                child: Text(
                  'N',
                  style: text.title.copyWith(color: colors.accentInk),
                ),
              ),
              const SizedBox(height: NourishlySpace.s5),
              Text('Nourishly', style: text.display),
              const SizedBox(height: NourishlySpace.s3),
              Text(
                'A private food and water diary for your household. '
                'Everything stays on this phone.',
                style: text.bodyLarge.copyWith(color: colors.ink2),
              ),
              const SizedBox(height: NourishlySpace.s6),
              for (final (icon, label) in _promises)
                Padding(
                  padding: const EdgeInsets.only(bottom: NourishlySpace.s3),
                  child: Row(
                    children: [
                      Icon(icon, size: 18, color: colors.accent),
                      const SizedBox(width: NourishlySpace.s3),
                      Expanded(
                        child: Text(
                          label,
                          style: text.body.copyWith(color: colors.ink2),
                        ),
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              FilledButton(
                onPressed: () => context.go('/today'),
                child: const Text('Set up my profile'),
              ),
              const SizedBox(height: NourishlySpace.s2),
              TextButton(
                onPressed: () => context.go('/today'),
                child: const Text('Skip for now'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
