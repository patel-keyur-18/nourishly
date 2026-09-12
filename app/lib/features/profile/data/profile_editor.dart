import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nourishly_data/nourishly_data.dart' hide NutrientTarget;
import 'package:nutrition_core/nutrition_core.dart';

import '../../../app/providers.dart';
import 'profile_providers.dart';

final profileEditorProvider = Provider<ProfileEditor>(ProfileEditor.new);

/// Changes one field of the profile without walking through setup again.
///
/// Before this existed, the only writer of a profile was the six-step
/// wizard, so "edit your height" meant `/profile/setup` — six screens, a
/// *Use these targets* button at the end, and a trip back to the dashboard
/// whether you wanted one or not. Worse, the wizard started from its own
/// hardcoded defaults rather than from the saved profile, so a user who
/// opened it to change their weight and backed out halfway could come away
/// with someone else's height.
///
/// Each method here reads the profile and goal in force, changes exactly
/// one thing, and writes the result back through
/// [ProfileDao.saveProfileAndDeriveTargets] — so effective dating (I-3) and
/// the carry-over of user overrides (FR-U-05) behave exactly as they do
/// when setup writes them. A change is still a new profile version and a
/// new target set, because that is what makes last month's report still
/// mean what it said.
class ProfileEditor {
  ProfileEditor(this._ref);

  final Ref _ref;

  Future<void> setDateOfBirth(DateTime dateOfBirth) =>
      _edit(dateOfBirth: dateOfBirth);

  /// Null is "prefer not to say", which is a real answer rather than a
  /// missing one: it selects the neutral reference (§27.1).
  Future<void> setBiologicalSex(BiologicalSex? sex) =>
      _edit(biologicalSex: sex, clearBiologicalSex: sex == null);

  Future<void> setHeightCm(double heightCm) => _edit(heightCm: heightCm);

  Future<void> setActivityLevel(ActivityLevel level) =>
      _edit(activityLevel: level);

  Future<void> setGoal(GoalType goal) => _edit(goal: goal);

  /// Weight goes through [BodyWeightDao] rather than straight to the
  /// profile, because FR-U-14 keeps weight as a series: the entry is the
  /// record, and the profile version it appends is the consequence. Doing
  /// it the other way round would move the targets while leaving the chart
  /// showing the old number.
  ///
  /// Returns the new target set id, or null when nothing was re-derived.
  Future<String?> recordWeight(double weightKg) async {
    final ownerId = await _ref.read(defaultOwnerProvider.future);
    final setId = await _ref
        .read(bodyWeightDaoProvider)
        .record(ownerId: ownerId, weightKg: weightKg);
    _invalidate();
    return setId;
  }

  /// FR-U-16. Null clears the stated preference back to "not said".
  Future<void> setDietaryPreference(DietaryPreference? preference) async {
    final ownerId = await _ref.read(defaultOwnerProvider.future);
    await _ref
        .read(preferencesDaoProvider)
        .update(
          ownerId,
          dietaryPreference: preference?.id,
          clearDietaryPreference: preference == null,
        );
    _invalidate();
  }

  Future<void> rename(String name) async {
    final ownerId = await _ref.read(defaultOwnerProvider.future);
    await _ref.read(preferencesDaoProvider).renameProfile(ownerId, name);
    _invalidate();
    _ref.invalidate(profileDisplayNameProvider);
  }

  /// True when there is a profile to edit at all. A skipped setup is a
  /// first-class state (§27.1), so the screen asks before it offers rows
  /// that would have nothing to change.
  Future<bool> hasProfile() async {
    final ownerId = await _ref.read(defaultOwnerProvider.future);
    return await _ref.read(profileDaoProvider).currentProfile(ownerId) != null;
  }

  Future<void> _edit({
    DateTime? dateOfBirth,
    BiologicalSex? biologicalSex,
    bool clearBiologicalSex = false,
    double? heightCm,
    double? weightKg,
    ActivityLevel? activityLevel,
    GoalType? goal,
  }) async {
    final ownerId = await _ref.read(defaultOwnerProvider.future);
    final dao = _ref.read(profileDaoProvider);
    final profile = await dao.currentProfile(ownerId);
    if (profile == null) {
      // Nothing to amend: there is no profile yet, and inventing one from
      // a single field would be worse than asking.
      throw StateError('No profile to edit — set one up first.');
    }
    final currentGoal = await dao.currentGoal(ownerId);
    final birth = dateOfBirth ?? profile.dateOfBirth;

    await dao.saveProfileAndDeriveTargets(
      ownerId: ownerId,
      inputs: ProfileInputs(
        ageYears: ageFromDateOfBirth(birth, now: _ref.read(clockProvider).now()),
        heightCm: heightCm ?? profile.heightCm,
        weightKg: weightKg ?? profile.weightKg,
        activityLevel:
            activityLevel ?? ActivityLevel.fromId(profile.activityLevel),
        biologicalSex: clearBiologicalSex
            ? null
            : biologicalSex ?? BiologicalSex.fromId(profile.biologicalSex),
        lifestage: Lifestage.fromId(profile.lifestage),
        region: profile.regionRef,
      ),
      dateOfBirth: birth,
      goal: goal ?? GoalType.fromId(currentGoal?.goalType ?? 'general_health'),
      goalRateKgPerWeek: currentGoal?.targetRateKgPerWeek,
    );
    _invalidate();
  }

  void _invalidate() => _ref.read(summaryRevisionProvider.notifier).bump();
}

/// Age in whole years, which is what the RDA tables are keyed by.
int ageFromDateOfBirth(DateTime dateOfBirth, {DateTime? now}) {
  final at = now ?? DateTime.now();
  final age = at.year - dateOfBirth.year;
  final beforeBirthday =
      at.month < dateOfBirth.month ||
      (at.month == dateOfBirth.month && at.day < dateOfBirth.day);
  return beforeBirthday ? age - 1 : age;
}
