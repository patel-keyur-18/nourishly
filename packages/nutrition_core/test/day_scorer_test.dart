import 'package:nutrition_core/nutrition_core.dart';
import 'package:test/test.dart';

NutrientAggregate _agg(
  String id,
  double amount, {
  double known = 2000,
  double total = 2000,
}) => NutrientAggregate(
  nutrientId: id,
  amount: amount,
  knownEnergyKcal: known,
  totalEnergyKcal: total,
);

const _micros = ['iron', 'calcium', 'vitamin_c', 'zinc', 'folate'];

Map<String, NutrientTarget> _fullTargets() => {
  'energy': const NutrientTarget(
    nutrientId: 'energy',
    curveType: TargetCurveType.range,
    amount: 2000,
  ),
  'protein': const NutrientTarget(
    nutrientId: 'protein',
    curveType: TargetCurveType.floor,
    amount: 90,
  ),
  'carbs': const NutrientTarget(
    nutrientId: 'carbs',
    curveType: TargetCurveType.range,
    amount: 240,
    tolerance: 0.15,
  ),
  'fat': const NutrientTarget(
    nutrientId: 'fat',
    curveType: TargetCurveType.range,
    amount: 61,
    tolerance: 0.27,
  ),
  'fibre': const NutrientTarget(
    nutrientId: 'fibre',
    curveType: TargetCurveType.floor,
    amount: 28,
  ),
  'sodium': const NutrientTarget(
    nutrientId: 'sodium',
    curveType: TargetCurveType.ceiling,
    amount: 2000,
  ),
  for (final id in _micros)
    id: NutrientTarget(
      nutrientId: id,
      curveType: TargetCurveType.floor,
      amount: 10,
    ),
};

Map<String, NutrientAggregate> _perfectDay() => {
  'energy': _agg('energy', 2000),
  'protein': _agg('protein', 90),
  'carbs': _agg('carbs', 240),
  'fat': _agg('fat', 61),
  'fibre': _agg('fibre', 28),
  'sodium': _agg('sodium', 1500),
  for (final id in _micros) id: _agg(id, 10),
};

void main() {
  group('day completeness gating (§21.5)', () {
    test('a day still running shows progress, not a score', () {
      final score = scoreDay(
        DayForScoring(
          nutrients: _perfectDay(),
          targets: _fullTargets(),
          goal: GoalType.generalHealth,
          isComplete: false,
          waterMl: 2000,
          waterTargetMl: 2500,
        ),
      );
      expect(score.composite, isNull);
      expect(score.withheldReason, ScoreWithheldReason.dayIncomplete);
    });

    test('a forgotten dinner is withheld, not read as a severe deficit', () {
      // The single most common false signal in nutrition apps.
      final score = scoreDay(
        DayForScoring(
          nutrients: {'energy': _agg('energy', 600, known: 600, total: 600)},
          targets: _fullTargets(),
          goal: GoalType.generalHealth,
          isComplete: true,
        ),
      );
      expect(score.withheldReason, ScoreWithheldReason.looksIncompletelyLogged);
    });

    test('a genuinely light but plausible day is scored', () {
      final nutrients = _perfectDay()
        ..['energy'] = _agg('energy', 1500, known: 1500, total: 1500);
      final score = scoreDay(
        DayForScoring(
          nutrients: nutrients,
          targets: _fullTargets(),
          goal: GoalType.generalHealth,
          isComplete: true,
          waterMl: 2500,
          waterTargetMl: 2500,
        ),
      );
      expect(score.withheldReason, isNull);
      expect(score.composite, isNotNull);
    });

    test(
      'a profile with no targets is told to set them, not scored at zero',
      () {
        final score = scoreDay(
          DayForScoring(
            nutrients: _perfectDay(),
            targets: const {},
            goal: GoalType.generalHealth,
            isComplete: true,
          ),
        );
        expect(score.withheldReason, ScoreWithheldReason.noTargets);
        expect(score.composite, isNull);
      },
    );
  });

  group('coverage gating (§21.5)', () {
    test('a micro below its coverage gate is left out of the mean', () {
      final nutrients = _perfectDay();
      // Iron reported by only a third of the day's energy: present, but
      // not enough of the day to say anything about.
      nutrients['iron'] = _agg('iron', 3, known: 660, total: 2000);
      final score = scoreDay(
        DayForScoring(
          nutrients: nutrients,
          targets: _fullTargets(),
          goal: GoalType.generalHealth,
          isComplete: true,
          waterMl: 2500,
          waterTargetMl: 2500,
        ),
      );
      final micros = score.component(ScoreComponentKey.micronutrientCoverage)!;
      expect(micros.wasExcluded, isFalse);
      expect(
        micros.score,
        100,
        reason:
            'the four that cleared the gate all met their target; the '
            'poorly-covered iron neither helped nor hurt',
      );
    });

    test('too few micros clearing the gate excludes the whole component', () {
      final nutrients = _perfectDay();
      for (final id in _micros.take(4)) {
        nutrients[id] = _agg(id, 3, known: 400, total: 2000);
      }
      final score = scoreDay(
        DayForScoring(
          nutrients: nutrients,
          targets: _fullTargets(),
          goal: GoalType.generalHealth,
          isComplete: true,
          waterMl: 2500,
          waterTargetMl: 2500,
        ),
      );
      final micros = score.component(ScoreComponentKey.micronutrientCoverage)!;
      expect(micros.exclusion, ScoreExclusion.insufficientCoverage);
      expect(micros.appliedWeight, 0);
    });

    test("an excluded component's weight goes to the others, and they still sum to 1", () {
      final nutrients = _perfectDay();
      for (final id in _micros) {
        nutrients[id] = _agg(id, 3, known: 200, total: 2000);
      }
      final score = scoreDay(
        DayForScoring(
          nutrients: nutrients,
          targets: _fullTargets(),
          goal: GoalType.generalHealth,
          isComplete: true,
          waterMl: 2500,
          waterTargetMl: 2500,
        ),
      );
      final applied = score.components
          .where((c) => !c.wasExcluded)
          .fold<double>(0, (a, c) => a + c.appliedWeight);
      expect(applied, closeTo(1, 1e-9));
    });
  });

  group('composite', () {
    test('a day that meets everything scores 100', () {
      final score = scoreDay(
        DayForScoring(
          nutrients: _perfectDay(),
          targets: _fullTargets(),
          goal: GoalType.generalHealth,
          isComplete: true,
          waterMl: 2500,
          waterTargetMl: 2500,
        ),
      );
      expect(score.composite, closeTo(100, 1e-9));
      expect(score.band, ScoreBand.excellent);
    });

    test('eating three times the protein target buys nothing (§21.4)', () {
      final capped = _perfectDay()..['protein'] = _agg('protein', 270);
      final score = scoreDay(
        DayForScoring(
          nutrients: capped,
          targets: _fullTargets(),
          goal: GoalType.generalHealth,
          isComplete: true,
          waterMl: 2500,
          waterTargetMl: 2500,
        ),
      );
      expect(score.composite, closeTo(100, 1e-9));
    });

    test('the goal changes the weighting (§21.4)', () {
      final nutrients = _perfectDay()..['protein'] = _agg('protein', 45);
      DailyScore forGoal(GoalType goal) => scoreDay(
        DayForScoring(
          nutrients: nutrients,
          targets: _fullTargets(),
          goal: goal,
          isComplete: true,
          waterMl: 2500,
          waterTargetMl: 2500,
        ),
      );
      expect(
        forGoal(GoalType.gainMuscle).composite,
        lessThan(forGoal(GoalType.generalHealth).composite!),
        reason: 'half the protein target costs more when the goal is muscle',
      );
    });

    test('water alone carries the hydration-only profile', () {
      final score = scoreDay(
        DayForScoring(
          nutrients: const {},
          targets: _fullTargets(),
          goal: GoalType.hydration,
          isComplete: true,
          waterMl: 2500,
          waterTargetMl: 2500,
        ),
      );
      // Nothing was eaten, so every food component drops out; hydration is
      // all that is left, and it was met.
      expect(score.withheldReason, ScoreWithheldReason.nothingLogged);
      expect(
        score.component(ScoreComponentKey.hydration)!.score,
        closeTo(100, 1e-9),
      );
    });
  });

  group('safety (§21.8)', () {
    test('eating far under target lowers the score, exactly as over does', () {
      DailyScore atEnergy(double kcal) {
        final nutrients = _perfectDay()
          ..['energy'] = _agg('energy', kcal, known: kcal, total: kcal);
        return scoreDay(
          DayForScoring(
            nutrients: nutrients,
            targets: _fullTargets(),
            goal: GoalType.generalHealth,
            isComplete: true,
            waterMl: 2500,
            waterTargetMl: 2500,
          ),
        );
      }

      final onTarget = atEnergy(2000).composite!;
      expect(atEnergy(1400).composite, lessThan(onTarget));
      expect(atEnergy(2800).composite, lessThan(onTarget));
    });
  });
}
