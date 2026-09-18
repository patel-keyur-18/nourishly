import 'package:meta/meta.dart';

/// What an insight is for, which is also how it is styled (§21.7).
enum InsightCategory {
  celebrate('celebrate'),
  inform('inform'),
  suggest('suggest'),
  caution('caution'),

  /// "Micronutrients are based on 45% of today's food" — the category that
  /// keeps the rest honest.
  dataQuality('data_quality');

  const InsightCategory(this.id);

  final String id;

  static InsightCategory fromId(String id) =>
      values.firstWhere((c) => c.id == id);
}

/// One generated line of the daily report (§22.5 `DailyInsight`).
///
/// Persisted rather than regenerated on view, so the report a user reads
/// twice says the same thing both times.
@immutable
class Insight {
  const Insight({
    required this.ruleId,
    required this.category,
    required this.text,
    required this.priority,
  });

  final String ruleId;
  final InsightCategory category;

  /// The rendered sentence. Assembled by the rule from a whole template,
  /// never by concatenating fragments — §27.14 rules that out because it
  /// breaks in every language with a different word order.
  final String text;

  /// Lower sorts first. §21.7 shows the top 2-4.
  final int priority;
}
