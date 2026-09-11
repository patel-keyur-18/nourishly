import 'package:flutter/material.dart';
import 'package:nourishly_ui/nourishly_ui.dart';
import 'package:nutrition_core/nutrition_core.dart';

/// The prototype's `.dh` row: the date, the profile name, and the score
/// chip — plus §27.2 item 1's quick navigation to adjacent days.
class DayHeader extends StatelessWidget {
  const DayHeader({
    super.key,
    required this.date,
    required this.score,
    this.profileName,
    this.title,
    this.onPreviousDay,
    this.onNextDay,
  });

  final DateTime date;
  final DailyScore score;

  /// The prototype's `.dh-w` line. Shown on today, where the date above it
  /// already says which day this is; on any other day the relative label
  /// ("Yesterday") is the more useful thing to put there.
  final String? profileName;

  final String? title;

  /// Null disables the arrow — there is no navigating into the future.
  final VoidCallback? onPreviousDay;
  final VoidCallback? onNextDay;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;

    return Row(
      children: [
        if (onPreviousDay != null)
          _DayArrow(
            icon: Icons.chevron_left_rounded,
            tooltip: 'Previous day',
            onPressed: onPreviousDay,
          ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatLongDate(date),
                style: text.caption.copyWith(color: colors.ink3),
              ),
              const SizedBox(height: 2),
              Text(title ?? _headline(date, profileName), style: text.title),
            ],
          ),
        ),
        const SizedBox(width: NourishlySpace.s2),
        // Flexible here rather than inside ScoreChip: the chip is also used
        // in the Insights list inside a shrink-wrapped Row, where a flex
        // child has no width to expand into and throws.
        Flexible(child: ScoreChip(score: score)),
        if (onNextDay != null)
          _DayArrow(
            icon: Icons.chevron_right_rounded,
            tooltip: 'Next day',
            onPressed: onNextDay,
          ),
      ],
    );
  }
}

class _DayArrow extends StatelessWidget {
  const _DayArrow({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      color: context.nourishlyColors.ink3,
    );
  }
}

/// The score as §21.6 requires it: a band *and* a number, never a bare
/// number, and a withheld score states its reason instead of showing a
/// blank or a zero.
class ScoreChip extends StatelessWidget {
  const ScoreChip({super.key, required this.score});

  final DailyScore score;

  @override
  Widget build(BuildContext context) {
    if (score.isWithheld) {
      return StatusChip(
        label: switch (score.withheldReason!) {
          ScoreWithheldReason.dayIncomplete => 'In progress',
          ScoreWithheldReason.looksIncompletelyLogged => 'Partly logged',
          ScoreWithheldReason.nothingLogged => 'Nothing logged',
          ScoreWithheldReason.noTargets => 'No targets yet',
          ScoreWithheldReason.allComponentsExcluded => 'Not enough data',
        },
        status: NourishlyStatus.unknown,
      );
    }
    return StatusChip(
      label: '${score.band!.label} ${score.composite!.round()}',
      status: switch (score.band!) {
        ScoreBand.excellent || ScoreBand.good => NourishlyStatus.ok,
        ScoreBand.fair => NourishlyStatus.unknown,
        ScoreBand.needsAttention => NourishlyStatus.low,
      },
    );
  }
}

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "Thursday, 9 Sep" — the prototype's date format.
String formatLongDate(DateTime date) =>
    '${_weekdays[date.weekday - 1]}, ${date.day} ${_months[date.month - 1]}';

String _headline(DateTime date, String? profileName) {
  final label = relativeDayLabel(date);
  if (label == 'Today' && profileName != null && profileName.isNotEmpty) {
    return profileName;
  }
  return label;
}

String relativeDayLabel(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);
  final difference = today.difference(target).inDays;
  return switch (difference) {
    0 => 'Today',
    1 => 'Yesterday',
    _ => '$difference days ago',
  };
}
