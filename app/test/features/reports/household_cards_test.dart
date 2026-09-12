import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly/features/reports/data/report_providers.dart';
import 'package:nourishly/features/reports/presentation/widgets/household_cards.dart';
import 'package:nourishly_data/nourishly_data.dart';
import 'package:nourishly_ui/nourishly_ui.dart';
import 'package:nutrition_core/nutrition_core.dart';

/// The two report cards that depend on knowing how one household cooks.
///
/// Most of what is worth testing here is when they say *nothing*. A card
/// that appears every week reading "0 g saved" teaches the reader to skip
/// that part of the report, and an empty cuisine mix is not a finding.
void main() {
  final summary = PeriodSummary(
    kind: PeriodKind.week,
    start: DateTime(2026, 9, 7),
    end: DateTime(2026, 9, 13),
    days: const [],
  );

  Future<void> pump(
    WidgetTester tester, {
    PeriodSavings? savings,
    ({List<CuisineCount> byCuisine, int totalEntries})? mix,
  }) async {
    final range = (from: summary.start, to: summary.end);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          periodSavingsProvider(range)
              .overrideWith((ref) async => savings ?? PeriodSavings.none),
          cuisineMixProvider(range).overrideWith(
            (ref) async =>
                mix ?? (byCuisine: <CuisineCount>[], totalEntries: 0),
          ),
        ],
        child: MaterialApp(
          theme: NourishlyTheme.light(),
          home: Scaffold(
            body: ListView(
              children: [
                OilSavedCard(summary: summary),
                CuisineMixCard(summary: summary),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('cooking lighter', () {
    testWidgets('states the fat and energy not eaten, and what it rests on', (
      tester,
    ) async {
      await pump(
        tester,
        savings: const PeriodSavings(
          energy: 740.4,
          fat: 84.2,
          entryCount: 11,
          dishCount: 3,
        ),
      );
      expect(find.text('Cooking lighter'), findsOneWidget);
      expect(
        find.text('84 g of fat and 740 kcal not eaten, across 11 meals.'),
        findsOneWidget,
      );
      // It says it is a difference between two computed recipes, because
      // that is the claim that makes the number trustworthy.
      expect(find.textContaining('not an estimate'), findsOneWidget);
    });

    testWidgets('says nothing at all when nothing was forked', (tester) async {
      await pump(tester);
      expect(find.text('Cooking lighter'), findsNothing);
    });

    testWidgets('says nothing when the saving is not a saving', (tester) async {
      await pump(
        tester,
        savings: const PeriodSavings(
          energy: 0,
          fat: 0,
          entryCount: 4,
          dishCount: 1,
        ),
      );
      expect(find.text('Cooking lighter'), findsNothing);
    });

    testWidgets('one meal reads as a meal', (tester) async {
      await pump(
        tester,
        savings: const PeriodSavings(
          energy: 36,
          fat: 4.2,
          entryCount: 1,
          dishCount: 1,
        ),
      );
      expect(
        find.text('4.2 g of fat and 36 kcal not eaten, across 1 meal.'),
        findsOneWidget,
      );
    });
  });

  group('cuisine mix', () {
    testWidgets('shows each cuisine as a share of what was classified', (
      tester,
    ) async {
      await pump(
        tester,
        mix: (
          byCuisine: const [
            CuisineCount('gujarati', 12),
            CuisineCount('tamil', 8),
          ],
          totalEntries: 20,
        ),
      );
      expect(find.text('What you ate'), findsOneWidget);
      expect(find.text('Gujarati'), findsOneWidget);
      expect(find.text('60%'), findsOneWidget);
      expect(find.text('40%'), findsOneWidget);
    });

    testWidgets('says how much of the period it could classify', (
      tester,
    ) async {
      // Untagged foods are never folded into the shares — a percentage is
      // only meaningful against a known total.
      await pump(
        tester,
        mix: (
          byCuisine: const [
            CuisineCount('gujarati', 6),
            CuisineCount('tamil', 4),
          ],
          totalEntries: 25,
        ),
      );
      expect(find.textContaining('Based on 10 of 25 entries'), findsOneWidget);
      expect(find.text('60%'), findsOneWidget);
    });

    testWidgets('one cuisine is not a mix', (tester) async {
      await pump(
        tester,
        mix: (
          byCuisine: const [CuisineCount('gujarati', 20)],
          totalEntries: 20,
        ),
      );
      expect(find.text('What you ate'), findsNothing);
    });

    testWidgets('nothing logged, nothing said', (tester) async {
      await pump(tester);
      expect(find.text('What you ate'), findsNothing);
    });
  });
}
