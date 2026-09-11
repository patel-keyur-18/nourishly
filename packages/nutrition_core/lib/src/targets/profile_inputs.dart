import 'package:meta/meta.dart';

/// Which reference values apply. Not a statement about identity — §27.1's
/// copy asks "which reference values should we use?" and offers a neutral
/// option, because that is the only thing the app needs to know.
enum BiologicalSex {
  female('female'),
  male('male');

  const BiologicalSex(this.id);

  final String id;

  static BiologicalSex? fromId(String? id) =>
      id == null ? null : values.firstWhere((s) => s.id == id);
}

/// Self-reported activity, described concretely because §20.4 warns that
/// adjectives ("moderate") are systematically over-claimed.
enum ActivityLevel {
  sedentary('sedentary', 'Desk job, little or no exercise', 1.2),
  light('light', 'Light exercise 1-3 days a week', 1.375),
  moderate('moderate', 'Moderate exercise 3-5 days a week', 1.55),
  active('active', 'Hard exercise 6-7 days a week', 1.725),
  veryActive('very_active', 'Physical job, or twice-daily training', 1.9);

  const ActivityLevel(this.id, this.description, this.pal);

  final String id;
  final String description;

  /// Physical activity level multiplier applied to BMR (§20.4).
  final double pal;

  static ActivityLevel fromId(String id) =>
      values.firstWhere((a) => a.id == id, orElse: () => sedentary);
}

/// Selects the RDA row. Pregnancy and lactation materially change
/// micronutrient targets and are out of scope for v1.0 (§20.4, A-6) — the
/// vocabulary exists so the data model does not have to change when they
/// arrive, and so a profile can be marked manual-targets-only.
enum Lifestage {
  adult('adult'),
  pregnant('pregnant'),
  lactating('lactating');

  const Lifestage(this.id);

  final String id;

  static Lifestage fromId(String id) =>
      values.firstWhere((l) => l.id == id, orElse: () => adult);
}

/// The physical attributes target derivation reads (§22.5
/// `UserProfileVersion`). Immutable and effective-dated in storage; this is
/// the pure-Dart view of one version of it.
@immutable
class ProfileInputs {
  const ProfileInputs({
    required this.ageYears,
    required this.heightCm,
    required this.weightKg,
    required this.activityLevel,
    this.biologicalSex,
    this.lifestage = Lifestage.adult,
    this.region = 'IN',
  });

  final int ageYears;
  final double heightCm;
  final double weightKg;
  final ActivityLevel activityLevel;

  /// Null means "prefer not to say", which uses a neutral reference — the
  /// mean of the male and female constants rather than a default to either.
  final BiologicalSex? biologicalSex;

  final Lifestage lifestage;
  final String region;
}
