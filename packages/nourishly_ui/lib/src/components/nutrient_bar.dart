import 'package:flutter/material.dart';

import '../theme/nourishly_colors.dart';
import '../theme/nourishly_theme.dart';
import '../theme/nourishly_typography.dart';
import '../tokens.g.dart';

/// One `.brow` from the prototype: a named nutrient, a track with the fill
/// and the 100%-of-target tick, and the value.
///
/// The track runs to 125% of target (§27.11) and the tick marks 100%, so a
/// bar is read *against a target* rather than filled to an edge — and
/// overshoot has somewhere to go instead of pinning full.
///
/// [planned] draws the week planner's forecast: a hatched segment
/// continuing from the solid fill, showing where the day lands if the rest
/// of the plan is eaten. Hatched rather than merely paler, because a
/// second shade of the same colour is colour carrying meaning on its own
/// (NFR-A-04) — the texture, the value text and the screen-reader label
/// all say the same thing independently.
class NutrientBar extends StatelessWidget {
  const NutrientBar({
    super.key,
    required this.name,
    required this.value,
    required this.target,
    required this.color,
    this.unit = 'g',
    this.planned = 0,
  });

  final String name;
  final double value;
  final double target;
  final Color color;
  final String unit;

  /// Additional amount that is planned but not yet eaten. Zero everywhere
  /// outside the planner.
  final double planned;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    final fraction = target <= 0
        ? 0.0
        : (value / target / NourishlyChart.trackToTargetRatio).clamp(0.0, 1.0);
    const tickFraction = 1 / NourishlyChart.trackToTargetRatio;

    // NFR-A-02's worked example, almost word for word: "Protein: 82 g of
    // 95 g target, 86%" — not "bar at 86%". The percentage is the
    // conclusion a sighted reader draws from where the fill sits relative
    // to the tick, so it is stated rather than left to be inferred from a
    // shape nobody can see.
    final percent = target <= 0 ? null : (value / target * 100).round();
    final plannedFraction = target <= 0 || planned <= 0
        ? 0.0
        : (planned / target / NourishlyChart.trackToTargetRatio).clamp(
            0.0,
            1.0 - fraction,
          );
    final projectedPercent = target <= 0
        ? null
        : ((value + planned) / target * 100).round();

    final base = percent == null
        ? '$name: ${_round(value)} $unit, no target set'
        : '$name: ${_round(value)} $unit of ${_round(target)} $unit '
              'target, $percent per cent';
    final projected = projectedPercent == null
        ? ''
        : ', $projectedPercent per cent';
    return Semantics(
      label: planned <= 0
          ? base
          : '$base. Planned but not yet eaten: ${_round(planned)} $unit, '
                'reaching ${_round(value + planned)} $unit$projected',
      excludeSemantics: true,
      child: _bar(
        context,
        colors,
        text,
        fraction,
        plannedFraction,
        tickFraction,
      ),
    );
  }

  static String _round(double value) =>
      value >= 10 ? value.round().toString() : value.toStringAsFixed(1);

  Widget _bar(
    BuildContext context,
    NourishlyColors colors,
    NourishlyTypography text,
    double fraction,
    double plannedFraction,
    double tickFraction,
  ) {
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
                      if (plannedFraction > 0)
                        Positioned(
                          left: constraints.maxWidth * fraction,
                          width: constraints.maxWidth * plannedFraction,
                          top: 0,
                          bottom: 0,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              NourishlyStroke.bar,
                            ),
                            child: CustomPaint(
                              painter: _PlannedHatchPainter(color: color),
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

  /// Whole grams past 10, one decimal below it. The prototype writes
  /// "198/240g", not "203.8/321.6g": a decigram of carbohydrate is not a
  /// distinction anyone acts on, and the extra characters wrap the value
  /// onto a second line at phone width.
  static String _format(double v) {
    if (v < 10) return v.toStringAsFixed(1);
    final rounded = v.round();
    if (rounded < 1000) return '$rounded';
    return '${rounded ~/ 1000},'
        '${(rounded % 1000).toString().padLeft(3, '0')}';
  }
}

/// The planned segment's diagonal hatch.
///
/// Drawn rather than tinted so the distinction survives greyscale, a
/// screenshot, and colour-blindness — the same reason every status in this
/// app is a dot *and* a word.
class _PlannedHatchPainter extends CustomPainter {
  const _PlannedHatchPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = color.withValues(alpha: 0.16),
    );
    final stroke = Paint()
      ..color = color.withValues(alpha: 0.75)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.butt;
    // Diagonals at 45 degrees, stepping by the bar's own height so the
    // spacing reads the same however long the segment is.
    const step = 4.0;
    for (var x = -size.height; x < size.width + size.height; x += step) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        stroke,
      );
    }
  }

  @override
  bool shouldRepaint(_PlannedHatchPainter oldDelegate) =>
      oldDelegate.color != color;
}
