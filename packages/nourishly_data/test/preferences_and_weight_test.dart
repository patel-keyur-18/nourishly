import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly_data/nourishly_data.dart';
import 'package:nutrition_core/nutrition_core.dart' hide NutrientTarget;

void main() {
  late NourishlyDatabase db;
  late String ownerId;

  setUp(() async {
    db = NourishlyDatabase.forTesting();
    ownerId = await ensureDefaultOwner(db);
    await db.batch((batch) {
      batch.insert(
        db.nutrientGroups,
        NutrientGroupsCompanion.insert(
          id: 'macronutrients',
          name: 'Macronutrients',
          sortOrder: 0,
        ),
      );
      var order = 0;
      for (final id in const ['energy', 'protein', 'carbs', 'fat', 'fibre']) {
        batch.insert(
          db.nutrients,
          NutrientsCompanion.insert(
            id: id,
            groupId: 'macronutrients',
            displayName: id,
            canonicalUnit: id == 'energy' ? 'kcal' : 'g',
            displayPrecision: 0,
            defaultCurveType: 'floor',
            isLimitNutrient: false,
            sortOrder: order++,
            isCore: true,
            minCoverageForScoring: 0.6,
          ),
        );
      }
    });
  });

  tearDown(() => db.close());

  Future<void> setUpProfile({double weightKg = 71}) {
    return ProfileDao(db).saveProfileAndDeriveTargets(
      ownerId: ownerId,
      inputs: ProfileInputs(
        ageYears: 34,
        heightCm: 174,
        weightKg: weightKg,
        activityLevel: ActivityLevel.light,
        biologicalSex: BiologicalSex.male,
      ),
      dateOfBirth: DateTime(1992, 3, 14),
      goal: GoalType.generalHealth,
      effectiveFrom: DateTime.now().subtract(const Duration(days: 30)),
    );
  }

  group('preferences (FR-U-07, FR-U-08, FR-U-09, §21.8)', () {
    test(
      'defaults are created on first read, not at profile creation',
      () async {
        expect(await db.select(db.userPreferences).get(), isEmpty);

        final preferences = await PreferencesDao(db).forOwner(ownerId);

        expect(preferences.showScore, isTrue);
        expect(preferences.hideEnergy, isFalse);
        expect(preferences.weekStartDay, DateTime.monday);
        expect(preferences.dayRolloverTime, 0);
        expect(preferences.unitSystem, 'metric');
        expect(focusNutrientsOf(preferences), hasLength(3));
      },
    );

    test('reading twice does not create a second row', () async {
      await PreferencesDao(db).forOwner(ownerId);
      await PreferencesDao(db).forOwner(ownerId);
      expect(await db.select(db.userPreferences).get(), hasLength(1));
    });

    test('the score can be turned off and energy hidden (§21.8)', () async {
      await PreferencesDao(db)
          .update(ownerId, showScore: false, hideEnergy: true);
      final preferences = await PreferencesDao(db).forOwner(ownerId);
      expect(preferences.showScore, isFalse);
      expect(preferences.hideEnergy, isTrue);
    });

    test('focus nutrients are capped at three (FR-U-09)', () async {
      await PreferencesDao(db).update(
        ownerId,
        focusNutrientIds: ['iron', 'calcium', 'fibre', 'zinc', 'folate'],
      );
      expect(focusNutrientsOf(await PreferencesDao(db).forOwner(ownerId)), [
        'iron',
        'calcium',
        'fibre',
      ]);
    });

    test('a profile can be renamed (FR-U-02)', () async {
      await PreferencesDao(db).renameProfile(ownerId, 'Keyur');
      final user = await (db.select(
        db.users,
      )..where((u) => u.id.equals(ownerId))).getSingle();
      expect(user.displayName, 'Keyur');
    });
  });

  group('day rollover (FR-U-08)', () {
    test('midnight rollover is the plain calendar day', () {
      expect(
        logDateFor(DateTime(2026, 9, 11, 1, 30), rolloverMinutes: 0),
        DateTime(2026, 9, 11),
      );
    });

    test('a 4am rollover puts 1am on the previous day', () {
      // The point of the setting: a late dinner belongs to the day you ate
      // it, not to the calendar.
      expect(
        logDateFor(DateTime(2026, 9, 11, 1, 30), rolloverMinutes: 4 * 60),
        DateTime(2026, 9, 10),
      );
      expect(
        logDateFor(DateTime(2026, 9, 11, 4, 0), rolloverMinutes: 4 * 60),
        DateTime(2026, 9, 11),
      );
      expect(
        logDateFor(DateTime(2026, 9, 11, 23, 0), rolloverMinutes: 4 * 60),
        DateTime(2026, 9, 11),
      );
    });
  });

  group('body weight as a series (FR-U-14)', () {
    test('recording a weight moves the targets from today forward', () async {
      await setUpProfile();
      final before = await ProfileDao(db).targetSetOn(ownerId, DateTime.now());
      final beforeTargets = await ProfileDao(db).targetsIn(before!.id);

      await BodyWeightDao(db).record(ownerId: ownerId, weightKg: 78);

      final after = await ProfileDao(db).targetSetOn(ownerId, DateTime.now());
      final afterTargets = await ProfileDao(db).targetsIn(after!.id);

      expect(after.id, isNot(before.id));
      expect(
        afterTargets['protein']!.amount,
        greaterThan(beforeTargets['protein']!.amount),
      );
      expect(afterTargets['protein']!.amount, closeTo(1.2 * 78, 0.01));
    });

    test(
      'history is newest first and survives a delete as a tombstone',
      () async {
        await setUpProfile();
        final dao = BodyWeightDao(db);
        await dao.record(
          ownerId: ownerId,
          weightKg: 71,
          recordedAt: DateTime(2026, 9, 1),
          rederiveTargets: false,
        );
        await dao.record(
          ownerId: ownerId,
          weightKg: 70,
          recordedAt: DateTime(2026, 9, 8),
          rederiveTargets: false,
        );

        final history = await dao.history(ownerId);
        expect(history.map((e) => e.weightKg), [70, 71]);

        await dao.delete(history.first.id);
        expect((await dao.history(ownerId)).map((e) => e.weightKg), [71]);
        expect(
          await db.select(db.bodyWeightEntries).get(),
          hasLength(2),
          reason: 'soft-deleted, so an export can still see it happened',
        );
      },
    );

    test('a weight with no profile is still recorded', () async {
      final targetSet = await BodyWeightDao(db)
          .record(ownerId: ownerId, weightKg: 71);
      expect(targetSet, isNull);
      expect(await BodyWeightDao(db).history(ownerId), hasLength(1));
    });
  });

  group('manual targets only (Q-27)', () {
    test('freezing copies the numbers into a manual set', () async {
      await setUpProfile();
      final before = await ProfileDao(db).targetSetOn(ownerId, DateTime.now());
      final beforeTargets = await ProfileDao(db).targetsIn(before!.id);

      await ProfileDao(db)
          .setManualTargetsOnly(ownerId: ownerId, enabled: true);

      final set = await ProfileDao(db).targetSetOn(ownerId, DateTime.now());
      final targets = await ProfileDao(db).targetsIn(set!.id);

      expect(set.derivationSource, 'manual');
      expect(await ProfileDao(db).isManualTargetsOnly(ownerId), isTrue);
      expect(
        targets['protein']!.amount,
        beforeTargets['protein']!.amount,
        reason: 'the numbers are frozen where they were, not recomputed',
      );
      expect(
        targets.values.any((t) => t.isUserOverride),
        isFalse,
        reason:
            'the freeze does not claim the user set these by hand — that is '
            'what makes turning it off possible',
      );
    });

    test(
      'a target the user really set stays marked through the toggle',
      () async {
        await setUpProfile();
        await ProfileDao(
          db,
        ).overrideTarget(ownerId: ownerId, nutrientId: 'water', amount: 3200);
        final dao = ProfileDao(db);
        await dao.setManualTargetsOnly(ownerId: ownerId, enabled: true);
        await dao.setManualTargetsOnly(ownerId: ownerId, enabled: false);

        final set = await dao.targetSetOn(ownerId, DateTime.now());
        final targets = await dao.targetsIn(set!.id);
        expect(targets['water']!.isUserOverride, isTrue);
        expect(targets['water']!.amount, 3200);
        expect(targets['protein']!.isUserOverride, isFalse);
      },
    );

    test(
      'a weight change is recorded but does not move frozen targets',
      () async {
        await setUpProfile();
        await ProfileDao(db)
            .setManualTargetsOnly(ownerId: ownerId, enabled: true);
        final frozen = await ProfileDao(db)
            .targetSetOn(ownerId, DateTime.now());
        final frozenTargets = await ProfileDao(db).targetsIn(frozen!.id);

        await BodyWeightDao(db).record(ownerId: ownerId, weightKg: 90);

        final after = await ProfileDao(db).targetSetOn(ownerId, DateTime.now());
        expect(after!.id, frozen.id);
        expect(
          (await ProfileDao(db).targetsIn(after.id))['protein']!.amount,
          frozenTargets['protein']!.amount,
        );
        expect(
          await BodyWeightDao(db).history(ownerId),
          hasLength(1),
          reason: 'the weight itself is still a fact worth keeping',
        );
      },
    );

    test(
      'a profile edit is recorded but does not move frozen targets',
      () async {
        await setUpProfile();
        await ProfileDao(db)
            .setManualTargetsOnly(ownerId: ownerId, enabled: true);
        final frozen = await ProfileDao(db)
            .targetSetOn(ownerId, DateTime.now());

        await setUpProfile(weightKg: 95);

        final after = await ProfileDao(db).targetSetOn(ownerId, DateTime.now());
        expect(after!.id, frozen!.id);
        expect(
          await db.select(db.userProfileVersions).get(),
          hasLength(2),
          reason: 'FR-U-02 still lets you edit the profile itself',
        );
      },
    );

    test('turning it off lets derivation resume', () async {
      await setUpProfile();
      await ProfileDao(db)
          .setManualTargetsOnly(ownerId: ownerId, enabled: true);
      await ProfileDao(db)
          .setManualTargetsOnly(ownerId: ownerId, enabled: false);

      expect(await ProfileDao(db).isManualTargetsOnly(ownerId), isFalse);

      await BodyWeightDao(db).record(ownerId: ownerId, weightKg: 90);
      final set = await ProfileDao(db).targetSetOn(ownerId, DateTime.now());
      expect(
        (await ProfileDao(db).targetsIn(set!.id))['protein']!.amount,
        closeTo(1.2 * 90, 0.01),
      );
    });
  });
}
