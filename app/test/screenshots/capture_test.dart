@Tags(['screenshots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly/app/app.dart';
import 'package:nourishly/app/router.dart';
import 'package:nourishly/features/food_catalog/data/food_catalog_providers.dart';

import 'package:nourishly_data/nourishly_data.dart';
import 'package:nutrition_core/nutrition_core.dart' hide NutrientTarget;
import 'package:drift/drift.dart' show Value, InsertMode;

/// Renders each Phase 3 screen at iPhone-13 size and writes a PNG, so the
/// result can be held next to `docs/design/prototype.html` rather than
/// taken on trust.
///
/// Tagged so it does not run in CI: it writes files, and a screenshot is a
/// review artefact rather than an assertion. Run it with
/// `flutter test --tags screenshots`.
///
/// `captureImage` must be inside `tester.runAsync()`: outside it, the
/// second capture in a file deadlocks waiting on a frame the fake async
/// zone will never produce.
void main() {
  const outputDir = 'build/screenshots';
  // iPhone 13 logical size — the device this is actually tested on.
  const size = Size(390, 844);

  late NourishlyDatabase db;
  late String ownerId;

  setUpAll(() async {
    // Without this every glyph renders as a filled box (flutter_test's
    // default font), which makes a screenshot useless for judging a design
    // and makes every overflow warning a false positive — the test font is
    // full-width for every character, so text measures far wider than it
    // ever will on a phone.
    for (final family in const ['IBM Plex Sans', 'IBM Plex Mono']) {
      final loader = FontLoader(family);
      for (final path in const [
        '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
        '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',
      ]) {
        loader.addFont(
          Future.value(File(path).readAsBytesSync().buffer.asByteData()),
        );
      }
      await loader.load();
    }
  });

  setUp(() async {
    Directory(outputDir).createSync(recursive: true);
    db = NourishlyDatabase.forTesting();
    ownerId = await ensureDefaultOwner(db);
    await _seedReferenceData(db);
    await _seedProfile(db, ownerId);
    await _seedDay(db, ownerId);
  });

  tearDown(() => db.close());

  final captureKey = GlobalKey();

  Future<void> pump(WidgetTester tester, String location) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nourishlyDatabaseProvider.overrideWithValue(db),
          catalogReadyProvider.overrideWith((ref) async {}),
        ],
        child: RepaintBoundary(key: captureKey, child: const NourishlyApp()),
      ),
    );
    await tester.pumpAndSettle();
    appRouter.go(location);
    await tester.pumpAndSettle();
  }

  Future<void> shoot(WidgetTester tester, String name) async {
    await tester.runAsync(() async {
      // The boundary wraps the whole app rather than being looked up
      // inside it: a route pushed on the root navigator (the report, the
      // goals screen, setup) sits *above* the shell, so hunting for the
      // first boundary in the tree captures the tab underneath it.
      final boundary =
          captureKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$outputDir/$name.png')
          .writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  testWidgets('dashboard', (tester) async {
    await pump(tester, '/today');
    await shoot(tester, '01-dashboard');
  });

  testWidgets('daily report', (tester) async {
    await pump(tester, '/today/report');
    await shoot(tester, '02-daily-report');
  });

  testWidgets('goals and targets', (tester) async {
    await pump(tester, '/profile/goals');
    await shoot(tester, '03-goals');
  });

  testWidgets('profile setup', (tester) async {
    await pump(tester, '/profile/setup');
    await shoot(tester, '04-profile-setup');
  });
}

Future<void> _seedReferenceData(NourishlyDatabase db) async {
  await db.batch((batch) {
    for (final (id, name, order) in const [
      ('macronutrients', 'Macronutrients', 0),
      ('minerals', 'Minerals', 1),
      ('vitamins', 'Vitamins', 2),
    ]) {
      batch.insert(
        db.nutrientGroups,
        NutrientGroupsCompanion.insert(id: id, name: name, sortOrder: order),
      );
    }
    var order = 0;
    for (final (id, name, unit, group) in const [
      ('energy', 'Energy', 'kcal', 'macronutrients'),
      ('protein', 'Protein', 'g', 'macronutrients'),
      ('carbs', 'Carbohydrate', 'g', 'macronutrients'),
      ('fat', 'Total fat', 'g', 'macronutrients'),
      ('fibre', 'Dietary fibre', 'g', 'macronutrients'),
      ('sodium', 'Sodium', 'mg', 'minerals'),
      ('iron', 'Iron', 'mg', 'minerals'),
      ('calcium', 'Calcium', 'mg', 'minerals'),
      ('vitamin_c', 'Vitamin C', 'mg', 'vitamins'),
    ]) {
      batch.insert(
        db.nutrients,
        NutrientsCompanion.insert(
          id: id,
          groupId: group,
          displayName: name,
          canonicalUnit: unit,
          displayPrecision: 0,
          defaultCurveType: 'floor',
          isLimitNutrient: id == 'sodium',
          sortOrder: order++,
          isCore: true,
          minCoverageForScoring: 0.6,
        ),
      );
    }
    var slotOrder = 0;
    for (final (id, name) in const [
      ('breakfast', 'Breakfast'),
      ('lunch', 'Lunch'),
      ('snack', 'Snack'),
      ('dinner', 'Dinner'),
    ]) {
      batch.insert(
        db.mealSlots,
        MealSlotsCompanion.insert(
          id: id,
          key: id,
          displayName: name,
          sortOrder: slotOrder++,
        ),
      );
    }
  });

  await RdaImporter(db).importFromString(
    File('assets/reference/rda_icmr_nin_2020.json').readAsStringSync(),
  );
}

Future<void> _seedProfile(NourishlyDatabase db, String ownerId) {
  return ProfileDao(db).saveProfileAndDeriveTargets(
    ownerId: ownerId,
    inputs: const ProfileInputs(
      ageYears: 34,
      heightCm: 174,
      weightKg: 71,
      activityLevel: ActivityLevel.light,
      biologicalSex: BiologicalSex.male,
    ),
    dateOfBirth: DateTime(1992, 3, 14),
    goal: GoalType.generalHealth,
    effectiveFrom: DateTime.now().subtract(const Duration(days: 30)),
  );
}

/// The prototype's sample day, so a screenshot can be held against it.
Future<void> _seedDay(NourishlyDatabase db, String ownerId) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  const meals = <(String, List<(String, double, Map<String, double>)>)>[
    (
      'breakfast',
      [
        (
          'Thepla, methi',
          90,
          {
            'energy': 250,
            'protein': 6,
            'carbs': 30,
            'fat': 11,
            'fibre': 3,
            'sodium': 320,
            'iron': 2.1,
          },
        ),
        (
          'Buttermilk',
          200,
          {'energy': 40, 'protein': 2, 'carbs': 4, 'fat': 1.5, 'sodium': 120},
        ),
      ],
    ),
    (
      'lunch',
      [
        (
          'Rotli / Chapati',
          120,
          {
            'energy': 265,
            'protein': 9,
            'carbs': 52,
            'fat': 2,
            'fibre': 6,
            'iron': 2.8,
          },
        ),
        (
          'Gujarati dal',
          200,
          {
            'energy': 95,
            'protein': 5,
            'carbs': 14,
            'fat': 2.5,
            'fibre': 4,
            'sodium': 410,
            'iron': 1.6,
          },
        ),
        (
          'Rice, white, cooked',
          150,
          {
            'energy': 130,
            'protein': 2.7,
            'carbs': 28,
            'fat': 0.3,
            'fibre': 0.4,
          },
        ),
        (
          'Bhinda nu shaak',
          120,
          {
            'energy': 90,
            'protein': 2,
            'carbs': 8,
            'fat': 6,
            'fibre': 3,
            'sodium': 260,
            'vitamin_c': 14,
          },
        ),
      ],
    ),
    (
      'snack',
      [
        (
          'Khakhra, plain',
          30,
          {'energy': 380, 'protein': 11, 'carbs': 66, 'fat': 8, 'fibre': 7},
        ),
        (
          'Filter coffee',
          100,
          {'energy': 55, 'protein': 2, 'carbs': 7, 'fat': 2},
        ),
      ],
    ),
  ];

  var index = 0;
  await db.batch((batch) {
    for (final (slot, foods) in meals) {
      for (final (name, grams, per100g) in foods) {
        final foodId = 'food-$index';
        final entryId = 'entry-$index';
        index++;
        batch.insert(
          db.foodItems,
          FoodItemsCompanion.insert(
            id: foodId,
            kind: 'recipe',
            canonicalName: name,
            qualityTier: 'derived',
            provenanceSource: 'catalog_pipeline_recipe',
          ),
          mode: InsertMode.insertOrReplace,
        );
        batch.insert(
          db.foodLogEntries,
          FoodLogEntriesCompanion.insert(
            id: entryId,
            ownerId: ownerId,
            logDate: today,
            mealSlotId: slot,
            foodId: foodId,
            foodRevision: 1,
            servingSizeId: const Value(null),
            quantity: 1,
            gramsConsumed: grams,
            loggedAt: today,
            source: 'manual',
          ),
          mode: InsertMode.insertOrReplace,
        );
        for (final entry in per100g.entries) {
          batch.insert(
            db.logEntryNutrients,
            LogEntryNutrientsCompanion.insert(
              entryId: entryId,
              nutrientId: entry.key,
              amount: entry.value * grams / 100,
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
      }
    }
  });

  await WaterLogDao(db)
      .logWater(ownerId: ownerId, volumeMl: 1600, logDate: today);
}
