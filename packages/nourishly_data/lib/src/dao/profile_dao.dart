import 'package:drift/drift.dart';
import 'package:nutrition_core/nutrition_core.dart';
import 'package:uuid/uuid.dart';

// Drift generates row classes named after the table rows, so `NutrientTarget`
// and `RdaReference` collide with nutrition_core's value objects of the same
// name. The core types are the ones this DAO speaks in; the Drift rows are
// reached through inference and their companions.
import '../database.dart' hide NutrientTarget, RdaReference;

const _uuid = Uuid();

/// Reads and writes the profile, its goal, and the target sets derived from
/// them (§22.5, §20.4).
///
/// Nothing here updates in place. A weight change appends a profile
/// version; a goal change closes the old goal and opens a new one; either
/// creates a **new** effective-dated [TargetSets]. That is invariant I-3,
/// and it is the whole reason a report from last month still means what it
/// said: a day is always read against the targets in force on that date,
/// not against today's.
class ProfileDao {
  ProfileDao(this._db);

  final NourishlyDatabase _db;

  Future<UserProfileVersion?> currentProfile(
    String ownerId, {
    DateTime? on,
  }) async {
    final at = on ?? DateTime.now();
    final rows =
        await (_db.select(_db.userProfileVersions)
              ..where(
                (p) =>
                    p.ownerId.equals(ownerId) &
                    p.deletedAt.isNull() &
                    p.effectiveFrom.isSmallerOrEqualValue(at),
              )
              ..orderBy([(p) => OrderingTerm.desc(p.effectiveFrom)])
              ..limit(1))
            .get();
    return rows.isEmpty ? null : rows.first;
  }

  Future<Goal?> currentGoal(String ownerId, {DateTime? on}) async {
    final at = on ?? DateTime.now();
    final rows =
        await (_db.select(_db.goals)
              ..where(
                (g) =>
                    g.ownerId.equals(ownerId) &
                    g.deletedAt.isNull() &
                    g.effectiveFrom.isSmallerOrEqualValue(at),
              )
              ..orderBy([(g) => OrderingTerm.desc(g.effectiveFrom)])
              ..limit(1))
            .get();
    return rows.isEmpty ? null : rows.first;
  }

  /// The target set in force on [on] — the one a day is scored against.
  Future<TargetSet?> targetSetOn(String ownerId, DateTime on) async {
    final rows =
        await (_db.select(_db.targetSets)
              ..where(
                (t) =>
                    t.ownerId.equals(ownerId) &
                    t.deletedAt.isNull() &
                    t.effectiveFrom.isSmallerOrEqualValue(on),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.effectiveFrom)])
              ..limit(1))
            .get();
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, NutrientTarget>> targetsIn(String targetSetId) async {
    final rows = await (_db.select(
      _db.nutrientTargets,
    )..where((t) => t.targetSetId.equals(targetSetId))).get();
    return {
      for (final r in rows)
        r.nutrientId: NutrientTarget(
          nutrientId: r.nutrientId,
          curveType: TargetCurveType.values.byName(r.curveType),
          amount: r.targetAmount,
          upperLimit: r.upperLimit,
          tolerance: r.tolerance,
          isUserOverride: r.isUserOverride,
        ),
    };
  }

  /// The reference rows that apply to a profile (§22.5 `RdaReference`).
  ///
  /// A sex-independent row is used when no sex-specific one matches, which
  /// is also what a profile that declined to state one gets — the neutral
  /// reference §27.1 promises, rather than a silent default to either.
  Future<List<RdaReference>> referencesFor(
    UserProfileVersion profile, {
    required int ageYears,
  }) async {
    final rows =
        await (_db.select(_db.rdaReferences)..where(
              (r) =>
                  r.region.equals(profile.regionRef) &
                  r.lifestage.equals(profile.lifestage) &
                  r.ageMin.isSmallerOrEqualValue(ageYears) &
                  r.ageMax.isBiggerOrEqualValue(ageYears),
            ))
            .get();

    final byNutrient = <String, dynamic>{};
    for (final row in rows) {
      final existing = byNutrient[row.nutrientId];
      final matchesSex = row.sex == profile.biologicalSex;
      if (existing == null ||
          (matchesSex && existing.sex != profile.biologicalSex)) {
        byNutrient[row.nutrientId] = row;
      }
    }
    return [
      for (final row in byNutrient.values)
        RdaReference(
          nutrientId: row.nutrientId,
          rdaAmount: row.rdaAmount,
          upperLimit: row.upperLimit,
          sourceCitation: row.sourceCitation,
        ),
    ];
  }

  /// Appends a profile version, a goal if one is given, and the target set
  /// derived from both — all in one transaction, effective from
  /// [effectiveFrom] (default: the start of today).
  ///
  /// Existing user overrides are carried across by default (FR-U-05): a
  /// person who raised their water target does not expect a weight change
  /// to quietly undo it.
  Future<String> saveProfileAndDeriveTargets({
    required String ownerId,
    required ProfileInputs inputs,
    required DateTime dateOfBirth,
    required GoalType goal,
    double? goalRateKgPerWeek,
    DateTime? effectiveFrom,
    bool keepUserOverrides = true,
  }) async {
    final from = effectiveFrom ?? _startOfToday();
    final profileId = _uuid.v7();
    final goalId = _uuid.v7();
    final targetSetId = _uuid.v7();

    final previousSet = await targetSetOn(ownerId, from);
    final previousOverrides = <String, NutrientTarget>{};
    if (keepUserOverrides && previousSet != null) {
      final previous = await targetsIn(previousSet.id);
      previousOverrides.addAll(
        Map.fromEntries(previous.entries.where((e) => e.value.isUserOverride)),
      );
    }

    await _db.transaction(() async {
      await _db
          .into(_db.userProfileVersions)
          .insert(
            UserProfileVersionsCompanion.insert(
              id: profileId,
              ownerId: ownerId,
              effectiveFrom: from,
              dateOfBirth: dateOfBirth,
              biologicalSex: Value(inputs.biologicalSex?.id),
              heightCm: inputs.heightCm,
              weightKg: inputs.weightKg,
              activityLevel: inputs.activityLevel.id,
              lifestage: inputs.lifestage.id,
              regionRef: inputs.region,
              source: 'user',
            ),
          );

      await _db
          .into(_db.goals)
          .insert(
            GoalsCompanion.insert(
              id: goalId,
              ownerId: ownerId,
              goalType: goal.id,
              targetRateKgPerWeek: Value(goalRateKgPerWeek),
              effectiveFrom: from,
            ),
          );

      final profileRow = await (_db.select(
        _db.userProfileVersions,
      )..where((p) => p.id.equals(profileId))).getSingle();
      final references = await referencesFor(
        profileRow,
        ageYears: inputs.ageYears,
      );

      final derived = deriveTargets(
        profile: inputs,
        goal: goal,
        rdaReferences: references,
        goalRateKgPerWeek: goalRateKgPerWeek,
      );

      await _writeTargetSet(
        targetSetId: targetSetId,
        ownerId: ownerId,
        from: from,
        derived: derived,
        profileVersionId: profileId,
        goalId: goalId,
        overrides: previousOverrides,
      );
    });

    return targetSetId;
  }

  /// Overrides one target from today forward (§27.12). Copies the whole set
  /// rather than editing it, because a target set is immutable — the past
  /// keeps the numbers it was measured against.
  Future<String> overrideTarget({
    required String ownerId,
    required String nutrientId,
    required double amount,
    DateTime? effectiveFrom,
  }) async {
    final from = effectiveFrom ?? _startOfToday();
    final current = await targetSetOn(ownerId, from);
    if (current == null) {
      throw StateError('No target set in force — derive one first.');
    }
    final targets = await targetsIn(current.id);
    final newSetId = _uuid.v7();

    await _db.transaction(() async {
      await _db
          .into(_db.targetSets)
          .insert(
            TargetSetsCompanion.insert(
              id: newSetId,
              ownerId: ownerId,
              effectiveFrom: from,
              derivationSource: 'mixed',
              rulesetVersion: derivationRulesetVersion,
              derivedFromProfileVersionId: Value(
                current.derivedFromProfileVersionId,
              ),
              derivedFromGoalId: Value(current.derivedFromGoalId),
            ),
          );

      await _db.batch((batch) {
        targets.forEach((id, target) {
          final isEdited = id == nutrientId;
          batch.insert(
            _db.nutrientTargets,
            NutrientTargetsCompanion.insert(
              id: _uuid.v7(),
              targetSetId: newSetId,
              nutrientId: id,
              targetAmount: isEdited ? amount : target.amount,
              upperLimit: Value(target.upperLimit),
              curveType: target.curveType.name,
              tolerance: target.tolerance,
              isUserOverride: Value(isEdited || target.isUserOverride),
            ),
          );
        });
      });
    });
    return newSetId;
  }

  /// Drops a user override, putting the derived value back (§27.12's
  /// "reset to derived").
  Future<String> resetTargetToDerived({
    required String ownerId,
    required String nutrientId,
    required ProfileInputs inputs,
    required GoalType goal,
    double? goalRateKgPerWeek,
    DateTime? effectiveFrom,
  }) async {
    final profile = await currentProfile(ownerId);
    final references = profile == null
        ? <RdaReference>[]
        : await referencesFor(profile, ageYears: inputs.ageYears);
    final derived = deriveTargets(
      profile: inputs,
      goal: goal,
      rdaReferences: references,
      goalRateKgPerWeek: goalRateKgPerWeek,
    );
    final derivedAmount = nutrientId == 'water'
        ? derived.waterTargetMl
        : derived.targets[nutrientId]?.amount;
    if (derivedAmount == null) {
      throw StateError('$nutrientId has no derived value to reset to.');
    }
    final setId = await overrideTarget(
      ownerId: ownerId,
      nutrientId: nutrientId,
      amount: derivedAmount,
      effectiveFrom: effectiveFrom,
    );
    await (_db.update(_db.nutrientTargets)..where(
          (t) => t.targetSetId.equals(setId) & t.nutrientId.equals(nutrientId),
        ))
        .write(const NutrientTargetsCompanion(isUserOverride: Value(false)));
    return setId;
  }

  Future<void> _writeTargetSet({
    required String targetSetId,
    required String ownerId,
    required DateTime from,
    required DerivedTargets derived,
    required String profileVersionId,
    required String goalId,
    required Map<String, NutrientTarget> overrides,
  }) async {
    await _db
        .into(_db.targetSets)
        .insert(
          TargetSetsCompanion.insert(
            id: targetSetId,
            ownerId: ownerId,
            effectiveFrom: from,
            derivationSource: overrides.isEmpty ? 'derived' : 'mixed',
            rulesetVersion: derivationRulesetVersion,
            derivedFromProfileVersionId: Value(profileVersionId),
            derivedFromGoalId: Value(goalId),
          ),
        );

    // Water is a target like any other, and lives in the same table so the
    // hydration score reads it the same way everything else is read.
    final all = <String, NutrientTarget>{
      ...derived.targets,
      'water': NutrientTarget(
        nutrientId: 'water',
        curveType: TargetCurveType.floor,
        amount: derived.waterTargetMl,
      ),
    };
    for (final entry in overrides.entries) {
      final existing = all[entry.key];
      all[entry.key] = existing == null
          ? entry.value
          : existing.copyWith(amount: entry.value.amount, isUserOverride: true);
    }

    await _db.batch((batch) {
      all.forEach((id, target) {
        batch.insert(
          _db.nutrientTargets,
          NutrientTargetsCompanion.insert(
            id: _uuid.v7(),
            targetSetId: targetSetId,
            nutrientId: id,
            targetAmount: target.amount,
            upperLimit: Value(target.upperLimit),
            curveType: target.curveType.name,
            tolerance: target.tolerance,
            isUserOverride: Value(target.isUserOverride),
          ),
        );
      });
    });
  }
}

DateTime _startOfToday() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

/// Whole years between [dateOfBirth] and [on], the way a person would say
/// their age.
int ageInYears(DateTime dateOfBirth, {DateTime? on}) {
  final at = on ?? DateTime.now();
  var age = at.year - dateOfBirth.year;
  final hadBirthday =
      at.month > dateOfBirth.month ||
      (at.month == dateOfBirth.month && at.day >= dateOfBirth.day);
  if (!hadBirthday) age -= 1;
  return age;
}
