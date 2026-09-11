import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/nourishly_theme.dart';
import '../tokens.g.dart';

/// One day in a [DayBarChart].
@immutable
class DayBar {
  const DayBar({required this.label, this.value, this.semanticLabel});

  /// The single letter under the bar: M, T, W…
  final String label;

  /// Null when nothing was logged. Not zero — §27.11 leaves an unlogged
  /// day visibly unlogged rather than drawing it as a day of nothing.
  final double? value;

  /// What a screen reader hears for this day. The conclusion, not the
  /// coordinate: "Monday, 1,720 kcal, under the 2,050 target".
  final String? semanticLabel;

  bool get wasLogged => value != null;
}

/// Vertical bars against a horizontal target line — §27.11's choice for a
/// week of energy, because the comparison of interest is day-to-target.
///
/// The axis runs past the target (`NourishlyChart.trackToTargetRatio`) so
/// a day over target has somewhere to go instead of pinning at the top,
/// and so the target line sits inside the plot rather than on its edge.
class DayBarChart extends StatelessWidget {
  const DayBarChart({
    super.key,
    required this.bars,
    this.target,
    this.height = 88,
    this.semanticsLabel,
  });

  final List<DayBar> bars;

  /// Draws the dashed line, and sets the axis. Null leaves the chart
  /// scaled to its own data with no line.
  final double? target;

  final double height;

  /// The chart's own text alternative — the conclusion of the whole chart,
  /// with each bar readable underneath it.
  final String? semanticsLabel;

  double get _axisMax {
    final values = [for (final bar in bars) ?bar.value];
    final largest = values.isEmpty ? 0.0 : values.reduce(math.max);
    final fromTarget = (target ?? 0) * NourishlyChart.trackToTargetRatio;
    final max = math.max(largest, fromTarget);
    // An all-zero week would divide by zero; one is as good as any.
    return max <= 0 ? 1 : max;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    final axisMax = _axisMax;

    return Semantics(
      label: semanticsLabel,
      container: semanticsLabel != null,
      // The chart states its own conclusion, and each bar stays reachable
      // underneath it rather than being merged into one long string.
      explicitChildNodes: true,
      child: SizedBox(
        height: height + 16,
        child: Stack(
          children: [
            Positioned.fill(
              bottom: 16,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < bars.length; i++) ...[
                    if (i > 0) const SizedBox(width: 7),
                    Expanded(
                      child: _Bar(
                        bar: bars[i],
                        fraction: (bars[i].value ?? 0) / axisMax,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (target != null)
              Positioned(
                left: 0,
                right: 0,
                // Measured from the top of the plot area.
                top: height * (1 - target! / axisMax),
                child: ExcludeSemantics(
                  child: CustomPaint(
                    painter: _DashedLinePainter(color: colors.ink3),
                    size: const Size.fromHeight(1.5),
                  ),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ExcludeSemantics(
                child: Row(
                  children: [
                    for (var i = 0; i < bars.length; i++) ...[
                      if (i > 0) const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          bars[i].label,
                          textAlign: TextAlign.center,
                          style: text.caption.copyWith(
                            fontSize: 10,
                            color: colors.ink3,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.bar, required this.fraction});

  final DayBar bar;
  final double fraction;

  /// An unlogged day still gets a visible stub, so the day is present in
  /// the chart as a day rather than vanishing into the axis.
  static const double _unloggedFraction = 0.04;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    return Semantics(
      label: bar.semanticLabel,
      child: FractionallySizedBox(
        alignment: Alignment.bottomCenter,
        heightFactor: bar.wasLogged
            ? fraction.clamp(0.02, 1.0)
            : _unloggedFraction,
        child: DecoratedBox(
          decoration: BoxDecoration(
            // Never colour alone (NFR-A-04): the unlogged bar is a
            // different height as well as a different colour, and it
            // carries its own label.
            color: bar.wasLogged ? colors.accent : colors.track,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..strokeWidth = 1.5;
    const dash = 4.0;
    const gap = 4.0;
    for (var x = 0.0; x < size.width; x += dash + gap) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(math.min(x + dash, size.width), 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// A line over time, with the unlogged days left as gaps.
///
/// §27.11: interpolating across a missing day invents data, so a run of
/// scores is drawn as its own segment and the gap between runs stays
/// empty. A single scored day surrounded by gaps is drawn as a point,
/// because a one-point line is invisible.
class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.values,
    this.smoothed,
    this.height = 64,
    this.minimum,
    this.maximum,
    this.minimumSpan = 0,
    this.semanticsLabel,
  });

  /// One entry per day, null where there is nothing to plot.
  final List<double?> values;

  /// An optional second line — §27.11's moving average under a noisy
  /// monthly series. Drawn without the area fill or the end dot.
  final List<double?>? smoothed;

  final double height;

  /// Fix the axis rather than scaling to the data. Handy when two
  /// sparklines are read against each other.
  final double? minimum;
  final double? maximum;

  /// The narrowest range the axis will scale to.
  ///
  /// Without it, a month whose scores run 86 to 88 is drawn as a mountain
  /// range: auto-scaling amplifies two points of noise into the full
  /// height of the card, which is a chart that lies about its own data.
  final double minimumSpan;

  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    return Semantics(
      label: semanticsLabel,
      image: semanticsLabel != null,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: SparklinePainter(
            values: values,
            smoothed: smoothed,
            line: colors.accent,
            fill: colors.accentSoft,
            dotBorder: colors.surface,
            minimum: minimum,
            maximum: maximum,
            minimumSpan: minimumSpan,
          ),
        ),
      ),
    );
  }
}

@visibleForTesting
class SparklinePainter extends CustomPainter {
  const SparklinePainter({
    required this.values,
    required this.line,
    required this.fill,
    required this.dotBorder,
    this.smoothed,
    this.minimum,
    this.maximum,
    this.minimumSpan = 0,
  });

  final List<double?> values;
  final List<double?>? smoothed;
  final Color line;
  final Color fill;
  final Color dotBorder;
  final double? minimum;
  final double? maximum;
  final double minimumSpan;

  /// Breathing room above and below the data, as a fraction of its range,
  /// so the highest point is not welded to the top edge.
  static const double _pad = 0.12;

  @override
  void paint(Canvas canvas, Size size) {
    final present = [for (final v in values) ?v];
    if (present.isEmpty || values.length < 2) return;

    var low = minimum ?? present.reduce(math.min);
    var high = maximum ?? present.reduce(math.max);
    if (high - low < 1e-9) {
      // A flat series would divide by zero; give it a band to sit in the
      // middle of rather than a line at the top.
      low -= 1;
      high += 1;
    } else {
      final pad = (high - low) * _pad;
      if (minimum == null) low -= pad;
      if (maximum == null) high += pad;
    }

    // Widen a narrow range around its own midpoint rather than letting the
    // axis magnify a couple of points of noise.
    if (high - low < minimumSpan) {
      final middle = (high + low) / 2;
      low = middle - minimumSpan / 2;
      high = middle + minimumSpan / 2;
    }

    Offset at(int index, double value) => Offset(
      values.length == 1 ? 0 : size.width * index / (values.length - 1),
      size.height * (1 - (value - low) / (high - low)),
    );

    final runs = _runs(values);

    // With a smoothed series present, that is the line: §27.11 calls the
    // moving average the signal and the raw daily values the noise, so the
    // raw series drops back to a faint trace behind it and the fill and
    // the end dot follow the smoothed line. Without one, the raw series is
    // all there is and carries both.
    final leadRuns = smoothed == null ? runs : _runs(smoothed!);

    final fillPaint = Paint()..color = fill;
    for (final run in leadRuns) {
      if (run.length < 2) continue;
      final path = Path()
        ..moveTo(at(run.first.$1, run.first.$2).dx, size.height);
      for (final (index, value) in run) {
        final point = at(index, value);
        path.lineTo(point.dx, point.dy);
      }
      path
        ..lineTo(at(run.last.$1, run.last.$2).dx, size.height)
        ..close();
      canvas.drawPath(path, fillPaint);
    }

    if (smoothed != null) {
      _strokeRuns(
        canvas,
        runs,
        at,
        Paint()
          ..color = line.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    _strokeRuns(
      canvas,
      leadRuns,
      at,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // The last point plotted, marked so the eye lands on where the series
    // actually ends rather than on the right edge of the box.
    final last = leadRuns.isEmpty ? null : leadRuns.last.last;
    if (last != null) {
      final point = at(last.$1, last.$2);
      canvas.drawCircle(point, 3.5, Paint()..color = line);
      canvas.drawCircle(
        point,
        3.5,
        Paint()
          ..color = dotBorder
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  void _strokeRuns(
    Canvas canvas,
    List<List<(int, double)>> runs,
    Offset Function(int, double) at,
    Paint paint,
  ) {
    for (final run in runs) {
      if (run.length == 1) {
        // One scored day between two gaps: a line of one point draws
        // nothing, so draw the point.
        canvas.drawCircle(
          at(run.first.$1, run.first.$2),
          paint.strokeWidth / 2 + 0.5,
          Paint()..color = paint.color,
        );
        continue;
      }
      final path = Path();
      for (var i = 0; i < run.length; i++) {
        final point = at(run[i].$1, run[i].$2);
        i == 0
            ? path.moveTo(point.dx, point.dy)
            : path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  /// Contiguous stretches of non-null values, each as (index, value).
  ///
  /// This is where §27.11's "gaps stay gaps" actually happens: each run is
  /// stroked as its own path, so nothing is ever drawn across a day that
  /// was not logged.
  @visibleForTesting
  static List<List<(int, double)>> runsIn(List<double?> series) =>
      _runs(series);

  static List<List<(int, double)>> _runs(List<double?> series) {
    final runs = <List<(int, double)>>[];
    var current = <(int, double)>[];
    for (var i = 0; i < series.length; i++) {
      final value = series[i];
      if (value == null) {
        if (current.isNotEmpty) runs.add(current);
        current = [];
      } else {
        current.add((i, value));
      }
    }
    if (current.isNotEmpty) runs.add(current);
    return runs;
  }

  @override
  bool shouldRepaint(SparklinePainter oldDelegate) =>
      !_sameSeries(oldDelegate.values, values) ||
      !_sameSeries(oldDelegate.smoothed, smoothed) ||
      oldDelegate.line != line ||
      oldDelegate.fill != fill ||
      oldDelegate.minimum != minimum ||
      oldDelegate.maximum != maximum ||
      oldDelegate.minimumSpan != minimumSpan;

  static bool _sameSeries(List<double?>? a, List<double?>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null || a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// How completely each day of a period was logged, one cell per day.
///
/// §27.11 asks for a strip rather than a streak counter: it shows the
/// denominator (UX-4) without the punitive framing a broken streak carries
/// (§21.8).
class ConsistencyStrip extends StatelessWidget {
  const ConsistencyStrip({
    super.key,
    required this.cells,
    this.labels,
    this.semanticsLabel,
  });

  /// One per day.
  final List<ConsistencyCell> cells;

  /// Optional single letters under the cells.
  final List<String>? labels;

  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;

    Color colorOf(ConsistencyCell cell) => switch (cell) {
      ConsistencyCell.logged => colors.accent,
      ConsistencyCell.partial => colors.accentSoft,
      ConsistencyCell.none => colors.track,
    };

    return Semantics(
      label: semanticsLabel,
      container: semanticsLabel != null,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                for (var i = 0; i < cells.length; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: colorOf(cells[i]),
                        borderRadius: BorderRadius.circular(3),
                        // A partial day is outlined as well as tinted, so
                        // it is distinguishable without colour.
                        border: cells[i] == ConsistencyCell.partial
                            ? Border.all(
                                color: colors.accent,
                                width: NourishlyStroke.hairline,
                              )
                            : null,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (labels != null) ...[
              const SizedBox(height: NourishlySpace.s1),
              Row(
                children: [
                  for (var i = 0; i < labels!.length; i++) ...[
                    if (i > 0) const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        labels![i],
                        textAlign: TextAlign.center,
                        style: text.caption.copyWith(
                          fontSize: 10,
                          color: colors.ink3,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// What one cell of a [ConsistencyStrip] says about its day.
enum ConsistencyCell {
  /// Logged, and looks like a whole day.
  logged,

  /// Logged, but flagged as looking incomplete, or still running.
  partial,

  /// Nothing at all.
  none,
}

/// One meal slot's row in a [MealConsistencyGrid].
@immutable
class MealRow {
  const MealRow({required this.label, required this.logged});

  /// "Breakfast", "Lunch"…
  final String label;

  /// One per day of the period, in the same order as the day labels.
  final List<bool> logged;
}

/// Which days *and which meals* were logged (§27.9), as a grid: one row
/// per meal slot, one column per day.
///
/// A day strip alone answers "did I log on Tuesday". This answers the more
/// useful question — which meal is the one that keeps getting missed —
/// and it is the same denominator framing rather than a streak (§21.8).
class MealConsistencyGrid extends StatelessWidget {
  const MealConsistencyGrid({
    super.key,
    required this.meals,
    required this.dayLabels,
    this.semanticsLabel,
  });

  final List<MealRow> meals;
  final List<String> dayLabels;
  final String? semanticsLabel;

  /// Wide enough for "Breakfast" at caption size without wrapping, and
  /// narrow enough to leave the grid the rest of a phone's width.
  static const double _labelWidth = 66;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;

    Widget cellRow(List<Widget> cells) => Row(
      children: [
        for (var i = 0; i < cells.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(child: cells[i]),
        ],
      ],
    );

    return Semantics(
      label: semanticsLabel,
      container: semanticsLabel != null,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(width: _labelWidth),
                Expanded(
                  child: cellRow([
                    for (final label in dayLabels)
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: text.caption.copyWith(
                          fontSize: 10,
                          color: colors.ink3,
                        ),
                      ),
                  ]),
                ),
              ],
            ),
            const SizedBox(height: NourishlySpace.s1),
            for (var m = 0; m < meals.length; m++) ...[
              if (m > 0) const SizedBox(height: 4),
              Row(
                children: [
                  SizedBox(
                    width: _labelWidth,
                    child: Text(
                      meals[m].label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.caption.copyWith(
                        fontSize: 10.5,
                        color: colors.ink2,
                      ),
                    ),
                  ),
                  Expanded(
                    child: cellRow([
                      for (final logged in meals[m].logged)
                        Container(
                          height: 10,
                          decoration: BoxDecoration(
                            color: logged ? colors.accent : colors.track,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                    ]),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
