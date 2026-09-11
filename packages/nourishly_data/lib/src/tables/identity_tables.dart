import 'package:drift/drift.dart';

import 'common.dart';

/// The local profile that owns a slice of data on this device (§0.4).
///
/// This replaces the account/auth-based `User` entity from §22.5 — there
/// is no server, no email, no password. `account_state` is dropped along
/// with it; a profile that's `deletedAt` is simply gone, with export
/// offered first by the settings UI, not modelled as a state here.
class Users extends Table with Identifiable, Timestamped, SoftDeletable {
  TextColumn get displayName => text()();

  /// A token or hex colour identifying the profile's avatar on the switcher.
  TextColumn get avatarColor => text()();
}

/// An immutable, effective-dated snapshot of the physical attributes that
/// drive target derivation (§22.5). Never updated in place — a change
/// appends a new version, which is what makes historical targets
/// explainable.
class UserProfileVersions extends Table
    with Identifiable, Owned, Timestamped, SoftDeletable {
  DateTimeColumn get effectiveFrom => dateTime()();
  DateTimeColumn get dateOfBirth => dateTime()();

  /// `male` | `female` | null (prefer not to say → neutral reference).
  TextColumn get biologicalSex => text().nullable()();
  RealColumn get heightCm => real()();
  RealColumn get weightKg => real()();

  /// `sedentary` | `light` | `moderate` | `active` | `very_active`.
  TextColumn get activityLevel => text()();

  /// e.g. `adult`, `pregnant`, `lactating` — selects the RDA lifestage row.
  TextColumn get lifestage => text()();

  /// Which `RdaReferences.region` applies, e.g. `IN`.
  TextColumn get regionRef => text()();

  /// `user` | `derived`.
  TextColumn get source => text()();
}

/// The user's stated intent — deliberately separate from [TargetSets]:
/// intent is user-provided, targets are derived from it (§22.5).
class Goals extends Table with Identifiable, Owned, Timestamped, SoftDeletable {
  /// `maintain` | `lose_weight` | `gain_weight` | `gain_muscle` | `general_health`.
  TextColumn get goalType => text()();
  RealColumn get targetWeightKg => real().nullable()();
  RealColumn get targetRateKgPerWeek => real().nullable()();
  DateTimeColumn get effectiveFrom => dateTime()();
  DateTimeColumn get effectiveTo => dateTime().nullable()();
}

/// An immutable, effective-dated collection of nutrient targets in force
/// from a date (§22.5). Never mutated — any change creates a new set, the
/// anchor of historical comparability (I-3, I-4).
class TargetSets extends Table
    with Identifiable, Owned, Timestamped, SoftDeletable {
  DateTimeColumn get effectiveFrom => dateTime()();

  /// `derived` | `manual` | `mixed`.
  TextColumn get derivationSource => text()();
  TextColumn get rulesetVersion => text()();
  TextColumn get derivedFromProfileVersionId => text()
      .nullable()
      .customConstraint('REFERENCES user_profile_versions (id)')();
  TextColumn get derivedFromGoalId =>
      text().nullable().customConstraint('REFERENCES goals (id)')();
  TextColumn get notes => text().nullable()();
}

/// One nutrient's target within a [TargetSets] row (§22.5).
class NutrientTargets extends Table with Identifiable {
  TextColumn get targetSetId =>
      text().customConstraint('NOT NULL REFERENCES target_sets (id)')();
  TextColumn get nutrientId =>
      text().customConstraint('NOT NULL REFERENCES nutrients (id)')();
  RealColumn get targetAmount => real()();
  RealColumn get minAmount => real().nullable()();
  RealColumn get maxAmount => real().nullable()();
  RealColumn get upperLimit => real().nullable()();

  /// `range` | `floor` | `ceiling` | `plateau` — see `TargetCurveType` in
  /// `nutrition_core`.
  TextColumn get curveType => text()();
  RealColumn get tolerance => real()();
  RealColumn get weightHint => real().nullable()();

  /// Lets a manual override survive profile-driven recomputation (FR-U-05).
  BoolColumn get isUserOverride =>
      boolean().withDefault(const Constant(false))();
}

/// Units, display, and behaviour settings — one row per profile (§22.5).
class UserPreferences extends Table with Owned, Timestamped {
  @override
  Set<Column> get primaryKey => {ownerId};

  /// `metric` | `imperial`.
  TextColumn get unitSystem => text()();

  /// `ml` | `L` | `floz_us` | `floz_imp`.
  TextColumn get volumeUnit => text()();
  TextColumn get massUnit => text()();
  TextColumn get heightUnit => text()();
  TextColumn get energyUnit => text()();

  /// ISO day-of-week number, 1 (Monday) - 7 (Sunday).
  IntColumn get weekStartDay => integer()();

  /// Minutes since local midnight at which a "day" rolls over.
  IntColumn get dayRolloverTime => integer()();

  /// JSON-encoded list of nutrient ids pinned to the dashboard (max 3).
  TextColumn get focusNutrientIds => text()();

  /// JSON-encoded list of quick-add water amounts, in millilitres.
  TextColumn get quickAddWaterAmounts => text()();
  BoolColumn get showScore => boolean().withDefault(const Constant(true))();
  BoolColumn get hideEnergy => boolean().withDefault(const Constant(false))();

  /// `light` | `dark` | `system`. Light is the default: the palette was
  /// drawn light-first and it is what the prototype was approved in.
  /// Dark is still first-class (§27.14) — `system` and `dark` are honoured
  /// in full, they are just no longer what a new profile starts on.
  TextColumn get theme => text().withDefault(const Constant('light'))();
  TextColumn get locale => text().withDefault(const Constant('en'))();

  /// `vegetarian` | `vegan` | `eggetarian` | `jain` | `halal` | null
  /// (FR-U-16). Null means not stated, which is the default and stays the
  /// default — the question is skippable.
  ///
  /// A preference rather than a profile attribute: it changes search
  /// ranking and which foods an insight may suggest, not any derived
  /// target, so it does not need effective dating.
  ///
  /// §30.1 counts this as sensitive — a food log already reveals religious
  /// and cultural practice, and this states it outright. In the
  /// personal-use scope that means it stays on the device like everything
  /// else; it is never used to hide a food from search, only to order
  /// results.
  TextColumn get dietaryPreference => text().nullable()();

  /// Whether the one-time welcome has been shown. Separate from "has a
  /// profile", so skipping setup does not mean seeing the welcome again on
  /// every launch.
  BoolColumn get onboardingSeen =>
      boolean().withDefault(const Constant(false))();
}

class BodyWeightEntries extends Table
    with Identifiable, Owned, Timestamped, SoftDeletable {
  DateTimeColumn get recordedAt => dateTime()();
  RealColumn get weightKg => real()();

  /// `manual` | `derived`.
  TextColumn get source => text()();
}
