import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly/features/food_logging/presentation/widgets/food_search_result_tile.dart';
import 'package:nourishly_data/nourishly_data.dart';
import 'package:nourishly_ui/nourishly_ui.dart';

FoodItem _food(String name, {String tags = '[]', String kind = 'recipe'}) =>
    FoodItem(
      id: 'id-$name-$tags',
      kind: kind,
      canonicalName: name,
      cuisineTags: tags,
      qualityTier: 'derived',
      provenanceSource: 'catalog_pipeline_recipe',
      revision: 1,
      isVerified: false,
    );

Future<void> _pump(WidgetTester tester, List<FoodItem> foods) =>
    tester.pumpWidget(
      MaterialApp(
        theme: NourishlyTheme.light(),
        home: Scaffold(
          body: ListView(
            children: [
              for (final food in foods)
                FoodSearchResultTile(food: food, onTap: () {}),
            ],
          ),
        ),
      ),
    );

void main() {
  testWidgets('the same dish from two regions is told apart by cuisine', (
    tester,
  ) async {
    // The bug: the shipped catalog carries "Coconut rice" three times
    // (catalog spec §0.6 keeps regional variants as separate foods), and
    // without a cuisine they render as identical, unchoosable lines.
    await _pump(tester, [
      _food('Coconut rice', tags: '["cuisine:tamil","course:rice"]'),
      _food('Coconut rice', tags: '["cuisine:kannadiga","course:rice"]'),
      _food('Coconut rice', tags: '["cuisine:pan-indian"]'),
    ]);

    expect(find.text('Coconut rice'), findsNWidgets(3));
    expect(find.text('Tamil · Recipe'), findsOneWidget);
    expect(find.text('Kannadiga · Recipe'), findsOneWidget);
    expect(find.text('Pan-Indian · Recipe'), findsOneWidget);
  });

  testWidgets('a food with no cuisine shows none, not a filler label', (
    tester,
  ) async {
    // "Other" would be a label pretending to be information.
    await _pump(tester, [_food('Something old', kind: 'ingredient')]);
    expect(find.text('Ingredient'), findsOneWidget);
  });

  testWidgets('a cuisine the screen has not learned is shown as written', (
    tester,
  ) async {
    // Swallowing it would hide the fact that the pipeline knows a cuisine
    // this screen does not.
    await _pump(tester, [
      _food('Kung pao', tags: '["cuisine:indo-chinese","course:gravy"]'),
    ]);
    expect(find.text('indo-chinese · Recipe'), findsOneWidget);
  });

  testWidgets('malformed tags never break the row', (tester) async {
    await _pump(tester, [_food('Broken', tags: 'not json')]);
    expect(find.text('Broken'), findsOneWidget);
    expect(find.text('Recipe'), findsOneWidget);
  });
}
