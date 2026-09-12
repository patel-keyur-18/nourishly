import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nourishly_ui/nourishly_ui.dart';

import '../../../../app/providers.dart';
import '../../../profile/data/profile_providers.dart';
import '../../data/backup_providers.dart';

/// §0.5's third backup mechanism: "a periodic export prompt — monthly,
/// dismissible, never nagging. With no server, an occasional gentle
/// reminder is the entire disaster-recovery strategy, and it costs one
/// screen."
///
/// It costs rather less than a screen: a card on the dashboard that shows
/// up when a month has passed with no export, and disappears for another
/// month the moment it is acted on or dismissed. Deliberately not a
/// dialog. A dialog interrupts the thing the user opened the app to do,
/// and this is a suggestion, not an error.
///
/// Note the wording: it does not say the data is at risk, because with
/// platform backup running it usually is not. It says what an export is
/// good for, which is the honest case for taking one.
class ExportPromptBanner extends ConsumerWidget {
  const ExportPromptBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(shouldPromptForExportProvider)) {
      return const SizedBox.shrink();
    }

    final colors = context.nourishlyColors;
    final text = context.nourishlyText;

    return Padding(
      padding: const EdgeInsets.only(bottom: NourishlySpace.s3),
      child: NourishlyCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.archive_outlined,
                  size: 20,
                  color: colors.accent,
                ),
                const SizedBox(width: NourishlySpace.s3),
                Expanded(
                  child: Text(
                    'Worth keeping a copy of your logging somewhere other '
                    'than this phone. It takes a few seconds.',
                    style: text.caption.copyWith(
                      color: colors.ink2,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: NourishlySpace.s2),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _snooze(ref),
                  child: const Text('Not now'),
                ),
                const SizedBox(width: NourishlySpace.s2),
                FilledButton(
                  // The theme makes filled buttons full-width
                  // (`Size.fromHeight`), which is right for the primary
                  // action at the bottom of a screen and wrong for a pair
                  // of buttons in a row. Height still meets NFR-A-05's
                  // 48 dp; only the width default is overridden.
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, NourishlyTarget.minTouch),
                  ),
                  onPressed: () {
                    _snooze(ref);
                    context.push('/profile/data');
                  },
                  child: const Text('Export'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// A month, whichever button was pressed. "Not now" and "done" both mean
  /// "stop asking for a while" — a prompt that returns tomorrow because
  /// the user dismissed rather than acted is the definition of nagging.
  Future<void> _snooze(WidgetRef ref) async {
    final ownerId = await ref.read(defaultOwnerProvider.future);
    await ref
        .read(preferencesDaoProvider)
        .update(
          ownerId,
          exportPromptSnoozedUntil: ref
              .read(clockProvider)
              .now()
              .add(const Duration(days: 30)),
        );
    ref.read(summaryRevisionProvider.notifier).bump();
  }
}
