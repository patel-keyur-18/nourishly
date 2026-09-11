import 'package:flutter/material.dart';
import 'package:nourishly_ui/nourishly_ui.dart';
import 'package:nutrition_core/nutrition_core.dart';

import '../../../../shared/formatting.dart';

/// The prototype's `.ch-h` + chart + `.ch-f`: a chart with a title, an
/// optional note on the right, and an optional footnote underneath.
class ChartCard extends StatelessWidget {
  const ChartCard({
    super.key,
    required this.title,
    required this.child,
    this.note,
    this.footnote,
  });

  final String title;
  final Widget child;

  /// The small grey figure on the right of the title — usually the
  /// denominator ("6 days scored", "Target 2,050").
  final String? note;

  /// Under the chart, for what the chart cannot say itself ("Friday not
  /// logged").
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;

    return NourishlyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: text.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.ink,
                  ),
                ),
              ),
              if (note != null)
                Text(
                  note!,
                  style: text.caption.copyWith(
                    fontSize: 10.5,
                    color: colors.ink3,
                  ),
                ),
            ],
          ),
          const SizedBox(height: NourishlySpace.s2),
          child,
          if (footnote != null) ...[
            const SizedBox(height: NourishlySpace.s1),
            Text(
              footnote!,
              style: text.caption.copyWith(fontSize: 10.5, color: colors.ink3),
            ),
          ],
        ],
      ),
    );
  }
}

/// One plain-language finding, colour-railed like the daily report's
/// insights so the two screens read as the same app.
@immutable
class PeriodFinding {
  const PeriodFinding(this.text, this.tone);

  const PeriodFinding.good(this.text) : tone = FindingTone.good;
  const PeriodFinding.short(this.text) : tone = FindingTone.short;
  const PeriodFinding.over(this.text) : tone = FindingTone.over;
  const PeriodFinding.note(this.text) : tone = FindingTone.note;

  final String text;
  final FindingTone tone;
}

enum FindingTone { good, short, over, note }

/// The prototype's findings card.
class FindingsCard extends StatelessWidget {
  const FindingsCard({super.key, required this.findings});

  final List<PeriodFinding> findings;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;

    return NourishlyCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < findings.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: colors.line),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: NourishlySpace.s4,
                vertical: NourishlySpace.s3,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 3,
                    height: 34,
                    margin: const EdgeInsets.only(
                      right: NourishlySpace.s3,
                      top: 2,
                    ),
                    decoration: BoxDecoration(
                      color: switch (findings[i].tone) {
                        FindingTone.good => colors.statusOk,
                        FindingTone.short => colors.statusLow,
                        FindingTone.over => colors.statusHigh,
                        FindingTone.note => colors.statusUnknown,
                      },
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      findings[i].text,
                      style: text.caption.copyWith(
                        color: colors.ink2,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// What a period shows instead of averages when too few days were logged
/// (§25.6). Never a blank screen and never a dash: the days that *are*
/// there are listed, because they are real data — it is the average over
/// them that would not be.
class NotEnoughDaysCard extends StatelessWidget {
  const NotEnoughDaysCard({
    super.key,
    required this.summary,
    required this.periodNoun,
  });

  final PeriodSummary summary;

  /// "week" or "month", for the sentence.
  final String periodNoun;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    final logged = summary.loggedDayCount;

    return NourishlyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            logged == 0
                ? 'Nothing logged this $periodNoun yet.'
                : logged == 1
                ? 'One logged day this $periodNoun.'
                : '$logged logged days this $periodNoun.',
            style: text.body.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: NourishlySpace.s2),
          Text(
            'Averages need at least ${PeriodHonesty.minDaysForAverages} '
            'logged days. Below that an average is noise rather than a '
            'pattern, so the days themselves are shown instead.',
            style: text.caption.copyWith(color: colors.ink3, height: 1.5),
          ),
        ],
      ),
    );
  }
}

/// "Week of 3–9 Sep", or "Week of 28 Sep – 4 Oct" when it straddles two.
String formatWeekRange(DateTime start, DateTime end) {
  final sameMonth = start.month == end.month && start.year == end.year;
  return sameMonth
      ? 'Week of ${start.day}–${end.day} ${monthAbbreviation(end.month)}'
      : 'Week of ${start.day} ${monthAbbreviation(start.month)} – '
            '${end.day} ${monthAbbreviation(end.month)}';
}

/// "September", or "September 2025" once it is not this year — a bare
/// month name a year out of date is the kind of thing nobody notices.
String formatMonthTitle(DateTime month, {required DateTime today}) =>
    month.year == today.year
    ? monthName(month.month)
    : '${monthName(month.month)} ${month.year}';

/// A nutrient amount with its unit, at the registry's precision.
/// Anything in the thousands gets a separator: "2,221 mg" rather than
/// "2221 mg", which is a number people have to count the digits of.
String formatAmount(double amount, String unit, int precision) {
  if (unit == 'kcal') return formatThousands(amount);
  final figure = amount.abs() >= 1000
      ? formatThousands(amount)
      : amount.toStringAsFixed(precision);
  return '$figure $unit';
}

/// "over 6 logged days" — §25.6's denominator, in words.
String daysDenominator(int days) =>
    'over $days logged ${days == 1 ? 'day' : 'days'}';

/// "target met on 5 of 6 days" — or, for a nutrient that is a ceiling
/// rather than something to reach, "under the limit on 5 of 6 days".
/// "Met" reads as an achievement, which is the wrong word for sodium.
String metDenominator(int met, int of, {bool isLimit = false}) {
  final days = of == 1 ? 'day' : 'days';
  return isLimit
      ? 'under the limit on $met of $of $days'
      : 'target met on $met of $of $days';
}

/// Which nutrients a "short of it" finding may name.
///
/// Only a floor (or a plateau, which has one) can be missed. A range —
/// energy, and the macros derived as a share of it — is neither missed
/// nor met in that sense: being under a band is a different failure from
/// missing a floor, and listing carbs as "consistently short" beside an
/// energy average that reads fine is a contradiction rather than a
/// finding. The registry's `defaultCurveType` is no help here; it is
/// `floor` for everything. The curve that matters is the one on the
/// target actually in force (§21.3).
bool canBeShort(TargetCurveType? curve) =>
    curve == TargetCurveType.floor || curve == TargetCurveType.plateau;

/// And which a "went over it" finding may name: a ceiling, or a plateau's
/// upper limit.
bool canBeOver(TargetCurveType? curve) =>
    curve == TargetCurveType.ceiling || curve == TargetCurveType.plateau;
