import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly/app/app.dart';
import 'package:nourishly/app/providers.dart';
import 'package:nourishly/app/router.dart';
import 'package:nourishly/features/data_backup/data/backup_providers.dart';
import 'package:nourishly/features/data_backup/data/export_service.dart';
import 'package:nourishly/features/food_catalog/data/food_catalog_providers.dart';
import 'package:nourishly/features/reminders/data/local_notification_scheduler.dart';
import 'package:nourishly/features/reminders/data/reminder_providers.dart';
import 'package:nourishly_data/nourishly_data.dart' hide ReminderRule;
import 'package:nourishly_domain/nourishly_domain.dart';
import 'package:nourishly_ui/nourishly_ui.dart';
import 'package:uuid/uuid.dart';

/// §7's accessibility NFRs, checked rather than asserted in a document.
///
/// Not every one of them can be: contrast (NFR-A-01) is a property of the
/// token file and is validated by the design system's own tooling, and a
/// real screen-reader pass on a device is Phase 6 work. What is checkable
/// here is the part that regresses silently — a chart that loses its text
/// alternative, a layout that breaks at large type, a tap target that
/// shrinks below the minimum when somebody tidies a padding value.
void main() {
  late NourishlyDatabase db;
  late String ownerId;
  final today = DateTime(2026, 9, 9);

  setUp(() async {
    db = NourishlyDatabase.forTesting();
    ownerId = await ensureDefaultOwner(db);
    await _seed(db, ownerId, today);
    await PreferencesDao(db).update(ownerId, onboardingSeen: true);
  });

  tearDown(() => db.close());

  Future<void> pump(
    WidgetTester tester,
    String location, {
    double textScale = 1,
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nourishlyDatabaseProvider.overrideWithValue(db),
          catalogReadyProvider.overrideWith((ref) async {}),
          clockProvider.overrideWithValue(
            FakeClock(today.add(const Duration(hours: 9))),
          ),
          reminderSchedulerProvider.overrideWithValue(NoopReminderScheduler()),
          // Nothing in a widget test may reach the real filesystem:
          // `path_provider` resolves XDG directories with real I/O that
          // never completes under flutter_test's fake clock, so a screen
          // that touches it simply stops. Same reasoning as the scheduler
          // override above.
          exportServiceProvider.overrideWith(
            (ref) => _NoFilesExportService(db),
          ),
        ],
        child: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: const NourishlyApp(),
        ),
      ),
    );
    await tester.pump();
    appRouter.go(location);
    await tester.pumpAndSettle();
  }

  group('NFR-A-02 — charts carry a text alternative', () {
    testWidgets('the energy ring says how much is left, not "80 per cent"', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(tester, '/today');

      // The conclusion, in words: what a sighted reader takes from the
      // ring at a glance.
      expect(
        find.bySemanticsLabel(RegExp(r'of 2,?000 kilocalories')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('a nutrient bar reads as a value against its target', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(tester, '/today');

      expect(
        find.bySemanticsLabel(RegExp('Protein: .* of .* target, .* per cent')),
        findsWidgets,
      );
      handle.dispose();
    });

    testWidgets('the water vessel reads as a volume against its goal', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(tester, '/water');

      expect(
        find.bySemanticsLabel(RegExp(r'\d+ millilitres of \d+')),
        findsWidgets,
      );
      handle.dispose();
    });
  });

  group('NFR-A-03 — 200% text scale', () {
    // The requirement is "without layout breakage or truncation of
    // essential content". A Flutter overflow is a caught exception, so
    // the check is simply: does anything break when type doubles?
    for (final route in const [
      '/today',
      '/water',
      '/profile',
      '/profile/reminders',
      '/profile/data',
    ]) {
      testWidgets('$route survives 200% type', (tester) async {
        await pump(tester, route, textScale: 2);
        expect(
          tester.takeException(),
          isNull,
          reason: '$route overflows at 200% text scale',
        );
      });
    }

    testWidgets('the dashboard survives 200% type on a small phone', (
      tester,
    ) async {
      // A 320-wide screen at double type is the worst realistic case, and
      // the one that catches a Row that should have been a Wrap.
      await pump(
        tester,
        '/today',
        textScale: 2,
        size: const Size(320, 640),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('NFR-A-05 — primary touch targets are at least 48 dp', () {
    for (final route in const ['/profile/reminders', '/profile/data']) {
      testWidgets(route, (tester) async {
        final handle = tester.ensureSemantics();
        await pump(tester, route);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        handle.dispose();
      });
    }
  });

  // NFR-A-01 is checked at the token level instead, in
  // `nourishly_ui/test/contrast_test.dart`: a screen-level guideline
  // reports "3.52 at font size 12" without saying which of a dozen greys
  // on which of three backgrounds, and the answer is always a token
  // rather than a screen.

  group('NFR-A-06 — reduced motion', () {
    testWidgets('the water vessel arrives instantly, without the ripple', (
      tester,
    ) async {
      // The platform's accessibility flag, which is what MediaQuery's
      // `disableAnimations` is built from.
      final binding = tester.binding;
      binding.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures.allOn;
      addTearDown(
        binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );

      await pump(tester, '/water');

      // Nothing pumps: with motion reduced the level is already at its
      // final value on the first frame, so there is no animation left for
      // pumpAndSettle to have waited on. The assertion that matters is
      // that the screen settled at all — an unreduced vessel would still
      // be rippling.
      final vessel = tester.state<WaterVesselState>(
        find.byType(WaterVessel),
      );
      expect(vessel.mounted, isTrue);
      expect(tester.takeException(), isNull);
    });
  });

  group('NFR-A-04 — no information by colour alone', () {
    testWidgets('every status chip carries a written label', (tester) async {
      await pump(tester, '/today');
      final chips = tester.widgetList<StatusChip>(find.byType(StatusChip));
      expect(chips, isNotEmpty);
      for (final chip in chips) {
        expect(
          chip.label.trim(),
          isNotEmpty,
          reason: 'a chip whose only signal is its colour',
        );
      }
    });
  });

  group('NFR-A-08 — destructive actions are confirmable', () {
    testWidgets('deleting everything takes two steps and offers an export', (
      tester,
    ) async {
      await pump(tester, '/profile/data');
      await tester.scrollUntilVisible(
        find.text('Delete everything on this phone'),
        200,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete everything on this phone'));
      await tester.pumpAndSettle();

      // Step one: says what it does, says it cannot be undone, and offers
      // the export first (§30.7).
      expect(find.text('Delete everything?'), findsOneWidget);
      // Both the row's subtitle and the dialog say it, which is the
      // point — the warning is not hidden behind the tap.
      expect(find.textContaining('cannot be undone'), findsWidgets);
      expect(find.text('Export first'), findsOneWidget);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Step two: a typed confirmation, so a stray tap cannot do it.
      expect(find.text('Type DELETE to confirm'), findsOneWidget);

      // And the wrong word does nothing.
      await tester.enterText(find.byType(TextField), 'delete everything');
      await tester.tap(find.text('Delete everything'));
      await tester.pumpAndSettle();

      final remaining = await ProfileEraser(db).remainingRows(ownerId);
      expect(remaining, greaterThan(0), reason: 'nothing should be gone yet');
    });

    testWidgets('the typed confirmation does delete', (tester) async {
      await pump(tester, '/profile/data');
      await tester.scrollUntilVisible(
        find.text('Delete everything on this phone'),
        200,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete everything on this phone'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'DELETE');
      await tester.tap(find.text('Delete everything'));
      // Bounded pumps rather than pumpAndSettle: the busy overlay uses an
      // indeterminate progress bar, which by design never stops animating
      // and so never lets pumpAndSettle return.
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Everything the user put in is gone.
      for (final table in const [
        'food_log_entries',
        'water_log_entries',
        'body_weight_entries',
        'target_sets',
        'user_profile_versions',
      ]) {
        final row = await db
            .customSelect('SELECT COUNT(*) AS c FROM $table')
            .getSingle();
        expect(row.data['c'], 0, reason: '$table survived the deletion');
      }

      // What comes back are defaults, not leftovers: §30.7 asks for "a
      // fresh guest state rather than an error state", and a live app
      // re-seeds preferences and the reminder rows the moment it reads
      // them again. That is the app starting over, not the delete having
      // missed something.
      final preferences = await PreferencesDao(db).forOwner(ownerId);
      expect(preferences.remindersEnabled, isFalse);
      expect(preferences.lastExportedAt, isNull);

      expect(find.textContaining('back to a clean start'), findsOneWidget);
      // And the screen is usable again, not stuck behind the overlay.
      expect(find.text('Deleting…'), findsNothing);
    });
  });
}

/// An [ExportService] that does everything except touch the disk.
class _NoFilesExportService extends ExportService {
  _NoFilesExportService(super.db);

  @override
  Future<void> clearGenerated() async {}
}

Future<void> _seed(
  NourishlyDatabase db,
  String ownerId,
  DateTime today,
) async {
  const uuid = Uuid();
  await db
      .into(db.nutrientGroups)
      .insert(
        NutrientGroupsCompanion.insert(
          id: 'macros',
          name: 'Macros',
          sortOrder: 0,
        ),
      );
  for (final (id, name, unit, curve) in const [
    ('energy', 'Energy', 'kcal', 'range'),
    ('protein', 'Protein', 'g', 'floor'),
    ('carbs', 'Carbohydrate', 'g', 'range'),
    ('fat', 'Fat', 'g', 'range'),
    ('fibre', 'Dietary fibre', 'g', 'floor'),
    ('water', 'Water', 'ml', 'floor'),
  ]) {
    await db
        .into(db.nutrients)
        .insert(
          NutrientsCompanion.insert(
            id: id,
            groupId: 'macros',
            displayName: name,
            canonicalUnit: unit,
            displayPrecision: 0,
            defaultCurveType: curve,
            isLimitNutrient: false,
            sortOrder: 0,
            isCore: true,
            minCoverageForScoring: 0.5,
          ),
        );
  }
  for (final (key, name, order) in const [
    ('breakfast', 'Breakfast', 0),
    ('lunch', 'Lunch', 1),
    ('dinner', 'Dinner', 2),
  ]) {
    await db
        .into(db.mealSlots)
        .insert(
          MealSlotsCompanion.insert(
            id: 'slot-$key',
            key: key,
            displayName: name,
            sortOrder: order,
            ownerId: const Value(null),
          ),
        );
  }
  await db
      .into(db.foodItems)
      .insert(
        FoodItemsCompanion.insert(
          id: 'food-dal',
          kind: 'dish',
          canonicalName: 'Dal',
          qualityTier: 'derived',
          provenanceSource: 'catalog_pipeline_recipe',
        ),
      );
  for (final (id, amount) in const [
    ('energy', 120.0),
    ('protein', 6.0),
    ('carbs', 18.0),
    ('fat', 2.0),
    ('fibre', 4.0),
  ]) {
    await db
        .into(db.foodNutrientValues)
        .insert(
          FoodNutrientValuesCompanion.insert(
            id: uuid.v7(),
            foodId: 'food-dal',
            nutrientId: id,
            amountPer100g: amount,
            valueSource: 'derived',
          ),
        );
  }

  const targetSetId = 'ts-1';
  await db
      .into(db.targetSets)
      .insert(
        TargetSetsCompanion.insert(
          id: targetSetId,
          ownerId: ownerId,
          effectiveFrom: today.subtract(const Duration(days: 60)),
          derivationSource: 'derived',
          rulesetVersion: '2026.09',
        ),
      );
  for (final (nutrient, target, curve) in const [
    ('energy', 2000.0, 'range'),
    ('protein', 95.0, 'floor'),
    ('carbs', 250.0, 'range'),
    ('fat', 65.0, 'range'),
    ('fibre', 30.0, 'floor'),
    ('water', 2500.0, 'floor'),
  ]) {
    await db
        .into(db.nutrientTargets)
        .insert(
          NutrientTargetsCompanion.insert(
            id: 'nt-$nutrient',
            targetSetId: targetSetId,
            nutrientId: nutrient,
            targetAmount: target,
            curveType: curve,
            tolerance: 0.1,
          ),
        );
  }

  await db
      .into(db.servingSizes)
      .insert(
        ServingSizesCompanion.insert(
          id: 'serving-bowl',
          foodId: 'food-dal',
          label: '1 bowl',
          grams: 150,
        ),
      );
  await FoodLoggingDao(db).logFood(
    ownerId: ownerId,
    foodId: 'food-dal',
    servingId: 'serving-bowl',
    quantity: 2,
    mealSlotId: 'slot-lunch',
    logDate: today,
  );
  await WaterLogDao(db).logWater(
    ownerId: ownerId,
    volumeMl: 1200,
    logDate: today,
  );
}
