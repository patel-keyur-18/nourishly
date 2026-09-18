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

/// Selects the RDA row, and the energy and protein increments on top of
/// it (§20.4).
///
/// Split by trimester and by stage of lactation because the requirements
/// are: the additional energy of a third trimester is not the additional
/// energy of a first, and treating them as one number is wrong for six
/// months out of nine. Nobody picks one of these directly — they follow
/// from a due date, through [lifestageOn].
enum Lifestage {
  adult('adult', 'Adult'),
  pregnantT1('pregnant_t1', 'First trimester'),
  pregnantT2('pregnant_t2', 'Second trimester'),
  pregnantT3('pregnant_t3', 'Third trimester'),
  lactating0to6('lactating_0_6', 'Nursing, first 6 months'),
  lactating7to12('lactating_7_12', 'Nursing, 6-12 months');

  const Lifestage(this.id, this.label);

  final String id;

  /// What the profile and goals screens call this stage.
  final String label;

  bool get isPregnant =>
      this == pregnantT1 || this == pregnantT2 || this == pregnantT3;

  bool get isLactating => this == lactating0to6 || this == lactating7to12;

  /// True while the app must not derive an energy deficit, whatever goal
  /// is set (§21.8's safety stance, extended).
  bool get refusesDeficit => isPregnant || isLactating;

  static Lifestage fromId(String id) => switch (id) {
    // Written by an app version that had one value for the whole of
    // pregnancy and one for the whole of lactation. The middle of each is
    // the honest reading of a stage that was never recorded, and a due
    // date set afterwards replaces it on the next launch anyway.
    'pregnant' => pregnantT2,
    'lactating' => lactating0to6,
    _ => values.firstWhere((l) => l.id == id, orElse: () => adult),
  };
}

/// A full-term pregnancy, counted from the last menstrual period — the
/// convention every trimester boundary below is stated in.
const int gestationDays = 280;

/// Which lifestage a due date puts someone in on [date] (FR-U-17).
///
/// This is the whole reason the app asks for a due date instead of a
/// trimester: a setting somebody has to change at week 14 and again at
/// week 28 is a setting that gets forgotten, and a forgotten one means
/// weeks of micronutrient targets that are quietly wrong — exactly the
/// failure planning a week ahead is meant to prevent.
///
/// Boundaries follow the standard obstetric weeks: trimester 1 is weeks
/// 0-13, trimester 2 is 14-27, trimester 3 is 28 to birth. After the due
/// date it moves through the two lactation stages and then back to
/// [Lifestage.adult] — a year on, nothing here applies any more, and
/// continuing to add 500 kcal a day because a date was never cleared is
/// its own kind of wrong.
Lifestage lifestageOn(DateTime date, DateTime dueDate) {
  final daysUntilDue = _dateOnly(dueDate).difference(_dateOnly(date)).inDays;
  final gestationalDay = gestationDays - daysUntilDue;

  if (gestationalDay < 0) return Lifestage.adult;
  if (daysUntilDue > 0) {
    if (gestationalDay < 14 * 7) return Lifestage.pregnantT1;
    if (gestationalDay < 28 * 7) return Lifestage.pregnantT2;
    return Lifestage.pregnantT3;
  }

  final daysSinceBirth = -daysUntilDue;
  if (daysSinceBirth < 183) return Lifestage.lactating0to6;
  if (daysSinceBirth < 365) return Lifestage.lactating7to12;
  return Lifestage.adult;
}

/// Completed weeks of gestation on [date], for display. Null once the due
/// date has passed.
int? gestationalWeeksOn(DateTime date, DateTime dueDate) {
  final daysUntilDue = _dateOnly(dueDate).difference(_dateOnly(date)).inDays;
  if (daysUntilDue <= 0) return null;
  final gestationalDay = gestationDays - daysUntilDue;
  return gestationalDay < 0 ? null : gestationalDay ~/ 7;
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

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
    this.dueDate,
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

  /// The date [lifestage] was derived from, kept so it can be re-derived
  /// as the weeks pass. Null for everyone not pregnant or nursing.
  final DateTime? dueDate;

  final String region;

  ProfileInputs copyWith({Lifestage? lifestage}) => ProfileInputs(
    ageYears: ageYears,
    heightCm: heightCm,
    weightKg: weightKg,
    activityLevel: activityLevel,
    biologicalSex: biologicalSex,
    lifestage: lifestage ?? this.lifestage,
    dueDate: dueDate,
    region: region,
  );
}
