import 'package:flutter/material.dart';

import '../theme/nourishly_theme.dart';
import '../theme/nourishly_typography.dart';
import '../tokens.g.dart';

/// One destination in [NourishlyBottomNav].
@immutable
class NourishlyBottomNavItem {
  const NourishlyBottomNavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// The four-tab-plus-centre-action navigation bar from prototype screen 3
/// (§28.1). The centre action is not a destination — it opens the logging
/// flow modally (§28.4) — so it takes its own [onFabPressed] callback
/// rather than participating in [currentIndex].
class NourishlyBottomNav extends StatelessWidget {
  const NourishlyBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.onFabPressed,
  }) : assert(
         items.length == 4,
         'The prototype nav bar always carries exactly four destinations '
         '(Today, Insights, Water, Profile) around the centre action.',
       );

  /// The bar's own height at normal text size, excluding the bottom
  /// safe-area inset.
  ///
  /// This is a fixed base deliberately. `Scaffold` lays its
  /// `bottomNavigationBar` out with *loose* constraints whose maxHeight is
  /// the whole screen, so any unbounded-height child here (an
  /// `Align`/`Center`, a `Spacer`) silently expands to fill the screen,
  /// collapsing the body to nothing.
  static const double barHeight = 64;

  /// How far the labels are allowed to grow with the OS text setting
  /// (NFR-A-03).
  ///
  /// Capped rather than uncapped, and both platforms do the same for their
  /// own tab bars. A doubled tab label either overflows a bar sized for
  /// the screen or takes a third of the screen for five words that are
  /// already carried by their icons. The cap is generous enough to help
  /// and small enough that the bar stays a bar — and nothing is truncated
  /// or lost, which is what the requirement actually protects.
  static const double maxLabelScale = 1.3;

  /// The bar's height at the current text setting, so the destinations
  /// have somewhere to grow into rather than overflowing a fixed box.
  static double heightFor(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context)
        .scale(1)
        .clamp(1.0, maxLabelScale);
    return barHeight + (scale - 1) * 20;
  }

  final List<NourishlyBottomNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onFabPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.line, width: NourishlyStroke.hairline),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: heightFor(context),
          child: Row(
            // Stretch, so each destination's tappable area is the full
            // height of the bar rather than just the icon and its label.
            // With the default centre alignment the children got loose
            // constraints and each `InkWell` shrank to its content — a
            // 78 × 36 target for the app's primary navigation, under
            // NFR-A-05's 48 dp minimum. Nothing moves visually; the
            // column inside is still centred.
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _destination(context, 0),
              _destination(context, 1),
              _FabSlot(onPressed: onFabPressed),
              _destination(context, 2),
              _destination(context, 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _destination(BuildContext context, int index) {
    final item = items[index];
    final colors = context.nourishlyColors;
    final selected = index == currentIndex;
    final color = selected ? colors.accent : colors.ink3;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onDestinationSelected(index),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.icon, size: 22, color: color),
              const SizedBox(height: 3),
              // The cap lives here rather than on the whole bar so that
              // anything else in it keeps the user's own setting.
              MediaQuery.withClampedTextScaling(
                maxScaleFactor: maxLabelScale,
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: NourishlyTypography.forInk(color).overline
                      .copyWith(letterSpacing: 0, height: 1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FabSlot extends StatelessWidget {
  const _FabSlot({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    return Expanded(
      child: Semantics(
        button: true,
        label: 'Log food or water',
        child: Material(
          color: colors.accent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            // The minimum touch target *is* the size here: the action was
            // 46 square, which is below NFR-A-05's floor for the most
            // frequently tapped control in the app.
            child: SizedBox(
              width: NourishlyTarget.minTouch,
              height: NourishlyTarget.minTouch,
              child: Icon(Icons.add_rounded, color: colors.accentInk, size: 24),
            ),
          ),
        ),
      ),
    );
  }
}
