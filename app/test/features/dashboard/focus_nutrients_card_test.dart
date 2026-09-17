import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly/features/dashboard/presentation/widgets/dashboard_cards.dart';
import 'package:nourishly/features/profile/data/profile_providers.dart';
import 'package:nourishly_data/nourishly_data.dart' hide DailyScore;
import 'package:nourishly_ui/nourishly_ui.dart';
import 'package:nutrition_core/nutrition_core.dart';

/// A focus nutrient's bar must read its real status colour, not a
/// hardcoded "unknown" grey — otherwise a low-vision dashboard user loses
/// the same ok/low/high signal every other bar in the app gives them.
void main() {
  SummaryNutrient nutrientWith(NutrientStatus status) => SummaryNutrient(
    nutrientId: 'protein',
    displayName: 'Protein',
    unit: 'g',
    amount: 40,
    coverage: 1,
    status: status,
    targetAmount: 100,
    pctOfTarget: 40,
  );

  DaySummary summaryWith(NutrientStatus status) => DaySummary(
    logDate: DateTime(2026, 9, 17),
    totalEnergyKcal: 500,
    entryCount: 1,
    nutrients: [nutrientWith(status)],
    meals: const [],
    score: DailyScore.from(const []),
    insights: const [],
    waterMl: 0,
    isComplete: true,
  );

  Future<void> pump(WidgetTester tester, NutrientStatus status) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          focusNutrientIdsProvider.overrideWithValue(const ['protein']),
        ],
        child: MaterialApp(
          theme: NourishlyTheme.light(),
          home: Scaffold(
            body: FocusNutrientsCard(summary: summaryWith(status)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('below-target status colours the bar low, not grey', (
    tester,
  ) async {
    await pump(tester, NutrientStatus.below);
    final bar = tester.widget<NutrientBar>(find.byType(NutrientBar));
    final colors = NourishlyTheme.light().extension<NourishlyColors>()!;
    expect(bar.color, colors.statusLow);
    expect(bar.color, isNot(colors.statusUnknown));
  });

  testWidgets('above-target status colours the bar high, not grey', (
    tester,
  ) async {
    await pump(tester, NutrientStatus.above);
    final bar = tester.widget<NutrientBar>(find.byType(NutrientBar));
    final colors = NourishlyTheme.light().extension<NourishlyColors>()!;
    expect(bar.color, colors.statusHigh);
  });

  testWidgets('within-target status colours the bar ok, not grey', (
    tester,
  ) async {
    await pump(tester, NutrientStatus.within);
    final bar = tester.widget<NutrientBar>(find.byType(NutrientBar));
    final colors = NourishlyTheme.light().extension<NourishlyColors>()!;
    expect(bar.color, colors.statusOk);
  });
}
