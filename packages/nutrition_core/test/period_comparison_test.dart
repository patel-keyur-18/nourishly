import 'package:nutrition_core/nutrition_core.dart';
import 'package:test/test.dart';

final _start = DateTime(2026, 9, 1);

PeriodSummary _month(
  DateTime start, {
  required int loggedDays,
  required double score,
  double energy = 2000,
}) => PeriodSummary(
  kind: PeriodKind.month,
  start: start,
  end: start.add(const Duration(days: 29)),
  days: [
    for (var i = 0; i < 30; i++)
      if (i < loggedDays)
        PeriodDay(
          date: start.add(Duration(days: i)),
          completeness: DayCompleteness.complete,
          entryCount: 4,
          totalEnergyKcal: energy,
          waterMl: 2500,
          nutrients: const {},
          score: score,
        )
      else
        PeriodDay.unlogged(start.add(Duration(days: i))),
  ],
);

final _previous = _start.subtract(const Duration(days: 30));

void main() {
  group('a comparison needs both periods (§25.6)', () {
    test('a sparse previous period produces no delta, and says why', () {
      final comparison = PeriodComparison.between(
        current: _month(_start, loggedDays: 24, score: 74),
        previous: _month(_previous, loggedDays: 2, score: 68),
      );

      expect(comparison.isAvailable, isFalse);
      expect(
        comparison.withheldReason,
        ComparisonWithheldReason.previousPeriodTooSparse,
      );
      expect(comparison.score, isNull);
    });

    test('a sparse current period is refused the same way', () {
      final comparison = PeriodComparison.between(
        current: _month(_start, loggedDays: 2, score: 74),
        previous: _month(_previous, loggedDays: 24, score: 68),
      );
      expect(
        comparison.withheldReason,
        ComparisonWithheldReason.currentPeriodTooSparse,
      );
    });

    test('two well-logged months compare, with both bases stated', () {
      final comparison = PeriodComparison.between(
        current: _month(_start, loggedDays: 24, score: 74),
        previous: _month(_previous, loggedDays: 22, score: 68),
      );

      expect(comparison.isAvailable, isTrue);
      final score = comparison.score!;
      expect(score.current, 74);
      expect(score.previous, 68, reason: '§27.11: never a bare percentage');
      expect(score.delta, 6);
      expect(score.direction, TrendDirection.up);
    });
  });

  group('a trend needs a big enough effect (§25.6)', () {
    test('a one-point move between two full months is not a trend', () {
      final comparison = PeriodComparison.between(
        current: _month(_start, loggedDays: 24, score: 69),
        previous: _month(_previous, loggedDays: 24, score: 68),
      );

      final score = comparison.score!;
      expect(score.delta, closeTo(1, 1e-9), reason: 'the delta is still shown');
      expect(
        score.direction,
        TrendDirection.flat,
        reason: 'but no arrow is drawn on it',
      );
      expect(score.isTrend, isFalse);
    });

    test('a downward move is called down, not just "changed"', () {
      final comparison = PeriodComparison.between(
        current: _month(_start, loggedDays: 24, score: 60),
        previous: _month(_previous, loggedDays: 24, score: 74),
      );
      expect(comparison.score!.direction, TrendDirection.down);
    });

    test('three logged days clears averaging but not trending', () {
      // §25.6 asks for a minimum sample for a trend arrow that is over and
      // above the minimum for an average.
      final comparison = PeriodComparison.between(
        current: _month(_start, loggedDays: 3, score: 90),
        previous: _month(_previous, loggedDays: 3, score: 60),
      );
      expect(comparison.current.averageScore, 90);
      expect(comparison.previous.averageScore, 60);
      expect(
        comparison.withheldReason,
        ComparisonWithheldReason.nothingScored,
        reason: 'both averages exist; neither sample carries an arrow',
      );
    });

    test('energy is compared on its relative movement', () {
      final flat = PeriodComparison.between(
        current: _month(_start, loggedDays: 24, score: 70, energy: 2020),
        previous: _month(_previous, loggedDays: 24, score: 70, energy: 2000),
      );
      expect(flat.energyKcal!.direction, TrendDirection.flat);

      final real = PeriodComparison.between(
        current: _month(_start, loggedDays: 24, score: 70, energy: 2400),
        previous: _month(_previous, loggedDays: 24, score: 70, energy: 2000),
      );
      expect(real.energyKcal!.direction, TrendDirection.up);
      expect(real.energyKcal!.relativeDelta, closeTo(0.2, 1e-9));
    });
  });
}
