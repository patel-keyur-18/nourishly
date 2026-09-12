import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nourishly_ui/nourishly_ui.dart';

import '../../../../app/providers.dart';
import '../../../profile/data/profile_providers.dart';

/// Onboarding (prototype screen 1, option B — single promise screen).
///
/// One screen, one sentence, straight into setup — which now exists, so
/// the primary action goes there rather than into the app. Skip is beside
/// it and equally reachable: §27.1 makes every step of setup optional, and
/// a skipped profile is a working app with generic targets.
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  /// Marks the welcome seen whichever way the user leaves it. Skipping is
  /// a decision, not a deferral — §27.1 makes setup optional, so asking
  /// again next launch would be nagging.
  static Future<void> _dismiss(WidgetRef ref, String destination) async {
    final router = GoRouter.of(ref.context);
    final ownerId = await ref.read(defaultOwnerProvider.future);
    await ref
        .read(preferencesDaoProvider)
        .update(ownerId, onboardingSeen: true);
    ref.read(summaryRevisionProvider.notifier).bump();
    router.go(destination);
  }

  static const _promises = [
    (Icons.wifi_off_rounded, 'Works with no signal'),
    (Icons.restaurant_menu_rounded, 'Knows Gujarati, Tamil and Kannadiga food'),
    (Icons.lock_outline_rounded, 'No account, no ads'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                onPressed: () => _dismiss(ref, '/profile/setup?from=welcome'),
                child: const Text('Set up my profile'),
              ),
              const SizedBox(height: NourishlySpace.s2),
              TextButton(
                onPressed: () => _dismiss(ref, '/today'),
                child: const Text('Skip for now'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
