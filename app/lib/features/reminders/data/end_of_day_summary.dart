import 'package:nourishly_data/nourishly_data.dart' show DaySummary;
import 'package:nutrition_core/nutrition_core.dart' show NutrientStatus;

import '../../../shared/formatting.dart';

/// The one-line headline the end-of-day notification carries (§29.4).
///
/// The requirement is specific: "so it is useful even unopened —
/// *Yesterday: 1,950 kcal, protein met, fibre a bit low*". A notification
/// that only says "your day is ready" makes the user open the app to find
/// out whether it was worth opening the app.
///
/// §21.7's language boundary applies here exactly as it does to insights,
/// and §21.8's no-praise-no-blame rule with it. So: energy is stated, not
/// judged; a nutrient that landed is "met"; one that fell short is "a bit
/// low"; one over a limit is "over" rather than "too much". Nothing here
/// tells anyone what to do about it, and nothing congratulates them.
String? endOfDaySummaryLine(DaySummary summary) {
  if (!summary.hasAnything) return null;

  final parts = <String>[
    '${formatThousands(summary.totalEnergyKcal.round())} kcal',
  ];

  // Two nutrients at most. The headline has to fit on a lock screen, and
  // §29.1's "few, and useful" applies to the content as much as to the
  // count.
  final notable = <String>[];
  for (final id in const ['protein', 'fibre', 'iron', 'sodium']) {
    if (notable.length == 2) break;
    final nutrient = summary.nutrient(id);
    if (nutrient == null || !nutrient.hasData) continue;
    final phrase = _phraseFor(nutrient.displayName, nutrient.status);
    if (phrase != null) notable.add(phrase);
  }
  parts.addAll(notable);

  if (summary.waterTargetMl != null && notable.length < 2) {
    final met = summary.waterMl >= summary.waterTargetMl!;
    parts.add(met ? 'water met' : 'water a bit short');
  }

  return parts.join(', ');
}

String? _phraseFor(String displayName, NutrientStatus status) {
  final name = shortNutrientName(displayName).toLowerCase();
  return switch (status) {
    NutrientStatus.within => '$name met',
    NutrientStatus.below => '$name a bit low',
    // "Above" is never alarming (§21.8) — it is a violet on the charts and
    // a plain word here.
    NutrientStatus.above => '$name over',
    NutrientStatus.insufficientData => null,
  };
}
