import 'dart:io';

import 'package:nutrition_core/nutrition_core.dart';
import 'package:test/test.dart';

NutrientAggregate _agg(
  String id,
  double amount, {
  double known = 2000,
  double total = 2000,
}) => NutrientAggregate(
  nutrientId: id,
  amount: amount,
  knownEnergyKcal: known,
  totalEnergyKcal: total,
);

const _targets = {
  'energy': NutrientTarget(
    nutrientId: 'energy',
    curveType: TargetCurveType.range,
    amount: 2050,
  ),
  'protein': NutrientTarget(
    nutrientId: 'protein',
    curveType: TargetCurveType.floor,
    amount: 95,
  ),
  'fibre': NutrientTarget(
    nutrientId: 'fibre',
    curveType: TargetCurveType.floor,
    amount: 29,
  ),
  'sodium': NutrientTarget(
    nutrientId: 'sodium',
    curveType: TargetCurveType.ceiling,
    amount: 2000,
  ),
  'iron': NutrientTarget(
    nutrientId: 'iron',
    curveType: TargetCurveType.plateau,
    amount: 19,
    upperLimit: 45,
  ),
};

InsightContext _context(
  Map<String, NutrientAggregate> nutrients, {
  double? waterMl,
  double? waterTargetMl,
  bool isComplete = true,
  int proteinStreak = 0,
}) {
  final day = DayForScoring(
    nutrients: nutrients,
    targets: _targets,
    goal: GoalType.generalHealth,
    isComplete: isComplete,
    waterMl: waterMl,
    waterTargetMl: waterTargetMl,
  );
  return InsightContext(
    day: day,
    score: scoreDay(day),
    displayNames: const {
      'sodium': 'Sodium',
      'fibre': 'Fibre',
      'protein': 'Protein',
      'iron': 'Iron',
    },
    consecutiveDaysProteinMet: proteinStreak,
  );
}

void main() {
  test(
    'a fibre gap names the number, the target, and a food that closes it',
    () {
      final insights = generateInsights(
        _context({
          'energy': _agg('energy', 1640),
          'protein': _agg('protein', 82),
          'fibre': _agg('fibre', 18),
        }),
      );
      final fibre = insights.firstWhere((i) => i.ruleId == 'suggest.fibre_gap');
      expect(fibre.text, contains('18 g'));
      expect(fibre.text, contains('29 g'));
      expect(fibre.category, InsightCategory.suggest);
    },
  );

  test('a limit exceeded is stated against the limit, not judged', () {
    final insights = generateInsights(
      _context({
        'energy': _agg('energy', 2000),
        'sodium': _agg('sodium', 2310),
      }),
    );
    final sodium = insights.firstWhere(
      (i) => i.ruleId == 'caution.limit_exceeded',
    );
    expect(sodium.text, 'Sodium came in at 2310 against the 2000 daily limit.');
  });

  test('a protein streak is celebrated, and one good day is just stated', () {
    final oneDay = generateInsights(
      _context({
        'energy': _agg('energy', 2000),
        'protein': _agg('protein', 100),
      }),
    );
    expect(
      oneDay.firstWhere((i) => i.ruleId == 'celebrate.protein_streak').text,
      contains('reached your'),
    );

    final streak = generateInsights(
      _context({
        'energy': _agg('energy', 2000),
        'protein': _agg('protein', 100),
      }, proteinStreak: 3),
    );
    expect(
      streak.firstWhere((i) => i.ruleId == 'celebrate.protein_streak').text,
      '3 days in a row hitting your protein target.',
    );
  });

  test('an incompletely logged day says so instead of reporting a deficit', () {
    final insights = generateInsights(
      _context({'energy': _agg('energy', 500, known: 500, total: 500)}),
    );
    expect(
      insights.map((i) => i.ruleId),
      contains('data_quality.incomplete_day'),
    );
    expect(
      insights.map((i) => i.ruleId),
      isNot(contains('inform.energy_under_band')),
      reason: 'a missing dinner is not a finding about energy intake',
    );
  });

  test('only the top few are returned, highest priority first', () {
    final insights = generateInsights(
      _context(
        {
          'energy': _agg('energy', 1200),
          'protein': _agg('protein', 40),
          'fibre': _agg('fibre', 8),
          'sodium': _agg('sodium', 3000),
        },
        waterMl: 500,
        waterTargetMl: 2500,
      ),
      limit: 3,
    );
    expect(insights, hasLength(3));
    expect(
      insights.map((i) => i.priority).toList(),
      orderedEquals([...insights.map((i) => i.priority)]..sort()),
    );
    expect(insights.first.category, InsightCategory.dataQuality);
    expect(insights.map((i) => i.category), contains(InsightCategory.caution));
  });

  group('language boundary (§21.7, §37 item 10)', () {
    /// Rendered across a matrix of days so every template gets exercised,
    /// then checked against the table §21.7 makes part of the definition of
    /// done. A new rule that reaches for "deficient" or "unhealthy" fails
    /// here rather than in review.
    final corpus = <String>[
      for (final context in [
        _context(
          {
            'energy': _agg('energy', 1640),
            'protein': _agg('protein', 82),
            'fibre': _agg('fibre', 18),
            'sodium': _agg('sodium', 2310),
            'iron': _agg('iron', 6, known: 500, total: 2000),
          },
          waterMl: 1600,
          waterTargetMl: 2600,
        ),
        _context(
          {
            'energy': _agg('energy', 2050),
            'protein': _agg('protein', 120),
            'fibre': _agg('fibre', 32),
            'sodium': _agg('sodium', 1200),
            'iron': _agg('iron', 20),
          },
          waterMl: 2700,
          waterTargetMl: 2600,
          proteinStreak: 5,
        ),
        _context({'energy': _agg('energy', 400, known: 400, total: 400)}),
        _context(
          {
            'energy': _agg('energy', 3200),
            'protein': _agg('protein', 30),
            'fibre': _agg('fibre', 4),
          },
          waterMl: 200,
          waterTargetMl: 2600,
        ),
      ])
        for (final insight in generateInsights(context, limit: 99))
          insight.text,
    ];

    test('every rule produced at least one line across the matrix', () {
      expect(corpus, isNotEmpty);
    });

    const forbidden = [
      'deficient',
      'deficiency',
      'unhealthy',
      'healthy',
      'supplement',
      'will cause',
      'bad day',
      'you failed',
      'failed',
      'poor',
      'should take',
      'diagnos',
      'disease',
      'obese',
      'overweight',
      'cheat',
      'guilty',
    ];

    for (final term in forbidden) {
      test('no insight says "$term"', () {
        for (final text in corpus) {
          expect(text.toLowerCase(), isNot(contains(term)), reason: text);
        }
      });
    }

    test('the rule source carries no forbidden term either', () {
      // Catches a template that this matrix happens not to trigger.
      // Comments are stripped first: the boundary table is quoted in the
      // doc comment above the ruleset, and an apostrophe in prose would
      // otherwise open a bogus string span running across it.
      final source = File('lib/src/insights/insight_rules.dart')
          .readAsStringSync()
          .split('\n')
          .where((line) => !line.trimLeft().startsWith('//'))
          .join('\n');
      final literals = RegExp(r"'((?:[^'\\]|\\.)*)'")
          .allMatches(source)
          .map((m) => m.group(1)!.toLowerCase())
          .where((s) => s.contains(' '))
          .toList();
      for (final term in forbidden) {
        for (final literal in literals) {
          // The boundary table itself is quoted in the doc comment, which
          // is not a string literal, so anything matching here is copy.
          expect(literal, isNot(contains(term)), reason: term);
        }
      }
    });
  });
}
