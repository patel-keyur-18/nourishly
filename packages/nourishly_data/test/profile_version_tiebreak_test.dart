import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly_data/nourishly_data.dart';
import 'package:nutrition_core/nutrition_core.dart' hide NutrientTarget;

/// Two changes on one day.
///
/// Every profile version and every goal is effective from a **midnight**
/// (I-3 — a day is read against the targets in force on that date), so two
/// edits on the same day share one `effectiveFrom`. `targetSetOn` already
/// broke that tie by creation order and said why; `currentProfile` and
/// `currentGoal` did not, so which version was "current" was whatever
/// SQLite happened to return — and the second change of the day could
/// silently do nothing.
///
/// That only became reachable when single fields became editable from the
/// profile screen: before it, the one writer was six-step setup, which
/// nobody ran twice in an afternoon.
void main() {
  late NourishlyDatabase db;
  late String ownerId;

  setUp(() async {
    db = NourishlyDatabase.forTesting();
    ownerId = await ensureDefaultOwner(db);
  });

  tearDown(() => db.close());

  Future<void> save({
    required double heightCm,
    required ActivityLevel activity,
    required GoalType goal,
  }) {
    return ProfileDao(db).saveProfileAndDeriveTargets(
      ownerId: ownerId,
      inputs: ProfileInputs(
        ageYears: 34,
        heightCm: heightCm,
        weightKg: 78,
        activityLevel: activity,
        biologicalSex: BiologicalSex.male,
      ),
      dateOfBirth: DateTime(1992, 3, 14),
      goal: goal,
    );
  }

  test('the last profile version written today is the current one', () async {
    await save(
      heightCm: 181,
      activity: ActivityLevel.moderate,
      goal: GoalType.gainMuscle,
    );
    await save(
      heightCm: 176,
      activity: ActivityLevel.moderate,
      goal: GoalType.gainMuscle,
    );

    final current = await ProfileDao(db).currentProfile(ownerId);
    expect(current!.heightCm, 176);
    // Both versions are kept: a version is a record, not an overwrite.
    expect(await db.select(db.userProfileVersions).get(), hasLength(2));
  });

  test('a third change on the same day still wins', () async {
    await save(
      heightCm: 181,
      activity: ActivityLevel.moderate,
      goal: GoalType.gainMuscle,
    );
    await save(
      heightCm: 176,
      activity: ActivityLevel.moderate,
      goal: GoalType.gainMuscle,
    );
    await save(
      heightCm: 176,
      activity: ActivityLevel.active,
      goal: GoalType.gainMuscle,
    );

    final current = await ProfileDao(db).currentProfile(ownerId);
    expect(current!.activityLevel, ActivityLevel.active.id);
    expect(current.heightCm, 176);
  });

  test('the last goal written today is the current one', () async {
    await save(
      heightCm: 181,
      activity: ActivityLevel.moderate,
      goal: GoalType.gainMuscle,
    );
    await save(
      heightCm: 181,
      activity: ActivityLevel.moderate,
      goal: GoalType.loseWeight,
    );

    final goal = await ProfileDao(db).currentGoal(ownerId);
    expect(goal!.goalType, GoalType.loseWeight.id);
  });

  test('yesterday still reads yesterday, not today (I-3)', () async {
    await ProfileDao(db).saveProfileAndDeriveTargets(
      ownerId: ownerId,
      inputs: const ProfileInputs(
        ageYears: 34,
        heightCm: 181,
        weightKg: 78,
        activityLevel: ActivityLevel.moderate,
        biologicalSex: BiologicalSex.male,
      ),
      dateOfBirth: DateTime(1992, 3, 14),
      goal: GoalType.gainMuscle,
      effectiveFrom: DateTime.now().subtract(const Duration(days: 2)),
    );
    await save(
      heightCm: 176,
      activity: ActivityLevel.moderate,
      goal: GoalType.gainMuscle,
    );

    final yesterday = await ProfileDao(db).currentProfile(
      ownerId,
      on: DateTime.now().subtract(const Duration(days: 1)),
    );
    expect(
      yesterday!.heightCm,
      181,
      reason: 'a tiebreak on creation order must not reach back past a date',
    );
  });
}
