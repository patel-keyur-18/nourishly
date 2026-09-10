import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/nourishly_colors.dart';
import '../theme/nourishly_theme.dart';
import '../tokens.g.dart';

/// The dashboard's hero energy ring (prototype screen 3, option A).
///
/// Shows consumed energy against a target, with the *remaining* figure as
/// the large number (UX-3: energy shows remaining, not consumed). The tick
/// mark sits at 100% of target while the track runs to 125%, so overshoot
/// has somewhere to go (§27.11) rather than pinning at a full ring.
class EnergyRing extends StatelessWidget {
  const EnergyRing({
    super.key,
    required this.consumed,
    required this.target,
    this.size = 118,
  });

  final double consumed;
  final double target;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    final remaining = (target - consumed).round();

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _RingPainter(
              progress: target <= 0 ? 0 : consumed / target,
              colors: colors,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${remaining.abs()}',
                style: text.numeral.copyWith(height: 1),
              ),
              const SizedBox(height: 2),
              Text(
                remaining >= 0 ? 'kcal left' : 'kcal over',
                style: text.caption.copyWith(color: colors.ink3, height: 1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress, required this.colors});

  /// Consumed / target. May exceed 1.0 — the track runs to 125%.
  final double progress;
  final NourishlyColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final radius = (size.shortestSide - NourishlyStroke.ring) / 2;
    final rect = Rect.fromCircle(center: centre, radius: radius);
    // The full sweep represents 125% of target, so 100% lands short of a
    // closed ring and overshoot stays visible rather than saturating.
    const fullSweep = 2 * math.pi;
    final scale = 1 / NourishlyChart.trackToTargetRatio;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = NourishlyStroke.ring
      ..color = colors.track;
    canvas.drawCircle(centre, radius, track);

    final filled = progress.clamp(0.0, NourishlyChart.trackToTargetRatio);
    if (filled > 0) {
      final fill = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = NourishlyStroke.ring
        ..strokeCap = StrokeCap.round
        ..color = progress > 1 ? colors.statusHigh : colors.accent;
      canvas.drawArc(rect, -math.pi / 2, fullSweep * filled * scale, false, fill);
    }

    // The tick at 100% of target: what the ring is read against (§27.11).
    final tickAngle = -math.pi / 2 + fullSweep * scale;
    final inner = radius - NourishlyStroke.ring / 2 - 2;
    final outer = radius + NourishlyStroke.ring / 2 + 3;
    final tick = Paint()
      ..strokeWidth = NourishlyStroke.tick
      ..strokeCap = StrokeCap.round
      ..color = colors.ink2;
    canvas.drawLine(
      centre + Offset(math.cos(tickAngle), math.sin(tickAngle)) * inner,
      centre + Offset(math.cos(tickAngle), math.sin(tickAngle)) * outer,
      tick,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.colors != colors;
}
