import 'package:nutrition_core/nutrition_core.dart';
import 'package:test/test.dart';

/// The due date is the only thing that moves the lifestage on, so these
/// boundaries are load-bearing: getting one wrong means weeks of targets
/// that are quietly for the wrong stage, which is exactly the failure
/// asking for a due date instead of a trimester was meant to remove.
void main() {
  final due = DateTime(2026, 12, 25);

  /// The day `weeks` completed weeks of gestation begins.
  DateTime atGestationalWeek(int weeks) =>
      due.subtract(Duration(days: gestationDays - weeks * 7));

  group('lifestageOn', () {
    test('before conception, nothing applies', () {
      expect(
        lifestageOn(
          atGestationalWeek(0).subtract(const Duration(days: 1)),
          due,
        ),
        Lifestage.adult,
      );
    });

    test('weeks 0-13 are the first trimester', () {
      expect(lifestageOn(atGestationalWeek(0), due), Lifestage.pregnantT1);
      expect(lifestageOn(atGestationalWeek(13), due), Lifestage.pregnantT1);
    });

    test('week 14 begins the second trimester', () {
      expect(lifestageOn(atGestationalWeek(14), due), Lifestage.pregnantT2);
      expect(lifestageOn(atGestationalWeek(27), due), Lifestage.pregnantT2);
    });

    test('week 28 begins the third', () {
      expect(lifestageOn(atGestationalWeek(28), due), Lifestage.pregnantT3);
      expect(
        lifestageOn(due.subtract(const Duration(days: 1)), due),
        Lifestage.pregnantT3,
      );
    });

    test('the due date itself is already nursing', () {
      expect(lifestageOn(due, due), Lifestage.lactating0to6);
    });

    test('nursing runs six months, then six more', () {
      expect(
        lifestageOn(due.add(const Duration(days: 182)), due),
        Lifestage.lactating0to6,
      );
      expect(
        lifestageOn(due.add(const Duration(days: 183)), due),
        Lifestage.lactating7to12,
      );
    });

    test('a year on, it lets go by itself', () {
      expect(
        lifestageOn(due.add(const Duration(days: 365)), due),
        Lifestage.adult,
        reason:
            'adding 500 kcal a day forever because a date was never '
            'cleared is its own kind of wrong',
      );
    });
  });

  test('gestationalWeeksOn reports completed weeks, then stops', () {
    expect(gestationalWeeksOn(atGestationalWeek(22), due), 22);
    expect(gestationalWeeksOn(due, due), isNull);
  });

  test('a lifestage written by the old two-value model still reads', () {
    expect(Lifestage.fromId('pregnant'), Lifestage.pregnantT2);
    expect(Lifestage.fromId('lactating'), Lifestage.lactating0to6);
    expect(Lifestage.fromId('adult'), Lifestage.adult);
    expect(Lifestage.fromId('nonsense'), Lifestage.adult);
  });

  group('derived targets', () {
    ProfileInputs profile(Lifestage lifestage) => ProfileInputs(
      ageYears: 31,
      heightCm: 162,
      weightKg: 58,
      activityLevel: ActivityLevel.light,
      biologicalSex: BiologicalSex.female,
      lifestage: lifestage,
    );

    test('the first trimester adds nothing', () {
      final adult = deriveTargets(
        profile: profile(Lifestage.adult),
        goal: GoalType.maintain,
      );
      final t1 = deriveTargets(
        profile: profile(Lifestage.pregnantT1),
        goal: GoalType.maintain,
      );
      expect(t1.energyKcal, adult.energyKcal);
      expect(t1.targets['protein']!.amount, adult.targets['protein']!.amount);
    });

    test('later trimesters add energy and protein', () {
      final adult = deriveTargets(
        profile: profile(Lifestage.adult),
        goal: GoalType.maintain,
      );
      final t3 = deriveTargets(
        profile: profile(Lifestage.pregnantT3),
        goal: GoalType.maintain,
      );
      expect(t3.energyKcal, adult.energyKcal + 350);
      expect(
        t3.targets['protein']!.amount,
        closeTo(adult.targets['protein']!.amount + 17.6, 0.001),
      );
    });

    test('a weight-loss goal is refused, not floored', () {
      final derived = deriveTargets(
        profile: profile(Lifestage.pregnantT2),
        goal: GoalType.loseWeight,
      );
      final maintain = deriveTargets(
        profile: profile(Lifestage.pregnantT2),
        goal: GoalType.maintain,
      );

      expect(derived.goalRefusedForLifestage, isTrue);
      expect(
        derived.energyKcal,
        maintain.energyKcal,
        reason:
            'a 350 kcal increment and a 350 kcal deficit must not '
            'cancel into a number that looks reasonable',
      );
    });

    test('a weight-loss goal is untouched for an adult', () {
      final derived = deriveTargets(
        profile: profile(Lifestage.adult),
        goal: GoalType.loseWeight,
      );
      expect(derived.goalRefusedForLifestage, isFalse);
      expect(derived.energyKcal, lessThan(derived.tdeeKcal));
    });

    test('the energy explanation names the increment', () {
      final derived = deriveTargets(
        profile: profile(Lifestage.lactating0to6),
        goal: GoalType.maintain,
      );
      expect(derived.explanations['energy'], contains('600 kcal'));
      expect(derived.explanations['energy'], contains('nursing'));
    });
  });
}
