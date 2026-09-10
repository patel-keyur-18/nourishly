import 'package:flutter/material.dart';

import '../theme/nourishly_theme.dart';
import '../theme/nourishly_typography.dart';
import '../tokens.g.dart';

/// One destination in [NourishlyBottomNav].
@immutable
class NourishlyBottomNavItem {
  const NourishlyBottomNavItem({required this.icon, required this.label});

  // Material icons stand in for the prototype's hand-drawn stroke icons
  // (clock, ascending bars, droplet, person) until the design system gets
  // custom-painted equivalents — a fidelity gap worth closing later, not
  // in Phase 1 scaffolding.
  final IconData icon;
  final String label;
}

/// The four-tab-plus-centre-action navigation bar from prototype screen 3
/// (§28.1): "Bottom tab navigation with four tabs and a prominent central
/// log action, dashboard-first." The centre action is not a destination —
/// it opens the logging flow modally (§28.4) — so it takes its own
/// [onFabPressed] callback rather than participating in [currentIndex].
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
         'around the centre action (Today, Insights, Water, Profile).',
       );

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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            NourishlySpace.s1,
            NourishlySpace.s1,
            NourishlySpace.s1,
            NourishlySpace.s2,
          ),
          child: Row(
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
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: NourishlySpace.s1),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(item.icon, size: 20, color: color),
                const SizedBox(height: 3),
                Text(
                  item.label,
                  style: NourishlyTypography.forInk(color).overline
                      .copyWith(letterSpacing: 0, height: 1),
                ),
              ],
            ),
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
      child: Center(
        child: Semantics(
          button: true,
          label: 'Log food or water',
          child: Material(
            color: colors.accent,
            shape: const CircleBorder(),
            elevation: 0,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(
                  Icons.add_rounded,
                  color: colors.accentInk,
                  size: 22,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
