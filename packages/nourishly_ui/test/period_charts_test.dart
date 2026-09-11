import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly_ui/nourishly_ui.dart';

/// §27.11's rules, as tests: gaps stay gaps, an unlogged day is visibly
/// unlogged, and every chart carries a text alternative that states the
/// conclusion rather than the coordinates.
void main() {
  Widget host(Widget child) => MaterialApp(
    theme: NourishlyTheme.light(),
    home: Scaffold(
      body: Center(child: SizedBox(width: 320, child: child)),
    ),
  );

  group('DayBarChart', () {
    testWidgets('an unlogged day is drawn differently, not as a zero', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const DayBarChart(
            bars: [
              DayBar(label: 'M', value: 1800),
              DayBar(label: 'T', value: 1900),
              DayBar(label: 'F'),
            ],
            target: 2050,
          ),
        ),
      );

      final boxes = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((w) => w.decoration as BoxDecoration)
          .toList();
      expect(
        boxes.where((d) => d.color == NourishlyLightColors.accent),
        hasLength(2),
      );
      expect(
        boxes.where((d) => d.color == NourishlyLightColors.track),
        hasLength(1),
        reason: 'the unlogged Friday, in the track shade rather than absent',
      );
    });

    testWidgets('every day keeps its label, logged or not', (tester) async {
      await tester.pumpWidget(
        host(
          const DayBarChart(
            bars: [
              DayBar(label: 'M', value: 1800),
              DayBar(label: 'T'),
              DayBar(label: 'W', value: 2100),
            ],
          ),
        ),
      );
      for (final label in ['M', 'T', 'W']) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('a day over target still fits, with room above the line', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const DayBarChart(
            bars: [DayBar(label: 'M', value: 2400)],
            target: 2050,
          ),
        ),
      );
      final bar = tester.widget<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );
      // The axis runs to 1.25x the target, so 2,400 fills most of it
      // without pinning at the top.
      expect(bar.heightFactor, closeTo(2400 / (2050 * 1.25), 1e-9));
      expect(bar.heightFactor, lessThan(1));
    });

    testWidgets('the chart carries a conclusion, not coordinates', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        host(
          const DayBarChart(
            bars: [
              DayBar(
                label: 'M',
                value: 1800,
                semanticLabel: 'Monday, 1,800 kcal, under the 2,050 target',
              ),
            ],
            target: 2050,
            semanticsLabel: 'Energy per day against a 2,050 kcal target',
          ),
        ),
      );

      expect(
        find.bySemanticsLabel('Energy per day against a 2,050 kcal target'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Monday, 1,800 kcal, under the 2,050 target'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets(
      'a week with nothing in it renders rather than dividing by zero',
      (tester) async {
        await tester.pumpWidget(
          host(
            const DayBarChart(
              bars: [
                DayBar(label: 'M'),
                DayBar(label: 'T'),
              ],
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('Sparkline', () {
    test('a gap splits the line into separate runs', () {
      final runs = SparklinePainter.runsIn(const [68, 72, null, null, 80, 84]);
      expect(runs, hasLength(2));
      expect(runs.first.map((p) => p.$2), [68, 72]);
      expect(runs.last.map((p) => p.$1), [4, 5], reason: 'x stays the day');
    });

    test('a single scored day between gaps is its own run', () {
      final runs = SparklinePainter.runsIn(const [null, 74, null]);
      expect(runs, [
        [(1, 74.0)],
      ]);
    });

    test('a series with no gaps is one run', () {
      expect(SparklinePainter.runsIn(const [1, 2, 3]), hasLength(1));
    });

    testWidgets('a gap in the data does not become a line across it', (
      tester,
    ) async {
      // Drawn as two segments, so nothing is invented between day 2 and
      // day 5. The assertion that matters is that it paints at all with
      // nulls in the middle, and that shouldRepaint sees the difference.
      const withGap = [68.0, 72.0, null, null, 80.0, 84.0];
      const filledIn = [68.0, 72.0, 76.0, 78.0, 80.0, 84.0];

      await tester.pumpWidget(host(const Sparkline(values: withGap)));
      expect(tester.takeException(), isNull);

      final painter = SparklinePainter(
        values: withGap,
        line: const Color(0xFF000000),
        fill: const Color(0xFF000000),
        dotBorder: const Color(0xFF000000),
      );
      expect(
        painter.shouldRepaint(
          SparklinePainter(
            values: filledIn,
            line: const Color(0xFF000000),
            fill: const Color(0xFF000000),
            dotBorder: const Color(0xFF000000),
          ),
        ),
        isTrue,
        reason: 'a series with a gap is not the same series as one without',
      );
    });

    testWidgets('an all-null series paints nothing rather than throwing', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const Sparkline(values: [null, null, null])),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a flat series does not divide by a zero range', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const Sparkline(values: [70.0, 70.0, 70.0])),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the text alternative states the trend', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        host(
          const Sparkline(
            values: [68.0, 72.0, null, 84.0],
            semanticsLabel: 'Daily score, 68 to 84 over 3 scored days',
          ),
        ),
      );
      expect(
        find.bySemanticsLabel('Daily score, 68 to 84 over 3 scored days'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('ConsistencyStrip', () {
    testWidgets('one cell per day, with the unlogged ones visible', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const ConsistencyStrip(
            cells: [
              ConsistencyCell.logged,
              ConsistencyCell.logged,
              ConsistencyCell.partial,
              ConsistencyCell.none,
            ],
            labels: ['M', 'T', 'W', 'T'],
          ),
        ),
      );

      final decorations = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .toList();
      expect(decorations, hasLength(4));
      expect(
        decorations[2].border,
        isNotNull,
        reason: 'partial is outlined as well as tinted, not colour alone',
      );
      expect(decorations[3].color, NourishlyLightColors.track);
    });
  });

  group('PeriodAverageRow', () {
    testWidgets('the denominator is rendered with the average', (tester) async {
      await tester.pumpWidget(
        host(
          const PeriodAverageRow(
            label: 'Energy',
            value: '1,910',
            note: 'over 6 logged days',
          ),
        ),
      );
      expect(find.text('Energy'), findsOneWidget);
      expect(find.text('1,910'), findsOneWidget);
      expect(find.text('over 6 logged days'), findsOneWidget);
    });
  });

  group('PeriodComparisonRow', () {
    testWidgets('a delta shows both the arrow and the sign', (tester) async {
      await tester.pumpWidget(
        host(
          const PeriodComparisonRow(
            label: 'vs August',
            delta: '+6',
            direction: PeriodTrend.up,
            note: '74 this month, 68 in August',
          ),
        ),
      );
      expect(find.text('+6'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
      expect(
        find.text('74 this month, 68 in August'),
        findsOneWidget,
        reason: '§27.11: never a bare percentage — the bases are named',
      );
    });

    testWidgets('a withheld comparison says so instead of showing nothing', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const PeriodComparisonRow(
            label: 'vs August',
            note: 'Not enough logged days in August to compare against.',
          ),
        ),
      );
      expect(find.text('Not compared'), findsOneWidget);
      expect(
        find.text('Not enough logged days in August to compare against.'),
        findsOneWidget,
      );
    });
  });
}
