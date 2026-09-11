import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/nourishly_theme.dart';
import '../tokens.g.dart';

/// The vessel that fills as you drink — the "fill visual" the design
/// decision picked over a glass grid, because it reads proportion best.
///
/// The proportions are the prototype's `.wfill-b`: a 106x132 tumbler,
/// squarer at the lip than at the base, filled with `--accent` at 85% over
/// `--surface-2`. The earlier cut painted `accentSoft` over `track`, two
/// tokens four hex values apart — the fill was there, and invisible.
class WaterVessel extends StatefulWidget {
  const WaterVessel({super.key, required this.totalMl, required this.goalMl});

  final double totalMl;
  final double goalMl;

  @override
  State<WaterVessel> createState() => WaterVesselState();
}

/// Public only so a test can reach the vessel's animation state; nothing
/// outside this file drives it.
class WaterVesselState extends State<WaterVessel>
    with TickerProviderStateMixin {
  /// Long enough to read as pouring, short enough not to be in the way of
  /// a second quick-add.
  static const Duration riseDuration = Duration(milliseconds: 900);

  /// The surface keeps moving after the level settles, then stills. It
  /// damps to nothing rather than looping forever: an endless animation
  /// burns a phone's battery on a screen people leave open, and it never
  /// lets a test settle.
  static const Duration rippleDuration = Duration(milliseconds: 2200);

  late final AnimationController _rise = AnimationController(
    vsync: this,
    duration: riseDuration,
  );
  late final AnimationController _ripple = AnimationController(
    vsync: this,
    duration: rippleDuration,
  );

  Animation<double> _level = const AlwaysStoppedAnimation(0.0);
  Animation<double> _volume = const AlwaysStoppedAnimation(0.0);
  double _shownMl = 0;

  double get _fraction =>
      widget.goalMl <= 0 ? 0 : (widget.totalMl / widget.goalMl).clamp(0.0, 1.0);

  @override
  void initState() {
    super.initState();
    // The vessel fills from empty the first time it is shown, too — the
    // day's total arriving is itself worth watching pour in.
    _animateTo();
  }

  @override
  void didUpdateWidget(WaterVessel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.totalMl == widget.totalMl &&
        oldWidget.goalMl == widget.goalMl) {
      return;
    }
    _animateTo();
  }

  void _animateTo() {
    final fromLevel = _level.value;
    final fromMl = _shownMl;
    _level = Tween<double>(
      begin: fromLevel,
      end: _fraction,
    ).animate(CurvedAnimation(parent: _rise, curve: Curves.easeOutCubic));
    _volume = Tween<double>(
      begin: fromMl,
      end: widget.totalMl,
    ).animate(CurvedAnimation(parent: _rise, curve: Curves.easeOutCubic));
    _shownMl = widget.totalMl;
    _rise.forward(from: 0);
    _ripple.forward(from: 0);
  }

  @override
  void dispose() {
    _rise.dispose();
    _ripple.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;

    return Semantics(
      // The painted level is decoration; the numbers are the content.
      label:
          '${widget.totalMl.toStringAsFixed(0)} millilitres of '
          '${widget.goalMl.toStringAsFixed(0)}',
      child: ExcludeSemantics(
        child: SizedBox(
          width: 106,
          height: 132,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface2,
              borderRadius: vesselRadius,
              border: Border.all(color: colors.lineStrong, width: 2),
            ),
            child: ClipRRect(
              // Inset by the border so the water never paints over the rim.
              borderRadius: vesselRadius.subtract(
                const BorderRadius.all(Radius.circular(2)),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_rise, _ripple]),
                      builder: (context, child) => CustomPaint(
                        painter: WaterVesselPainter(
                          level: _level.value,
                          ripple: _ripple.value,
                          color: colors.accent,
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedBuilder(
                          animation: _volume,
                          builder: (context, child) => Text(
                            (_volume.value / 1000).toStringAsFixed(2),
                            style: text.numeral.copyWith(color: colors.ink),
                          ),
                        ),
                        const SizedBox(height: NourishlySpace.s1),
                        Text(
                          'of ${(widget.goalMl / 1000).toStringAsFixed(1)} L',
                          style: text.caption.copyWith(color: colors.ink2),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// A tumbler, not a rounded rectangle: the prototype's
  /// `border-radius:10px 10px 18px 18px`.
  static const BorderRadius vesselRadius = BorderRadius.only(
    topLeft: Radius.circular(10),
    topRight: Radius.circular(10),
    bottomLeft: Radius.circular(18),
    bottomRight: Radius.circular(18),
  );
}

/// Paints the body of water and the two waves on its surface.
@visibleForTesting
class WaterVesselPainter extends CustomPainter {
  const WaterVesselPainter({
    required this.level,
    required this.ripple,
    required this.color,
  });

  /// 0..1 of the vessel's height.
  final double level;

  /// 0..1 through one ripple; the wave damps to flat as it approaches 1.
  final double ripple;

  final Color color;

  /// How tall the crests are at the moment of the pour.
  static const double maxAmplitude = 7;

  /// Crests across the width. Two is enough to read as water and few
  /// enough not to look like a graph.
  static const double waves = 2;

  @override
  void paint(Canvas canvas, Size size) {
    if (level <= 0) return;

    // Damped so the surface stills; squared so it calms quickly and then
    // lingers, the way water does.
    final damping = ripple >= 1 ? 0.0 : (1 - ripple) * (1 - ripple);
    final amplitude = maxAmplitude * damping;
    final surfaceY = size.height * (1 - level);

    // The far wave trails the near one, which is what makes it read as a
    // surface rather than a line.
    _paintWave(
      canvas,
      size,
      surfaceY: surfaceY,
      amplitude: amplitude * 0.7,
      phase: ripple * 2 * math.pi * 2 + math.pi * 0.9,
      paint: Paint()..color = color.withValues(alpha: 0.45),
    );
    _paintWave(
      canvas,
      size,
      surfaceY: surfaceY,
      amplitude: amplitude,
      phase: ripple * 2 * math.pi * 3,
      paint: Paint()..color = color.withValues(alpha: 0.85),
    );
  }

  void _paintWave(
    Canvas canvas,
    Size size, {
    required double surfaceY,
    required double amplitude,
    required double phase,
    required Paint paint,
  }) {
    final path = Path()..moveTo(0, size.height);
    // A crest above a full vessel would clip flat, so the surface is held
    // inside the walls; at 100% the wave flattens against the rim.
    final clampedY = surfaceY.clamp(amplitude, size.height);
    if (amplitude <= 0) {
      path
        ..lineTo(0, clampedY)
        ..lineTo(size.width, clampedY);
    } else {
      path.lineTo(0, clampedY);
      const steps = 24;
      for (var i = 0; i <= steps; i++) {
        final x = size.width * i / steps;
        final y =
            clampedY +
            amplitude * math.sin(2 * math.pi * waves * i / steps + phase);
        path.lineTo(x, y);
      }
    }
    path
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(WaterVesselPainter oldDelegate) =>
      oldDelegate.level != level ||
      oldDelegate.ripple != ripple ||
      oldDelegate.color != color;
}
