import 'dart:convert';
import 'dart:io';

import 'package:nutrition_core/nutrition_core.dart';
import 'package:test/test.dart';

/// Runs `test/golden/scoring_vectors.json` against the engine.
///
/// The vectors are the specification (§37 item 9): they were written from
/// §21.3-21.6 before the engine existed, and they are what a reviewer
/// checks rather than reading the arithmetic. A change here that moves a
/// number is a ruleset change and needs `scoringRulesetVersion` bumped —
/// §25.7 exists so yesterday's 78 stays 78.
void main() {
  final vectors = jsonDecode(
    File('test/golden/scoring_vectors.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  test('the vectors were written for the ruleset this engine implements', () {
    expect(vectors['rulesetVersion'], scoringRulesetVersion);
  });

  group('curves (§21.3)', () {
    for (final raw in vectors['curves'] as List) {
      final spec = raw as Map<String, dynamic>;
      test(spec['name'] as String, () {
        final target = NutrientTarget(
          nutrientId: 'test',
          curveType: TargetCurveType.values.byName(spec['curve'] as String),
          amount: (spec['target'] as num).toDouble(),
          upperLimit: (spec['upperLimit'] as num?)?.toDouble(),
          tolerance:
              (spec['tolerance'] as num?)?.toDouble() ??
              NutrientTarget.defaultTolerance,
          plateauTaper:
              (spec['plateauTaper'] as num?)?.toDouble() ??
              NutrientTarget.defaultPlateauTaper,
        );
        for (final rawCase in spec['cases'] as List) {
          final c = rawCase as Map<String, dynamic>;
          final x = (c['x'] as num).toDouble();
          expect(
            scoreNutrient(target, x),
            closeTo((c['score'] as num).toDouble(), 1e-9),
            reason: 'x = $x${c['note'] != null ? ' (${c['note']})' : ''}',
          );
        }
      });
    }
  });

  group('composite (§21.4)', () {
    for (final raw in vectors['composite'] as List) {
      final spec = raw as Map<String, dynamic>;
      test(spec['name'] as String, () {
        final components = [
          for (final rawComponent in spec['components'] as List)
            () {
              final c = rawComponent as Map<String, dynamic>;
              final excluded = c['excluded'] as String?;
              return ScoredComponent(
                key: ScoreComponentKey.fromId(c['key'] as String),
                score: (c['score'] as num?)?.toDouble(),
                weight: (c['weight'] as num).toDouble(),
                appliedWeight: 0,
                exclusion: excluded == null
                    ? null
                    : ScoreExclusion.values.firstWhere((e) => e.id == excluded),
              );
            }(),
        ];

        final score = DailyScore.from(components);

        expect(
          score.composite,
          closeTo((spec['composite'] as num).toDouble(), 1e-9),
        );
        expect(score.band, ScoreBand.fromId(spec['band'] as String));

        final expectedWeights = spec['appliedWeights'] as Map<String, dynamic>?;
        if (expectedWeights != null) {
          for (final entry in expectedWeights.entries) {
            expect(
              score
                  .component(ScoreComponentKey.fromId(entry.key))!
                  .appliedWeight,
              closeTo((entry.value as num).toDouble(), 1e-9),
              reason: entry.key,
            );
          }
        }
      });
    }
  });

  test('bands (§21.6)', () {
    for (final raw in vectors['bands'] as List) {
      final b = raw as Map<String, dynamic>;
      expect(
        ScoreBand.forScore((b['score'] as num).toDouble()),
        ScoreBand.fromId(b['band'] as String),
        reason: '${b['score']}',
      );
    }
  });
}
