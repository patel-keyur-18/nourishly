import 'package:nutrition_core/nutrition_core.dart';
import 'package:test/test.dart';

/// The profile the prototype's screens are drawn against (screen 2, screen
/// 12): 34, male, 174 cm, 71 kg, general health. Keeping the tests on it
/// means the numbers here and the numbers in the design are the same
/// numbers.
const _keyur = ProfileInputs(
  ageYears: 34,
  heightCm: 174,
  weightKg: 71,
  activityLevel: ActivityLevel.light,
  biologicalSex: BiologicalSex.male,
);

void main() {
  group('Mifflin-St Jeor (§20.4)', () {
    test('male adds 5 to the base', () {
      // 10(71) + 6.25(174) - 5(34) + 5 = 710 + 1087.5 - 170 + 5
      expect(mifflinStJeorBmr(_keyur), closeTo(1632.5, 0.01));
    });

    test('female subtracts 161', () {
      const p = ProfileInputs(
        ageYears: 34,
        heightCm: 174,
        weightKg: 71,
        activityLevel: ActivityLevel.light,
        biologicalSex: BiologicalSex.female,
      );
      expect(mifflinStJeorBmr(p), closeTo(1466.5, 0.01));
    });

    test('no stated sex takes the midpoint, not one of the two', () {
      const p = ProfileInputs(
        ageYears: 34,
        heightCm: 174,
        weightKg: 71,
        activityLevel: ActivityLevel.light,
      );
      final male = mifflinStJeorBmr(
        const ProfileInputs(
          ageYears: 34,
          heightCm: 174,
          weightKg: 71,
          activityLevel: ActivityLevel.light,
          biologicalSex: BiologicalSex.male,
        ),
      );
      final female = mifflinStJeorBmr(
        const ProfileInputs(
          ageYears: 34,
          heightCm: 174,
          weightKg: 71,
          activityLevel: ActivityLevel.light,
          biologicalSex: BiologicalSex.female,
        ),
      );
      expect(mifflinStJeorBmr(p), closeTo((male + female) / 2, 0.01));
    });
  });

  group('energy target', () {
    test('maintain is TDEE untouched', () {
      final t = deriveTargets(profile: _keyur, goal: GoalType.maintain);
      expect(t.tdeeKcal, closeTo(1632.5 * 1.375, 0.01));
      expect(t.energyKcal, closeTo(t.tdeeKcal, 0.01));
      expect(t.safetyFloorApplied, isFalse);
    });

    test('the deficit is capped at 20% of TDEE however fast you ask', () {
      final t = deriveTargets(
        profile: _keyur,
        goal: GoalType.loseWeight,
        goalRateKgPerWeek: 5,
      );
      expect(t.energyKcal, closeTo(t.tdeeKcal * 0.80, 0.01));
    });

    test(
      'a small requested rate is honoured rather than rounded up to the cap',
      () {
        final t = deriveTargets(
          profile: _keyur,
          goal: GoalType.loseWeight,
          goalRateKgPerWeek: 0.25,
        );
        // 0.25 kg/week is 275 kcal/day, well inside the 20% cap.
        expect(t.energyKcal, closeTo(t.tdeeKcal - 275, 0.01));
      },
    );

    test('the calorie floor holds even when the goal asks to go below it', () {
      // A small, sedentary profile whose 20% deficit would land under
      // 1,200 kcal.
      const small = ProfileInputs(
        ageYears: 62,
        heightCm: 148,
        weightKg: 42,
        activityLevel: ActivityLevel.sedentary,
        biologicalSex: BiologicalSex.female,
      );
      final t = deriveTargets(
        profile: small,
        goal: GoalType.loseWeight,
        goalRateKgPerWeek: 0.75,
      );
      expect(t.energyKcal, minEnergyKcalFemale);
      expect(
        t.safetyFloorApplied,
        isTrue,
        reason: 'the clamp is told to the user, not applied silently',
      );
    });
  });

  group('macros', () {
    test('protein, fat and carbs add back up to the energy target', () {
      final t = deriveTargets(profile: _keyur, goal: GoalType.maintain);
      final fromMacros =
          t.targets['protein']!.amount * 4 +
          t.targets['fat']!.amount * 9 +
          t.targets['carbs']!.amount * 4;
      expect(fromMacros, closeTo(t.energyKcal, 0.01));
    });

    test('building muscle raises protein per kg', () {
      final general = deriveTargets(
        profile: _keyur,
        goal: GoalType.generalHealth,
      );
      final muscle = deriveTargets(profile: _keyur, goal: GoalType.gainMuscle);
      expect(
        muscle.targets['protein']!.amount,
        greaterThan(general.targets['protein']!.amount),
      );
      expect(muscle.targets['protein']!.amount, closeTo(1.6 * 71, 0.01));
    });

    test('fibre follows energy at 14 g per 1,000 kcal', () {
      final t = deriveTargets(profile: _keyur, goal: GoalType.maintain);
      expect(
        t.targets['fibre']!.amount,
        closeTo(14 * t.energyKcal / 1000, 0.01),
      );
    });

    test('energy is a range and protein is a floor (§21.3)', () {
      final t = deriveTargets(profile: _keyur, goal: GoalType.maintain);
      expect(t.targets['energy']!.curveType, TargetCurveType.range);
      expect(t.targets['protein']!.curveType, TargetCurveType.floor);
    });
  });

  group('water (§20.4, A-5)', () {
    test('35 ml per kg plus an activity allowance', () {
      expect(waterTargetMl(_keyur), closeTo(35 * 71 + 150, 0.01));
    });

    test('clamped at both ends so no profile gets an absurd target', () {
      const tiny = ProfileInputs(
        ageYears: 30,
        heightCm: 150,
        weightKg: 30,
        activityLevel: ActivityLevel.sedentary,
      );
      const huge = ProfileInputs(
        ageYears: 30,
        heightCm: 200,
        weightKg: 200,
        activityLevel: ActivityLevel.veryActive,
      );
      expect(waterTargetMl(tiny), 1500);
      expect(waterTargetMl(huge), 5000);
    });
  });

  group('micronutrient targets come from the RDA table, not from code', () {
    test('a reference with an upper limit becomes a plateau curve', () {
      final t = deriveTargets(
        profile: _keyur,
        goal: GoalType.maintain,
        rdaReferences: const [
          RdaReference(nutrientId: 'iron', rdaAmount: 19, upperLimit: 45),
        ],
      );
      expect(t.targets['iron']!.curveType, TargetCurveType.plateau);
      expect(t.targets['iron']!.amount, 19);
      expect(t.targets['iron']!.upperLimit, 45);
    });

    test('one without becomes a plain floor rather than an invented limit', () {
      final t = deriveTargets(
        profile: _keyur,
        goal: GoalType.maintain,
        rdaReferences: const [
          RdaReference(nutrientId: 'vitamin_b12', rdaAmount: 2.2),
        ],
      );
      expect(t.targets['vitamin_b12']!.curveType, TargetCurveType.floor);
      expect(t.targets['vitamin_b12']!.upperLimit, isNull);
    });

    test('sodium is scored as a ceiling, not as something to reach', () {
      final t = deriveTargets(
        profile: _keyur,
        goal: GoalType.maintain,
        rdaReferences: const [
          RdaReference(nutrientId: 'sodium', rdaAmount: 2000),
        ],
      );
      expect(t.targets['sodium']!.curveType, TargetCurveType.ceiling);
    });
  });
}
