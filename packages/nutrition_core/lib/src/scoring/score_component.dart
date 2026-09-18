import 'package:meta/meta.dart';

/// The five things a day is scored on (§21.4). Sub-scores are the product;
/// the composite over them is a convenience (§21.1).
enum ScoreComponentKey {
  energyAdherence('energy', 'Energy adherence'),
  macroBalance('macros', 'Macro balance'),
  micronutrientCoverage('micros', 'Micronutrients'),
  limitNutrients('limits', 'Limit nutrients'),
  hydration('hydration', 'Hydration');

  const ScoreComponentKey(this.id, this.label);

  final String id;
  final String label;

  static ScoreComponentKey fromId(String id) =>
      values.firstWhere((k) => k.id == id);
}

/// What the user is trying to do (§22.5 `Goal.goal_type`). Drives both
/// target derivation (§20.4) and score weighting (§21.4).
enum GoalType {
  maintain('maintain', 'Maintain weight'),
  loseWeight('lose_weight', 'Lose weight'),
  gainWeight('gain_weight', 'Gain weight'),
  gainMuscle('gain_muscle', 'Build muscle'),
  generalHealth('general_health', 'General health'),

  /// Persona 4: water only. §21.4 gives this its own weighting column, and
  /// §27.7 requires the water flow to work with no nutrition setup at all.
  hydration('hydration', 'Hydration only');

  const GoalType(this.id, this.label);

  final String id;
  final String label;

  static GoalType fromId(String id) =>
      values.firstWhere((g) => g.id == id, orElse: () => generalHealth);
}

/// How the five components are weighted, keyed by goal (§21.4's table).
///
/// [ASSUMPTION A-7] These are a considered starting point, not an
/// evidence-based derivation, and §37 asks for a qualified review before
/// launch. They are data so that review can change them without touching
/// the engine, and `rulesetVersion` records which set a day was scored
/// under.
@immutable
class ScoreWeights {
  const ScoreWeights(this._byComponent, {required this.macroSubWeights});

  /// §21.4's default column.
  static const ScoreWeights standard = ScoreWeights({
    ScoreComponentKey.energyAdherence: 0.25,
    ScoreComponentKey.macroBalance: 0.30,
    ScoreComponentKey.micronutrientCoverage: 0.20,
    ScoreComponentKey.limitNutrients: 0.15,
    ScoreComponentKey.hydration: 0.10,
  }, macroSubWeights: _standardMacros);

  /// §21.4's "muscle gain" column — macro-heavy and protein-dominant.
  static const ScoreWeights muscleGain = ScoreWeights({
    ScoreComponentKey.energyAdherence: 0.20,
    ScoreComponentKey.macroBalance: 0.40,
    ScoreComponentKey.micronutrientCoverage: 0.15,
    ScoreComponentKey.limitNutrients: 0.10,
    ScoreComponentKey.hydration: 0.15,
  }, macroSubWeights: _proteinDominantMacros);

  /// §21.4's "hydration" column — for the profile that tracks water and
  /// little else.
  static const ScoreWeights hydrationFocused = ScoreWeights({
    ScoreComponentKey.energyAdherence: 0.10,
    ScoreComponentKey.macroBalance: 0.15,
    ScoreComponentKey.micronutrientCoverage: 0.10,
    ScoreComponentKey.limitNutrients: 0.10,
    ScoreComponentKey.hydration: 0.55,
  }, macroSubWeights: _standardMacros);

  /// Within the macro component. §21.4 says the four are "sub-weighted"
  /// but does not give the split; protein leads because it is the macro
  /// most often short in this household's cuisine, and fibre follows for
  /// the same reason.
  static const Map<String, double> _standardMacros = {
    'protein': 0.35,
    'fibre': 0.25,
    'fat': 0.20,
    'carbs': 0.20,
  };

  static const Map<String, double> _proteinDominantMacros = {
    'protein': 0.55,
    'fibre': 0.20,
    'fat': 0.125,
    'carbs': 0.125,
  };

  static ScoreWeights forGoal(GoalType goal) => switch (goal) {
    GoalType.gainMuscle => muscleGain,
    GoalType.hydration => hydrationFocused,
    _ => standard,
  };

  final Map<ScoreComponentKey, double> _byComponent;
  final Map<String, double> macroSubWeights;

  double operator [](ScoreComponentKey key) => _byComponent[key] ?? 0;

  Map<ScoreComponentKey, double> get all => Map.unmodifiable(_byComponent);
}

/// Why a component was left out of the composite. Never silent — §21.4
/// requires the UI to state which components were excluded.
enum ScoreExclusion {
  /// Fewer than 60% of scorable micros cleared the coverage gate (§21.5).
  insufficientCoverage('insufficient_coverage'),

  /// The component has no target to score against — a profile that skipped
  /// nutrition setup, or a nutrient nothing logged reports.
  noTarget('no_target'),

  /// Nothing was logged for it at all.
  noData('no_data');

  const ScoreExclusion(this.id);

  final String id;
}

/// One component's contribution to the day, kept whole so the report can
/// show its weight, its value, and its exclusion reason (§27.8 item 3).
@immutable
class ScoredComponent {
  const ScoredComponent({
    required this.key,
    required this.score,
    required this.weight,
    required this.appliedWeight,
    this.exclusion,
  });

  final ScoreComponentKey key;

  /// Null when [exclusion] is set.
  final double? score;

  /// The weight this component carries in the ruleset.
  final double weight;

  /// The weight it actually carried today, after excluded components had
  /// theirs redistributed. Zero for an excluded component.
  final double appliedWeight;

  final ScoreExclusion? exclusion;

  bool get wasExcluded => exclusion != null;
}
