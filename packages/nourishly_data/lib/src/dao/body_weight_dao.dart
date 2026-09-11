import 'package:drift/drift.dart';
import 'package:nutrition_core/nutrition_core.dart';
import 'package:uuid/uuid.dart';

import '../database.dart' hide NutrientTarget;
import 'profile_dao.dart';

const _uuid = Uuid();

/// Body weight as a series (FR-U-14), and the bridge from a new weight to
/// new targets.
///
/// Weight is a series and not a judgement (§21.8): no BMI category, no
/// verdict, just the numbers over time. Recording one also appends a
/// profile version, because energy, protein and water all key off body
/// weight — and appending is what keeps yesterday's report measured
/// against yesterday's targets (I-3).
class BodyWeightDao {
  BodyWeightDao(this._db);

  final NourishlyDatabase _db;

  Future<List<BodyWeightEntry>> history(String ownerId, {int limit = 60}) {
    return (_db.select(_db.bodyWeightEntries)
          ..where((w) => w.ownerId.equals(ownerId) & w.deletedAt.isNull())
          ..orderBy([(w) => OrderingTerm.desc(w.recordedAt)])
          ..limit(limit))
        .get();
  }

  Stream<List<BodyWeightEntry>> watch(String ownerId, {int limit = 60}) {
    return (_db.select(_db.bodyWeightEntries)
          ..where((w) => w.ownerId.equals(ownerId) & w.deletedAt.isNull())
          ..orderBy([(w) => OrderingTerm.desc(w.recordedAt)])
          ..limit(limit))
        .watch();
  }

  Future<BodyWeightEntry?> latest(String ownerId) async {
    final rows = await history(ownerId, limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  /// Records a weight and, unless [rederiveTargets] is false, appends a
  /// profile version so the targets follow it from today.
  ///
  /// Returns the new target set id, or null when nothing was re-derived —
  /// either because the caller asked not to, or because there is no
  /// profile to re-derive from yet.
  Future<String?> record({
    required String ownerId,
    required double weightKg,
    DateTime? recordedAt,
    bool rederiveTargets = true,
  }) async {
    final at = recordedAt ?? DateTime.now();
    await _db
        .into(_db.bodyWeightEntries)
        .insert(
          BodyWeightEntriesCompanion.insert(
            id: _uuid.v7(),
            ownerId: ownerId,
            recordedAt: at,
            weightKg: weightKg,
            source: 'manual',
          ),
        );

    if (!rederiveTargets) return null;

    final dao = ProfileDao(_db);
    final profile = await dao.currentProfile(ownerId);
    if (profile == null) return null;

    // A target set marked fully manual is left alone: the whole point of
    // that mode is that the app stops computing targets for you (Q-27).
    final currentSet = await dao.targetSetOn(ownerId, DateTime.now());
    if (currentSet?.derivationSource == 'manual') return null;

    final goalRow = await dao.currentGoal(ownerId);
    return dao.saveProfileAndDeriveTargets(
      ownerId: ownerId,
      inputs: ProfileInputs(
        ageYears: ageInYears(profile.dateOfBirth),
        heightCm: profile.heightCm,
        weightKg: weightKg,
        activityLevel: ActivityLevel.fromId(profile.activityLevel),
        biologicalSex: BiologicalSex.fromId(profile.biologicalSex),
        lifestage: Lifestage.fromId(profile.lifestage),
        region: profile.regionRef,
      ),
      dateOfBirth: profile.dateOfBirth,
      goal: goalRow == null
          ? GoalType.generalHealth
          : GoalType.fromId(goalRow.goalType),
      goalRateKgPerWeek: goalRow?.targetRateKgPerWeek,
    );
  }

  Future<void> delete(String entryId) {
    return (_db.update(_db.bodyWeightEntries)
          ..where((w) => w.id.equals(entryId)))
        .write(BodyWeightEntriesCompanion(deletedAt: Value(DateTime.now())));
  }
}
