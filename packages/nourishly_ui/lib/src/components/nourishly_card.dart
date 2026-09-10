import 'package:flutter/material.dart';

import '../theme/nourishly_theme.dart';
import '../tokens.g.dart';

/// The prototype's `.card` — a hairline-bordered surface panel. Every
/// grouped block on a screen sits in one of these.
class NourishlyCard extends StatelessWidget {
  const NourishlyCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(NourishlySpace.s4),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(NourishlyRadius.lg),
      side: BorderSide(color: colors.line, width: NourishlyStroke.hairline),
    );

    // The surface is a Material, not a DecoratedBox, so that interactive
    // children inside the card (list tiles, ink wells) have a Material
    // ancestor to paint their splashes onto — a coloured DecoratedBox in
    // between would hide them.
    return Material(
      color: colors.surface,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? Padding(padding: padding, child: child)
          : InkWell(
              onTap: onTap,
              child: Padding(padding: padding, child: child),
            ),
    );
  }
}

/// The prototype's `.sec-h` — a small uppercase section label, optionally
/// with a trailing action.
class NourishlySectionHeader extends StatelessWidget {
  const NourishlySectionHeader({
    super.key,
    required this.label,
    this.actionLabel,
    this.onActionPressed,
  });

  final String label;
  final String? actionLabel;
  final VoidCallback? onActionPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    return Padding(
      padding: const EdgeInsets.only(
        top: NourishlySpace.s5,
        bottom: NourishlySpace.s2,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label.toUpperCase(),
            style: text.overline.copyWith(color: colors.ink3),
          ),
          if (actionLabel != null)
            GestureDetector(
              onTap: onActionPressed,
              child: Text(
                actionLabel!,
                style: text.caption.copyWith(
                  color: colors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
