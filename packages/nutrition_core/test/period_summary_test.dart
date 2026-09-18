import 'package:nutrition_core/nutrition_core.dart';
import 'package:test/test.dart';

final _monday = DateTime(2026, 9, 7);

PeriodDayNutrient _n(
  String id,
  double amount, {
  double? target,
  NutrientStatus status = NutrientStatus.within,
  double coverage = 1,
}) => PeriodDayNutrient(
  nutrientId: id,
  amount: amount,
  coverage: coverage,
  status: status,
  targetAmount: target,
);

PeriodDay _day(
  int dayOffset, {
  double? score,
  double energy = 2000,
  double water = 2500,
  int entries = 4,
  DayCompleteness completeness = DayCompleteness.complete,
  Map<String, PeriodDayNutrient> nutrients = const {},
}) => PeriodDay(
  date: _monday.add(Duration(days: dayOffset)),
  completeness: completeness,
  entryCount: entries,
  totalEnergyKcal: energy,
  waterMl: water,
  nutrients: nutrients,
  score: score,
  energyTargetKcal: 2050,
);

PeriodSummary _week(List<PeriodDay> days, {List<String> order = const []}) =>
    PeriodSummary(
      kind: PeriodKind.week,
      start: _monday,
      end: _monday.add(const Duration(days: 6)),
      days: days,
      nutrientOrder: order,
    );

/// A full week with [logged] days logged, the rest untouched.
PeriodSummary _weekWith(int logged, {double score = 75}) => _week([
  for (var i = 0; i < 7; i++)
    if (i < logged)
      _day(
        i,
        score: score,
        nutrients: {'protein': _n('protein', 90, target: 90)},
      )
    else
      PeriodDay.unlogged(_monday.add(Duration(days: i))),
]);

void main() {
  group('the logging threshold (§25.6)', () {
    test('two logged days produce no averages at all', () {
      final week = _weekWith(2);
      expect(week.meetsLoggingThreshold, isFalse);
      expect(week.averageScore, isNull);
      expect(week.averageEnergyKcal, isNull);
      expect(week.averageWaterMl, isNull);
      expect(week.nutrientAverages, isEmpty);
      expect(week.chronicallyLow, isEmpty);
    });

    test('three logged days is enough, and the raw days are still there', () {
      final week = _weekWith(3);
      expect(week.meetsLoggingThreshold, isTrue);
      expect(week.averageScore, 75);
      // The denominator survives: seven calendar days, three of them logged.
      expect(week.calendarDayCount, 7);
      expect(week.loggedDayCount, 3);
      expect(week.averagedDayCount, 3);
    });
  });

  group('what may be averaged', () {
    test('a day that looks incompletely logged is held out, and shown', () {
      final week = _week([
        _day(0, score: 80),
        _day(1, score: 80),
        _day(2, score: 80),
        // The forgotten dinner: logged, and not a real 600 kcal day.
        _day(3, energy: 600, completeness: DayCompleteness.looksIncomplete),
        for (var i = 4; i < 7; i++)
          PeriodDay.unlogged(_monday.add(Duration(days: i))),
      ]);

      expect(week.loggedDayCount, 4, reason: 'it was logged');
      expect(week.averagedDayCount, 3, reason: 'but it is not averaged');
      expect(week.averageEnergyKcal, 2000, reason: 'the 600 is not in here');
      expect(week.daysExcludedAsIncomplete.map((d) => d.date), [
        _monday.add(const Duration(days: 3)),
      ], reason: '§25.6 wants the exclusion visible, not silent');
    });

    test('a day still in progress is not yet a data point', () {
      final week = _week([
        _day(0, score: 80),
        _day(1, score: 80),
        _day(2, score: 80),
        _day(3, energy: 500, completeness: DayCompleteness.inProgress),
        for (var i = 4; i < 7; i++)
          PeriodDay.unlogged(_monday.add(Duration(days: i))),
      ]);
      expect(week.averagedDayCount, 3);
      expect(week.averageEnergyKcal, 2000);
    });

    test('a water-only day is a logged day', () {
      final day = _day(0, entries: 0, energy: 0, water: 2000);
      expect(day.wasLogged, isTrue);
      expect(day.countsTowardAverages, isTrue);
    });

    test(
      'an energy average skips days with no food but keeps them for water',
      () {
        final week = _week([
          _day(0, entries: 4, energy: 2000, water: 2000),
          _day(1, entries: 4, energy: 2000, water: 2000),
          // Water only: no food to average into the energy figure.
          _day(2, entries: 0, energy: 0, water: 1000),
          for (var i = 3; i < 7; i++)
            PeriodDay.unlogged(_monday.add(Duration(days: i))),
        ]);
        expect(week.averageEnergyKcal, 2000, reason: 'over the two food days');
        expect(
          week.averageWaterMl,
          closeTo((2000 + 2000 + 1000) / 3, 1e-9),
          reason: 'a food day with no water really did have no water',
        );
      },
    );
  });

  group('averages carry their denominators (§25.6)', () {
    test('a nutrient average states the days it is built from', () {
      final week = _week([
        for (var i = 0; i < 5; i++)
          _day(
            i,
            score: 70,
            nutrients: {
              'fibre': _n(
                'fibre',
                i == 4 ? 30 : 16,
                target: 29,
                status: i == 4 ? NutrientStatus.within : NutrientStatus.below,
              ),
            },
          ),
        for (var i = 5; i < 7; i++)
          PeriodDay.unlogged(_monday.add(Duration(days: i))),
      ]);

      final fibre = week.nutrientAverage('fibre')!;
      expect(fibre.average, closeTo((16 * 4 + 30) / 5, 1e-9));
      expect(fibre.daysAveraged, 5);
      expect(fibre.daysMet, 1);
      expect(fibre.daysMissed, 4);
    });

    test('a nutrient with no data on a day is not averaged as zero', () {
      final week = _week([
        _day(0, score: 70, nutrients: {'iron': _n('iron', 12, target: 19)}),
        _day(1, score: 70, nutrients: {'iron': _n('iron', 14, target: 19)}),
        _day(
          2,
          score: 70,
          nutrients: {
            'iron': _n(
              'iron',
              0,
              target: 19,
              status: NutrientStatus.insufficientData,
              coverage: 0.2,
            ),
          },
        ),
        for (var i = 3; i < 7; i++)
          PeriodDay.unlogged(_monday.add(Duration(days: i))),
      ]);

      final iron = week.nutrientAverage('iron')!;
      expect(iron.average, 13, reason: 'not (12 + 14 + 0) / 3');
      expect(iron.daysAveraged, 2);
    });

    test('a period average carries the coverage it was built from', () {
      final week = _week([
        for (var i = 0; i < 3; i++)
          _day(
            i,
            score: 70,
            nutrients: {'iron': _n('iron', 12, target: 19, coverage: 0.4)},
          ),
        for (var i = 3; i < 7; i++)
          PeriodDay.unlogged(_monday.add(Duration(days: i))),
      ]);
      expect(week.nutrientAverage('iron')!.averageCoverage, closeTo(0.4, 1e-9));
    });

    test('nutrients come back in registry order', () {
      final week = _week(
        [
          for (var i = 0; i < 3; i++)
            _day(
              i,
              score: 70,
              nutrients: {
                'iron': _n('iron', 12),
                'protein': _n('protein', 90),
                'energy': _n('energy', 2000),
              },
            ),
          for (var i = 3; i < 7; i++)
            PeriodDay.unlogged(_monday.add(Duration(days: i))),
        ],
        order: const ['energy', 'protein', 'iron'],
      );

      expect(week.nutrientAverages.map((n) => n.nutrientId), [
        'energy',
        'protein',
        'iron',
      ]);
    });
  });

  group('the score line', () {
    test('an unlogged day is a gap, not a zero and not an interpolation', () {
      final week = _weekWith(3, score: 80);
      final series = week.scoreSeries;
      expect(series, hasLength(7));
      expect(series.take(3).map((p) => p.score), [80, 80, 80]);
      expect(
        series.skip(3).map((p) => p.score),
        everyElement(isNull),
        reason: '§27.11: interpolation invents data; a gap is the truth',
      );
    });

    test('a logged day whose score was withheld is also a gap', () {
      final week = _week([
        _day(0, score: 80),
        _day(1),
        _day(2, score: 80),
        for (var i = 3; i < 7; i++)
          PeriodDay.unlogged(_monday.add(Duration(days: i))),
      ]);
      expect(week.scoreSeries[1].score, isNull);
      expect(week.loggedDayCount, 3);
    });

    test('the moving average waits for its window to fill', () {
      final month = PeriodSummary(
        kind: PeriodKind.month,
        start: _monday,
        end: _monday.add(const Duration(days: 13)),
        days: [for (var i = 0; i < 14; i++) _day(i, score: 70)],
      );
      final smoothed = month.movingAverage();

      expect(
        smoothed.take(6).map((p) => p.score),
        everyElement(isNull),
        reason: 'six days is not a seven-day average',
      );
      expect(smoothed[6].score, 70);
      expect(smoothed.last.score, 70);
    });

    test('a mostly-empty window produces no point rather than a thin one', () {
      final month = PeriodSummary(
        kind: PeriodKind.month,
        start: _monday,
        end: _monday.add(const Duration(days: 13)),
        days: [
          for (var i = 0; i < 14; i++)
            if (i == 6)
              _day(i, score: 90)
            else
              PeriodDay.unlogged(_monday.add(Duration(days: i))),
        ],
      );
      // One scored day out of seven drawn as a seven-day average would be
      // the same lie as averaging a week over two days.
      expect(month.movingAverage()[6].score, isNull);
    });

    test('the smoothed line tracks the shape it is given', () {
      final month = PeriodSummary(
        kind: PeriodKind.month,
        start: _monday,
        end: _monday.add(const Duration(days: 13)),
        days: [for (var i = 0; i < 14; i++) _day(i, score: 60 + i * 2)],
      );
      final smoothed = month.movingAverage();
      expect(smoothed[6].score, closeTo(66, 1e-9));
      expect(smoothed[13].score, closeTo(80, 1e-9));
      expect(smoothed[13].score, greaterThan(smoothed[6].score!));
    });
  });

  group('findings', () {
    test('the best day is the best scored day, not the busiest', () {
      final week = _week([
        _day(0, score: 68),
        _day(1, score: 84),
        _day(2, score: 71),
        for (var i = 3; i < 7; i++)
          PeriodDay.unlogged(_monday.add(Duration(days: i))),
      ]);
      expect(week.bestDay!.score, 84);
      expect(week.bestDay!.date, _monday.add(const Duration(days: 1)));
    });

    test('most-missed is ordered by how often, worst first', () {
      PeriodDayNutrient miss(String id, {required bool met}) => _n(
        id,
        10,
        target: 20,
        status: met ? NutrientStatus.within : NutrientStatus.below,
      );

      final week = _week([
        for (var i = 0; i < 6; i++)
          _day(
            i,
            score: 70,
            nutrients: {
              // Fibre missed all six, iron four, protein one.
              'fibre': miss('fibre', met: false),
              'iron': miss('iron', met: i >= 4),
              'protein': miss('protein', met: i >= 1),
            },
          ),
        PeriodDay.unlogged(_monday.add(const Duration(days: 6))),
      ]);

      expect(week.mostMissed().map((n) => n.nutrientId), [
        'fibre',
        'iron',
        'protein',
      ]);
      expect(week.mostMissed(limit: 2), hasLength(2));
    });

    test('a nutrient with no target is not counted as missed', () {
      final week = _week([
        for (var i = 0; i < 4; i++)
          _day(
            i,
            score: 70,
            nutrients: {
              'manganese': _n('manganese', 2, status: NutrientStatus.below),
            },
          ),
        for (var i = 4; i < 7; i++)
          PeriodDay.unlogged(_monday.add(Duration(days: i))),
      ]);
      expect(week.mostMissed(), isEmpty);
    });

    test('chronically low needs half the days, and states the count', () {
      PeriodDay dayWith({required bool fibreLow, required int at}) => _day(
        at,
        score: 70,
        nutrients: {
          'fibre': _n(
            'fibre',
            fibreLow ? 16 : 30,
            target: 29,
            status: fibreLow ? NutrientStatus.below : NutrientStatus.within,
          ),
          'sodium': _n(
            'sodium',
            2600,
            target: 2000,
            status: NutrientStatus.above,
          ),
        },
      );

      final week = _week([
        for (var i = 0; i < 6; i++) dayWith(fibreLow: i < 5, at: i),
        PeriodDay.unlogged(_monday.add(const Duration(days: 6))),
      ]);

      final low = week.chronicallyLow.single;
      expect(low.nutrientId, 'fibre');
      expect(low.days, 5);
      expect(low.outOf, 6, reason: 'shown as "5 of 6 days"');

      expect(week.chronicallyHigh.single.nutrientId, 'sodium');
    });

    test('a nutrient short on a minority of days is not called chronic', () {
      final week = _week([
        for (var i = 0; i < 6; i++)
          _day(
            i,
            score: 70,
            nutrients: {
              'fibre': _n(
                'fibre',
                i < 2 ? 16 : 30,
                target: 29,
                status: i < 2 ? NutrientStatus.below : NutrientStatus.within,
              ),
            },
          ),
        PeriodDay.unlogged(_monday.add(const Duration(days: 6))),
      ]);
      expect(week.chronicallyLow, isEmpty);
    });
  });

  test('the consistency strip has one cell per calendar day', () {
    final week = _weekWith(3);
    expect(week.consistencyStrip, hasLength(7));
    expect(
      week.consistencyStrip.take(3),
      everyElement(DayCompleteness.complete),
    );
    expect(week.consistencyStrip.skip(3), everyElement(DayCompleteness.empty));
  });
}
