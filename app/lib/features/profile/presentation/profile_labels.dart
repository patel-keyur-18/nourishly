import 'package:nourishly_data/nourishly_data.dart' hide NutrientTarget;
import 'package:nutrition_core/nutrition_core.dart';

/// The user-facing words for the profile's enums, in one place.
///
/// `ActivityLevel` carries a concrete *description* ("Light exercise 1–3
/// days a week") because §20.4 warns that adjectives are over-claimed, but a
/// settings row still needs a short name for the value, and a goal still
/// needs the one line that says what choosing it does. Those were written
/// out three times — setup, profile, settings — and had already started to
/// drift apart.
abstract final class ProfileLabels {
  /// The short name, for a row's value. The honest description belongs
  /// underneath it, and is [ActivityLevel.description].
  static String activity(ActivityLevel level) => switch (level) {
    ActivityLevel.sedentary => 'Not very active',
    ActivityLevel.light => 'A little active',
    ActivityLevel.moderate => 'Moderately active',
    ActivityLevel.active => 'Very active',
    ActivityLevel.veryActive => 'Extremely active',
  };

  /// The same, lower-cased for the middle of a sentence — the profile row's
  /// "General health · moderately active".
  static String activityInline(ActivityLevel level) =>
      activity(level).toLowerCase();

  static String goalSubtitle(GoalType goal) => switch (goal) {
    GoalType.maintain => 'Keep things where they are',
    GoalType.loseWeight => 'A bounded deficit, never an aggressive one',
    GoalType.gainWeight => 'A bounded surplus',
    GoalType.gainMuscle => 'More protein, and the score weighs it heavier',
    GoalType.generalHealth => 'Balanced targets, nothing pushed',
    GoalType.hydration => 'Water only — no nutrition setup needed',
  };

  /// FR-U-16's honesty about what a stated diet does and does not do. Said
  /// plainly rather than implied: the catalog records neither root
  /// vegetables nor slaughter method, so these two order results the same
  /// way their nearest recorded neighbour does.
  static String? dietSubtitle(DietaryPreference preference) =>
      switch (preference) {
        DietaryPreference.jain =>
          'Ranked as vegetarian — the catalog does not record root '
              'vegetables',
        DietaryPreference.halal =>
          'The catalog does not record slaughter method, so this does not '
              'reorder anything',
        _ => null,
      };
}
