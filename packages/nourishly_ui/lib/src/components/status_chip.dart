import 'package:flutter/material.dart';

import '../theme/nourishly_theme.dart';
import '../tokens.g.dart';

/// Which status a [StatusChip] reports. Over-target uses [high] (violet),
/// never danger red — a food tracker must not scold (§21.8).
enum NourishlyStatus { ok, low, high, unknown, score }

/// The prototype's `.chip` — a status dot plus a label.
///
/// The dot is never the only signal: every chip carries a written label
/// too, because colour alone must not encode meaning (NFR-A-04).
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.status});

  final String label;
  final NourishlyStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    final dotColor = switch (status) {
      NourishlyStatus.ok => colors.statusOk,
      NourishlyStatus.low => colors.statusLow,
      NourishlyStatus.high => colors.statusHigh,
      NourishlyStatus.unknown => colors.statusUnknown,
      NourishlyStatus.score => colors.accent,
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(NourishlyRadius.pill),
        border: Border.all(color: colors.line, width: NourishlyStroke.hairline),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: NourishlySpace.s3,
          vertical: NourishlySpace.s1 + 2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: NourishlySpace.s2),
            // Flexible so a long label ellipsises rather than overflowing
            // whatever row the chip has been dropped into.
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.caption.copyWith(
                  color: colors.ink2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The prototype's `.qb` — a quick-add pill (e.g. `+250 ml`).
class QuickAddButton extends StatelessWidget {
  const QuickAddButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.emphasised = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    return Material(
      color: emphasised ? colors.accent : colors.surface2,
      borderRadius: BorderRadius.circular(NourishlyRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(NourishlyRadius.pill),
        onTap: onPressed,
        child: Container(
          height: NourishlyTarget.minTouchCompact,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: NourishlySpace.s3),
          child: Text(
            label,
            style: text.label.copyWith(
              color: emphasised ? colors.accentInk : colors.accentSoftInk,
            ),
          ),
        ),
      ),
    );
  }
}
