import 'package:meta/meta.dart';

import '../nutrients/nutrient_id.dart';
import '../scoring/nutrient_target.dart';
import '../scoring/score_component.dart';
import 'profile_inputs.dart';
import 'target_curve_type.dart';

/// Ruleset version for target derivation. Recorded on every `TargetSet` so
/// a historical target can be explained with the rules that produced it.
const String derivationRulesetVersion = '1.0.0';

/// One micronutrient's reference intake, looked up by age, sex, lifestage
/// and region (§22.5 `RdaReference`). Data, not code — the values live in
/// the database and this is the shape they arrive in.
@immutable
class RdaReference {
  const RdaReference({
    required this.nutrientId,
    required this.rdaAmount,
    this.upperLimit,
    this.sourceCitation = '',
  });

  final NutrientId nutrientId;
  final double rdaAmount;
  final double? upperLimit;
  final String sourceCitation;
}

/// What a derivation produced, and the reasoning behind each headline
/// number — §27.12's goals screen shows exactly these sentences under each
/// target, and §27.1 shows the energy one during onboarding.
@immutable
class DerivedTargets {
  const DerivedTargets({
    required this.targets,
    required this.waterTargetMl,
    required this.bmrKcal,
    required this.tdeeKcal,
    required this.explanations,
    required this.safetyFloorApplied,
    this.goalRefusedForLifestage = false,
  });

  final Map<NutrientId, NutrientTarget> targets;
  final double waterTargetMl;
  final double bmrKcal;
  final double tdeeKcal;

  /// Nutrient id -> the one-line "why this number" shown on the goals
  /// screen.
  final Map<NutrientId, String> explanations;

  /// True when the goal adjustment was clamped by §20.4's calorie floor.
  /// Surfaced to the user rather than silently applied — the floor is a
  /// safety requirement, and a target that quietly differs from what was
  /// asked for is worse than one that explains itself.
  final bool safetyFloorApplied;

  /// True when a weight-loss goal was refused because the profile is on a
  /// pregnancy or lactation lifestage. Same reasoning as the floor, and
  /// the same obligation: the screen says so rather than quietly showing
  /// a number that is not what was asked for.
  final bool goalRefusedForLifestage;

  double get energyKcal => targets['energy']!.amount;
}

/// The extra energy and protein a pregnancy or lactation lifestage adds on
/// top of the derived adult numbers (§20.4).
///
/// Here rather than in `rda_icmr_nin_2020.json` for the same reason
/// saturated fat and sugar are: these are increments on a number derived
/// per-profile, and a table keyed by age and sex cannot express "whatever
/// this person's requirement is, plus 350".
///
/// [REVIEW PENDING] Transcribed from ICMR-NIN, *Nutrient Requirements for
/// Indians* (2020), and carrying exactly the status the adult values in
/// the RDA asset carry: they are here so the app can derive a target at
/// all, and they are not a substitute for the nutrition review packet
/// (§0.6). Every figure below is to be checked against the report before
/// anyone relies on it.
const Map<Lifestage, LifestageIncrement> lifestageIncrements = {
  // ICMR-NIN 2020 adds nothing in the first trimester: the requirement
  // rises with the pregnancy, and an increment from week one would be
  // three months of a target nobody needs.
  Lifestage.pregnantT1: LifestageIncrement(energyKcal: 0, proteinG: 0),
  Lifestage.pregnantT2: LifestageIncrement(energyKcal: 350, proteinG: 7.6),
  Lifestage.pregnantT3: LifestageIncrement(energyKcal: 350, proteinG: 17.6),
  Lifestage.lactating0to6: LifestageIncrement(energyKcal: 600, proteinG: 13.6),
  Lifestage.lactating7to12: LifestageIncrement(energyKcal: 520, proteinG: 10.6),
};

/// One lifestage's additions to the derived energy and protein targets.
@immutable
class LifestageIncrement {
  const LifestageIncrement({required this.energyKcal, required this.proteinG});

  final double energyKcal;
  final double proteinG;

  static const none = LifestageIncrement(energyKcal: 0, proteinG: 0);
}

/// §20.4's minimum energy targets. The app will not compute a target below
/// these even if the goal asks for it — a safety requirement, not a
/// default (§21.8).
const double minEnergyKcalFemale = 1200;
const double minEnergyKcalMale = 1500;

/// Derives a full target set from a profile and a goal (§20.4).
///
/// Everything here is a documented default that the user can override
/// (FR-U-05); the derivation exists so that a profile which answers five
/// questions gets sensible targets, not so that the numbers are beyond
/// question.
DerivedTargets deriveTargets({
  required ProfileInputs profile,
  required GoalType goal,
  Iterable<RdaReference> rdaReferences = const [],
  double? goalRateKgPerWeek,
}) {
  final bmr = mifflinStJeorBmr(profile);
  final tdee = bmr * profile.activityLevel.pal;

  // A deficit is refused outright on a pregnancy or lactation lifestage,
  // not merely floored (§21.8's stance, extended). The floor alone is not
  // enough: a 350 kcal increment and a 350 kcal deficit cancel into a
  // number that looks entirely reasonable and is not what anybody asked
  // for. The refusal is reported rather than applied silently.
  final refusesDeficit =
      profile.lifestage.refusesDeficit && goal == GoalType.loseWeight;
  final effectiveGoal = refusesDeficit ? GoalType.maintain : goal;

  final (baseEnergy, floorApplied) = _energyForGoal(
    tdee: tdee,
    goal: effectiveGoal,
    profile: profile,
    rateKgPerWeek: goalRateKgPerWeek,
  );

  final increment =
      lifestageIncrements[profile.lifestage] ?? LifestageIncrement.none;
  final energy = baseEnergy + increment.energyKcal;

  final proteinGPerKg = _proteinGramsPerKg(effectiveGoal);
  final protein = proteinGPerKg * profile.weightKg + increment.proteinG;
  // Fat as the midpoint of §20.4's 20-35% range; carbohydrate takes the
  // remainder, which is what makes the three add up to the energy target
  // instead of to something near it.
  final fat = energy * 0.275 / 9;
  final carbs = ((energy - protein * 4 - fat * 9) / 4).clamp(
    0,
    double.infinity,
  );
  final fibre = 14 * energy / 1000;

  final targets = <NutrientId, NutrientTarget>{
    'energy': NutrientTarget(
      nutrientId: 'energy',
      curveType: TargetCurveType.range,
      amount: energy,
    ),
    'protein': NutrientTarget(
      nutrientId: 'protein',
      curveType: TargetCurveType.floor,
      amount: protein,
    ),
    'fat': NutrientTarget(
      nutrientId: 'fat',
      curveType: TargetCurveType.range,
      // A 20-35% range is wider than the default +/-10% band, so the band
      // is widened to match rather than scoring the edges of an explicitly
      // acceptable range as a miss.
      amount: fat,
      tolerance: 0.27,
    ),
    'carbs': NutrientTarget(
      nutrientId: 'carbs',
      curveType: TargetCurveType.range,
      amount: carbs.toDouble(),
      tolerance: 0.15,
    ),
    'fibre': NutrientTarget(
      nutrientId: 'fibre',
      curveType: TargetCurveType.floor,
      amount: fibre,
    ),
    // Both limits are fractions of energy rather than fixed grams, so they
    // move with the target the way WHO states them. They are not in the RDA
    // table for the same reason: a table keyed by age and sex cannot express
    // "10% of whatever this person's energy target is".
    'saturated_fat': NutrientTarget(
      nutrientId: 'saturated_fat',
      curveType: TargetCurveType.ceiling,
      amount: energy * 0.10 / 9,
    ),
    'sugar': NutrientTarget(
      nutrientId: 'sugar',
      curveType: TargetCurveType.ceiling,
      amount: energy * 0.10 / 4,
    ),
  };

  for (final reference in rdaReferences) {
    targets[reference.nutrientId] = NutrientTarget(
      nutrientId: reference.nutrientId,
      curveType: _curveFor(reference),
      amount: reference.rdaAmount,
      upperLimit: reference.upperLimit,
    );
  }

  final water = waterTargetMl(profile);

  return DerivedTargets(
    targets: targets,
    waterTargetMl: water,
    bmrKcal: bmr,
    tdeeKcal: tdee,
    safetyFloorApplied: floorApplied,
    goalRefusedForLifestage: refusesDeficit,
    explanations: {
      'energy':
          'Mifflin-St Jeor from your height, weight and age, times your '
          'activity level${effectiveGoal == GoalType.maintain || effectiveGoal == GoalType.generalHealth ? '' : ', adjusted for your goal'}'
          '${increment.energyKcal > 0 ? ', plus ${increment.energyKcal.round()} kcal for ${profile.lifestage.label.toLowerCase()}' : ''}.',
      'protein':
          '$proteinGPerKg g per kg of body weight for ${effectiveGoal.label.toLowerCase()}'
          '${increment.proteinG > 0 ? ', plus ${increment.proteinG} g for ${profile.lifestage.label.toLowerCase()}' : ''}.',
      'fat': '27.5% of your energy target — the middle of the 20-35% range.',
      'carbs': 'Whatever energy is left after protein and fat.',
      'fibre': '14 g per 1,000 kcal.',
      'saturated_fat': 'WHO guidance: under 10% of your energy.',
      'sugar': 'WHO guidance on free sugars: under 10% of your energy.',
      'water': '35 ml per kg of body weight, plus a little for activity.',
    },
  );
}

/// Mifflin-St Jeor (§20.4): better validated in general populations than
/// Harris-Benedict, and unlike Katch-McArdle it needs nothing the user is
/// unlikely to know.
///
/// A profile that declined to state a sex gets the midpoint of the two
/// constants rather than a default to either — the honest reading of "no
/// reference chosen".
double mifflinStJeorBmr(ProfileInputs p) {
  final base = 10 * p.weightKg + 6.25 * p.heightCm - 5 * p.ageYears;
  return switch (p.biologicalSex) {
    BiologicalSex.male => base + 5,
    BiologicalSex.female => base - 161,
    null => base - 78,
  };
}

/// §20.4: ~30-35 ml/kg, adjusted for activity, floored and capped.
///
/// [ASSUMPTION A-5] Hydration needs vary with climate and are poorly
/// characterised. 35 ml/kg is the top of the cited range because the
/// household is in India; the number is easy to override (§27.12).
double waterTargetMl(ProfileInputs p) {
  final activityBonus = switch (p.activityLevel) {
    ActivityLevel.sedentary => 0.0,
    ActivityLevel.light => 150.0,
    ActivityLevel.moderate => 300.0,
    ActivityLevel.active => 500.0,
    ActivityLevel.veryActive => 700.0,
  };
  return (35 * p.weightKg + activityBonus).clamp(1500, 5000);
}

/// §20.4's protein table, capped to plausible ranges.
double _proteinGramsPerKg(GoalType goal) => switch (goal) {
  GoalType.gainMuscle => 1.6,
  GoalType.gainWeight => 1.4,
  GoalType.loseWeight => 1.4,
  _ => 1.2,
};

/// Energy adjustment for the goal, bounded both ways (§20.4, §21.8).
///
/// The rate cap comes first (0.75 kg/week, ~825 kcal/day, well beyond what
/// the 20% deficit cap allows anyway), then the percentage cap, then the
/// absolute floor. A request that hits the floor reports that it did.
(double, bool) _energyForGoal({
  required double tdee,
  required GoalType goal,
  required ProfileInputs profile,
  double? rateKgPerWeek,
}) {
  const maxRateKgPerWeek = 0.75;
  const kcalPerKgBodyMass = 7700;

  final direction = switch (goal) {
    GoalType.loseWeight => -1,
    GoalType.gainWeight || GoalType.gainMuscle => 1,
    _ => 0,
  };
  if (direction == 0) return (tdee, false);

  final requestedRate = (rateKgPerWeek ?? 0.5).abs().clamp(
    0.0,
    maxRateKgPerWeek,
  );
  final fromRate = requestedRate * kcalPerKgBodyMass / 7;
  // §20.4 caps the adjustment at 20% of TDEE regardless of the rate asked
  // for, which is the binding constraint for most people.
  final adjustment = fromRate.clamp(0.0, tdee * 0.20);
  final unclamped = tdee + direction * adjustment;

  final floor = switch (profile.biologicalSex) {
    BiologicalSex.male => minEnergyKcalMale,
    // A profile with no stated sex takes the lower floor, because the
    // floor exists to prevent harm and the cautious reading is the one
    // that leaves more energy on the table, not less.
    _ => minEnergyKcalFemale,
  };
  if (unclamped < floor) return (floor, true);
  return (unclamped, false);
}

/// A reference with an upper limit is a plateau curve; without one it is a
/// plain floor. Sodium is the exception — it is a limit nutrient, scored
/// as a ceiling against WHO's guidance rather than as something to reach.
TargetCurveType _curveFor(RdaReference reference) {
  if (reference.nutrientId == 'sodium' ||
      reference.nutrientId == 'sugar' ||
      reference.nutrientId == 'saturated_fat') {
    return TargetCurveType.ceiling;
  }
  return reference.upperLimit != null
      ? TargetCurveType.plateau
      : TargetCurveType.floor;
}
