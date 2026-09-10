import 'package:flutter/material.dart';

import '../theme/nourishly_theme.dart';
import '../tokens.g.dart';

/// One `.brow` from the prototype: a named nutrient, a track with the fill
/// and the 100%-of-target tick, and the value.
///
/// The track runs to 125% of target (§27.11) and the tick marks 100%, so a
/// bar is read *against a target* rather than filled to an edge — and
/// overshoot has somewhere to go instead of pinning full.
class NutrientBar extends StatelessWidget {
  const NutrientBar({
    super.key,
    required this.name,
    required this.value,
    required this.target,
    required this.color,
    this.unit = 'g',
  });

  final String name;
  final double value;
  final double target;
  final Color color;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    final fraction = target <= 0
        ? 0.0
        : (value / target / NourishlyChart.trackToTargetRatio).clamp(0.0, 1.0);
    const tickFraction = 1 / NourishlyChart.trackToTargetRatio;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: NourishlySpace.s2),
      child: Row(
        children: [
          SizedBox(
            width: 58,
            child: Text(name, style: text.caption.copyWith(color: colors.ink2)),
          ),
          const SizedBox(width: NourishlySpace.s2),
          Expanded(
            child: SizedBox(
              height: NourishlyStroke.bar,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // StackFit.expand keeps children tightly constrained —
                  // an unbounded child in a bar this small silently takes
                  // whatever space it is offered.
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.track,
                          borderRadius: BorderRadius.circular(
                            NourishlyStroke.bar,
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: fraction,
                          heightFactor: 1,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(
                                NourishlyStroke.bar,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: constraints.maxWidth * tickFraction,
                        top: -2,
                        bottom: -2,
                        child: SizedBox(
                          width: NourishlyStroke.tick,
                          child: DecoratedBox(
                            decoration: BoxDecoration(color: colors.ink2),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: NourishlySpace.s3),
          SizedBox(
            width: 74,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: _format(value),
                    style: text.caption.copyWith(
                      color: colors.ink,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  TextSpan(
                    text: '/${_format(target)}$unit',
                    style: text.caption.copyWith(color: colors.ink3),
                  ),
                ],
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  static String _format(double v) =>
      v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}
