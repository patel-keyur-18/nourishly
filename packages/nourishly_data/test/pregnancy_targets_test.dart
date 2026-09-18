import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly_data/nourishly_data.dart' hide NutrientTarget;
import 'package:nutrition_core/nutrition_core.dart';

/// End to end for the pregnancy lifestage: the profile stores a due date,
/// the stage follows from it, and the targets that come out are the
/// pregnancy ones where the data says so and the adult ones everywhere
/// else.
///
/// The fallback is the part worth pinning. The RDA asset states only the
/// nutrients whose requirement actually changes, so a missing lifestage
/// row has to mean "unchanged" — if it ever meant "no row matched", that
/// nutrient would silently drop out of the target set and out of the
/// score, which looks exactly like a nutrient nobody needs.
void main() {
  late NourishlyDatabase db;
  late String ownerId;
  late ProfileDao dao;

  const rda = '''
  {
    "rulesetVersion": "test-1",
    "region": "IN",
    "sourceCitation": "ICMR-NIN 2020",
    "references": [
      {"nutrientId": "iron", "sex": "female", "ageMin": 19, "ageMax": 120,
       "rdaAmount": 29, "unit": "mg"},
      {"nutrientId": "iron", "lifestage": "pregnant_t2", "sex": "female",
       "ageMin": 19, "ageMax": 120, "rdaAmount": 27, "unit": "mg"},
      {"nutrientId": "folate", "sex": null, "ageMin": 19, "ageMax": 120,
       "rdaAmount": 300, "unit": "ug"},
      {"nutrientId": "folate", "lifestage": "pregnant_t2", "sex": null,
       "ageMin": 19, "ageMax": 120, "rdaAmount": 570, "unit": "ug"},
      {"nutrientId": "calcium", "sex": null, "ageMin": 19, "ageMax": 120,
       "rdaAmount": 1000, "unit": "mg"}
    ]
  }
  ''';

  setUp(() async {
    db = NourishlyDatabase.forTesting();
    ownerId = await ensureDefaultOwner(db);
    dao = ProfileDao(db);
    await RdaImporter(db).importFromString(rda);
  });

  tearDown(() => db.close());

  Future<UserProfileVersion> profileWith({
    required DateTime? dueDate,
    required Lifestage lifestage,
    required DateTime on,
  }) async {
    await dao.saveProfileAndDeriveTargets(
      ownerId: ownerId,
      inputs: ProfileInputs(
        ageYears: 31,
        heightCm: 162,
        weightKg: 58,
        activityLevel: ActivityLevel.light,
        biologicalSex: BiologicalSex.female,
        lifestage: lifestage,
        dueDate: dueDate,
      ),
      dateOfBirth: DateTime(1995, 4, 2),
      goal: GoalType.maintain,
      effectiveFrom: on,
    );
    return (await dao.currentProfile(ownerId, on: on))!;
  }

  test(
    'a pregnancy row wins, and everything else falls back to adult',
    () async {
      final profile = await profileWith(
        dueDate: DateTime(2027, 3, 1),
        lifestage: Lifestage.pregnantT2,
        on: DateTime(2026, 9, 18),
      );

      final references = await dao.referencesFor(profile, ageYears: 31);
      final byId = {for (final r in references) r.nutrientId: r.rdaAmount};

      expect(byId['iron'], 27, reason: 'the pregnancy row, not the adult 29');
      expect(byId['folate'], 570);
      expect(
        byId['calcium'],
        1000,
        reason: 'no pregnancy row for calcium means unchanged, never missing',
      );
      expect(references.map((r) => r.nutrientId).toSet(), {
        'iron',
        'folate',
        'calcium',
      });
    },
  );

  test('an adult profile never picks up a pregnancy row', () async {
    final profile = await profileWith(
      dueDate: null,
      lifestage: Lifestage.adult,
      on: DateTime(2026, 9, 18),
    );

    final references = await dao.referencesFor(profile, ageYears: 31);
    final byId = {for (final r in references) r.nutrientId: r.rdaAmount};
    expect(byId['iron'], 29);
    expect(byId['folate'], 300);
  });

  group('advanceLifestageIfDue', () {
    test('moves the stage on when the due date says so, and writes a new '
        'effective-dated target set', () async {
      final due = DateTime(2027, 3, 1);
      // 20 weeks along: second trimester.
      await profileWith(
        dueDate: due,
        lifestage: Lifestage.pregnantT2,
        on: DateTime(2026, 10, 12),
      );

      // 30 weeks along: third.
      final moved = await dao.advanceLifestageIfDue(
        ownerId: ownerId,
        on: DateTime(2026, 12, 21),
      );

      expect(moved, Lifestage.pregnantT3);
      final now = await dao.currentProfile(ownerId, on: DateTime(2026, 12, 21));
      expect(now!.lifestage, Lifestage.pregnantT3.id);
      expect(now.dueDate, due, reason: 'the date itself is carried forward');

      // I-3: the earlier version is still there, so a report from October
      // is still read against October's targets.
      final earlier = await dao.currentProfile(
        ownerId,
        on: DateTime(2026, 10, 20),
      );
      expect(earlier!.lifestage, Lifestage.pregnantT2.id);
    });

    test('does nothing on a second call the same day', () async {
      await profileWith(
        dueDate: DateTime(2027, 3, 1),
        lifestage: Lifestage.pregnantT2,
        on: DateTime(2026, 10, 12),
      );

      final at = DateTime(2026, 12, 21);
      expect(
        await dao.advanceLifestageIfDue(ownerId: ownerId, on: at),
        Lifestage.pregnantT3,
      );
      expect(
        await dao.advanceLifestageIfDue(ownerId: ownerId, on: at),
        isNull,
        reason:
            'this runs on every launch and resume; it must not append '
            'a profile version each time',
      );
    });

    test('a profile with no due date is left alone', () async {
      await profileWith(
        dueDate: null,
        lifestage: Lifestage.adult,
        on: DateTime(2026, 9, 18),
      );
      expect(
        await dao.advanceLifestageIfDue(
          ownerId: ownerId,
          on: DateTime(2027, 9, 18),
        ),
        isNull,
      );
    });
  });

  test('a pregnancy profile is refused an energy deficit', () async {
    await dao.saveProfileAndDeriveTargets(
      ownerId: ownerId,
      inputs: const ProfileInputs(
        ageYears: 31,
        heightCm: 162,
        weightKg: 58,
        activityLevel: ActivityLevel.light,
        biologicalSex: BiologicalSex.female,
        lifestage: Lifestage.pregnantT3,
      ),
      dateOfBirth: DateTime(1995, 4, 2),
      goal: GoalType.loseWeight,
      effectiveFrom: DateTime(2026, 9, 18),
    );

    final set = await dao.targetSetOn(ownerId, DateTime(2026, 9, 18));
    final targets = await dao.targetsIn(set!.id);
    final maintain = deriveTargets(
      profile: const ProfileInputs(
        ageYears: 31,
        heightCm: 162,
        weightKg: 58,
        activityLevel: ActivityLevel.light,
        biologicalSex: BiologicalSex.female,
        lifestage: Lifestage.pregnantT3,
      ),
      goal: GoalType.maintain,
    );

    expect(targets['energy']!.amount, closeTo(maintain.energyKcal, 0.001));
  });

  test('the stored due date survives recording a weight', () async {
    // Weight is the field a pregnant profile changes most often, and
    // recording one re-derives every target — so it is the likeliest
    // place for the pregnancy to be dropped on the floor. It did: the
    // inputs were rebuilt field by field and `dueDate` was not among
    // them, which ended the pregnancy and froze the lifestage, since the
    // launch-time advance has nothing left to read.
    // Whole days: the column stores seconds, so a `DateTime.now()` carried
    // straight through would come back rounded and compare unequal.
    final today = DateTime.now();
    final due = DateTime(today.year, today.month, today.day + 120);
    await profileWith(
      dueDate: due,
      lifestage: lifestageOn(today, due),
      on: DateTime(today.year, today.month, today.day - 1),
    );

    await BodyWeightDao(db).record(ownerId: ownerId, weightKg: 60);

    final profile = await dao.currentProfile(ownerId);
    expect(
      profile!.dueDate,
      due,
      reason: 'recording a weight must not clear the pregnancy',
    );
    expect(profile.weightKg, 60);
    expect(profile.lifestage, lifestageOn(today, due).id);
  });
}
