import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly/app/app.dart';
import 'package:nourishly/app/router.dart';
import 'package:nourishly/features/food_catalog/data/food_catalog_providers.dart';
import 'package:nourishly/features/reminders/data/local_notification_scheduler.dart';
import 'package:nourishly/features/reminders/data/reminder_providers.dart';
import 'package:nourishly_data/nourishly_data.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Browsing the catalog by cuisine from an empty search box.
///
/// UX-6 made custom-food creation one tap from a failed search, which was
/// right for a catalog small enough to remember. At 441 foods across seven
/// cuisines, "search for a food" assumes knowledge the person does not
/// have — so an empty box offers a way in instead of a blank.
void main() {
  late NourishlyDatabase db;
  late String ownerId;

  setUp(() async {
    db = NourishlyDatabase.forTesting();
    ownerId = await ensureDefaultOwner(db);
    await PreferencesDao(db).update(ownerId, onboardingSeen: true);
  });

  tearDown(() => db.close());

  Future<void> food(String name, {String? tags}) async {
    final id = _uuid.v7();
    await db
        .into(db.foodItems)
        .insert(
          FoodItemsCompanion.insert(
            id: id,
            kind: 'recipe',
            canonicalName: name,
            cuisineTags: tags == null ? const Value.absent() : Value(tags),
            qualityTier: 'derived',
            provenanceSource: 'catalog_pipeline_recipe',
          ),
        );
    await FoodSearchDao(db)
        .indexFood(foodId: id, canonicalName: name, altNames: const []);
  }

  Future<void> settle(WidgetTester tester, {int frames = 20}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpSearch(WidgetTester tester, {double height = 1600}) async {
    tester.view.physicalSize = Size(390, height) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nourishlyDatabaseProvider.overrideWithValue(db),
          catalogReadyProvider.overrideWith((ref) async {}),
          reminderSchedulerProvider.overrideWithValue(NoopReminderScheduler()),
        ],
        child: const NourishlyApp(),
      ),
    );
    await settle(tester);
    appRouter.go('/log');
    await settle(tester);
  }

  testWidgets('an empty box offers the cuisines in the catalog', (
    tester,
  ) async {
    await food('Gujarati dal', tags: '["cuisine:gujarati","course:gravy"]');
    await food('Thepla', tags: '["cuisine:gujarati","course:bread"]');
    await food('Idli', tags: '["cuisine:tamil","course:tiffin"]');

    await pumpSearch(tester);

    expect(find.text('Or browse by cuisine'), findsOneWidget);
    expect(find.text('Gujarati · 2'), findsOneWidget);
    expect(find.text('Tamil · 1'), findsOneWidget);
  });

  testWidgets('picking a cuisine lists its foods', (tester) async {
    await food('Gujarati dal', tags: '["cuisine:gujarati","course:gravy"]');
    await food('Thepla', tags: '["cuisine:gujarati","course:bread"]');
    await food('Idli', tags: '["cuisine:tamil","course:tiffin"]');

    await pumpSearch(tester);
    await tester.tap(find.text('Gujarati · 2'));
    await settle(tester);

    expect(find.text('Gujarati dal'), findsOneWidget);
    expect(find.text('Thepla'), findsOneWidget);
    expect(find.text('Idli'), findsNothing);
  });

  testWidgets('the shelf opens on a cuisine rather than on a blank', (
    tester,
  ) async {
    await food('Gujarati dal', tags: '["cuisine:gujarati","course:gravy"]');
    await food('Thepla', tags: '["cuisine:gujarati","course:bread"]');
    await food('Idli', tags: '["cuisine:tamil","course:tiffin"]');

    await pumpSearch(tester);

    // Nothing tapped: the biggest shelf is already open, so the room the
    // chips take is paid back immediately instead of after a tap.
    expect(find.text('Gujarati dal'), findsOneWidget);
    expect(find.text('Thepla'), findsOneWidget);
    expect(find.text('Idli'), findsNothing);
  });

  testWidgets('the cuisine chips stay on one line, and the foods fit under '
      'them on a phone', (tester) async {
    for (final cuisine in const [
      'gujarati',
      'tamil',
      'kannadiga',
      'pan-indian',
      'north-indian',
      'italian',
      'modern',
    ]) {
      await food('Dish from $cuisine', tags: '["cuisine:$cuisine"]');
    }

    // A real phone, not the tall harness default — the bug was that four
    // rows of chips pushed the food list off the bottom of one.
    await pumpSearch(tester, height: 844);

    final chips = find.byType(ChoiceChip);
    expect(chips, findsNWidgets(7));
    final tops = {
      for (final chip in chips.evaluate())
        tester.getTopLeft(find.byWidget(chip.widget)).dy,
    };
    expect(
      tops,
      hasLength(1),
      reason: 'the strip scrolls sideways instead of wrapping down',
    );

    // And the food it opened on is on screen, not below the fold.
    final food0 = find.textContaining('Dish from ').first;
    expect(
      tester.getTopLeft(food0).dy,
      lessThan(844),
      reason: 'the foods are what the screen is for',
    );
  });

  testWidgets('a catalog with no cuisines shows no shelf at all', (
    tester,
  ) async {
    // What a seed built before cuisine tags looks like. An empty shelf
    // would be worse than no shelf, so the old empty state stands.
    await food('Something old');

    await pumpSearch(tester);

    expect(find.text('Or browse by cuisine'), findsNothing);
    expect(find.text('Search for a food to log'), findsOneWidget);
  });
}
