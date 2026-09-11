import 'package:flutter/material.dart';

import '../theme/nourishly_theme.dart';
import '../tokens.g.dart';

/// The prototype's `.avg` — a period average, its value, and the
/// denominator it is stated against.
///
/// [note] is not decoration. §25.6 requires every average to display what
/// it was averaged over ("over 6 logged days", "target met on 5 of 6"), so
/// the row will not render without one.
class PeriodAverageRow extends StatelessWidget {
  const PeriodAverageRow({
    super.key,
    required this.label,
    required this.value,
    required this.note,
    this.showDivider = true,
    this.onTap,
  });

  final String label;
  final String value;

  /// The denominator, in words.
  final String note;

  final bool showDivider;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;

    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: NourishlySpace.s2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: text.caption.copyWith(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: colors.ink2,
                  ),
                ),
              ),
              const SizedBox(width: NourishlySpace.s3),
              Text(
                value,
                style: text.body.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: NourishlySpace.s1),
                Icon(Icons.chevron_right_rounded, size: 18, color: colors.ink3),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(
            note,
            style: text.caption.copyWith(fontSize: 10.5, color: colors.ink3),
          ),
        ],
      ),
    );

    return MergeSemantics(
      child: Column(
        children: [
          if (onTap == null) content else InkWell(onTap: onTap, child: content),
          if (showDivider) Divider(height: 1, thickness: 1, color: colors.line),
        ],
      ),
    );
  }
}

/// The prototype's `.cmp` — one period against the one before it.
///
/// Both values are named, never just the delta: §27.11 rules out a bare
/// "+12%", which hides what it is 12% of. [delta] is null when the
/// comparison was withheld, and then [note] carries the reason.
class PeriodComparisonRow extends StatelessWidget {
  const PeriodComparisonRow({
    super.key,
    required this.label,
    this.delta,
    this.direction = PeriodTrend.flat,
    this.note,
  });

  /// e.g. "vs August".
  final String label;

  /// Already formatted, sign included: "+6", "-140 kcal".
  final String? delta;

  final PeriodTrend direction;

  /// Shown under the row: the base being compared against, or the reason
  /// there is no comparison.
  final String? note;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;

    final tint = switch (direction) {
      PeriodTrend.up => colors.statusOk,
      PeriodTrend.down => colors.statusLow,
      PeriodTrend.flat => colors.ink2,
    };

    return MergeSemantics(
      child: Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.only(top: 9),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colors.line)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: text.caption.copyWith(color: colors.ink3),
                  ),
                ),
                const SizedBox(width: NourishlySpace.s2),
                if (delta != null) ...[
                  // Never colour alone (NFR-A-04): the arrow and the sign
                  // both say which way it went.
                  Icon(direction.icon, size: 15, color: tint),
                  const SizedBox(width: 2),
                  Text(
                    delta!,
                    style: text.body.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: tint,
                    ),
                  ),
                ] else
                  Text(
                    'Not compared',
                    style: text.caption.copyWith(color: colors.ink3),
                  ),
              ],
            ),
            if (note != null) ...[
              const SizedBox(height: 2),
              Text(
                note!,
                style: text.caption.copyWith(
                  fontSize: 10.5,
                  color: colors.ink3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Which way a compared number moved. `flat` is a real answer — it means
/// "looked, and it did not move enough to say" (§25.6), which is not the
/// same as no comparison at all.
enum PeriodTrend {
  up(Icons.arrow_upward_rounded),
  down(Icons.arrow_downward_rounded),
  flat(Icons.remove_rounded);

  const PeriodTrend(this.icon);

  final IconData icon;
}
