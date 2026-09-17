import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nourishly_ui/nourishly_ui.dart';

import '../../../../app/providers.dart';
import '../../../profile/data/profile_editor.dart';
import '../../../profile/data/profile_providers.dart';

/// Onboarding (prototype screen 1, option B — single promise screen).
///
/// One screen, one sentence, straight into setup — which now exists, so
/// the primary action goes there rather than into the app. Skip is beside
/// it and equally reachable: §27.1 makes every step of setup optional, and
/// a skipped profile is a working app with generic targets.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  static const _promises = [
    (Icons.wifi_off_rounded, 'Works with no signal'),
    (Icons.restaurant_menu_rounded, 'Knows Gujarati, Tamil and Kannadiga food'),
    (Icons.lock_outline_rounded, 'No account, no ads'),
  ];

  /// Saves the name whichever way the screen is left, then marks the
  /// welcome seen and moves on — §27.1 makes every step optional, so a
  /// blank field is a real answer, not a validation failure.
  Future<void> _dismiss(String destination) async {
    final router = GoRouter.of(context);
    final name = _nameController.text.trim();
    if (name.isNotEmpty) {
      await ref.read(profileEditorProvider).rename(name);
    }
    final ownerId = await ref.read(defaultOwnerProvider.future);
    await ref
        .read(preferencesDaoProvider)
        .update(ownerId, onboardingSeen: true);
    ref.read(summaryRevisionProvider.notifier).bump();
    router.go(destination);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  NourishlySpace.s6,
                  NourishlySpace.s6,
                  NourishlySpace.s6,
                  0,
                ),
                children: [
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
                      padding: const EdgeInsets.only(
                        bottom: NourishlySpace.s3,
                      ),
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
                  const SizedBox(height: NourishlySpace.s5),
                  TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Your name (optional)',
                      helperText: 'Shown on the dashboard, and nowhere else.',
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(NourishlySpace.s6),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () =>
                          _dismiss('/profile/setup?from=welcome'),
                      child: const Text('Set up my profile'),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _dismiss('/today'),
                    child: const Text('Skip for now'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
