import 'package:flutter/material.dart';

import '../theme/nourishly_theme.dart';
import '../tokens.g.dart';

/// The prototype's `.lr` — one row of a grouped list.
///
/// Prototype 13A is "a grouped list: familiar platform pattern, dense,
/// scannable, nothing to read", and its rows are all one shape: a label on
/// the left, the current value on the right, a chevron if tapping goes
/// somewhere. Before this existed, four screens each drew that row
/// themselves, with four different paddings and two different ideas about
/// where the chevron goes.
///
/// Variants, all from the prototype's own CSS: `.lr-tap` (tappable, with a
/// chevron), `.lr-accent` (an additive action, e.g. "+ Add a profile"),
/// `.dgr` (the destructive one), and a trailing switch for the rows that
/// toggle rather than open.
class NourishlyListRow extends StatelessWidget {
  const NourishlyListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.value,
    this.onTap,
    this.leading,
    this.trailing,
    this.showChevron = true,
    this.style = NourishlyRowStyle.plain,
    this.toggled,
  });

  /// A row whose trailing control is a switch. The whole row toggles, so
  /// the target is the row rather than the 40-odd pixels of the switch
  /// itself (NFR-A-03).
  factory NourishlyListRow.switched({
    Key? key,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return NourishlyListRow(
      key: key,
      title: title,
      subtitle: subtitle,
      showChevron: false,
      onTap: () => onChanged(!value),
      toggled: value,
      trailing: _RowSwitch(value: value, onChanged: onChanged),
    );
  }

  final String title;
  final String? subtitle;

  /// The prototype's `.lr-r` — the current setting, read-only, right
  /// aligned next to the chevron.
  final String? value;

  final VoidCallback? onTap;
  final Widget? leading;
  final Widget? trailing;
  final bool showChevron;
  final NourishlyRowStyle style;

  /// Set by [NourishlyListRow.switched] so the row announces itself as a
  /// switch that is on or off, rather than as a button.
  final bool? toggled;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;

    final titleColor = switch (style) {
      NourishlyRowStyle.plain => colors.ink,
      NourishlyRowStyle.accent => colors.accent,
      NourishlyRowStyle.danger => colors.danger,
    };
    final titleWeight = style == NourishlyRowStyle.plain
        ? FontWeight.w500
        : FontWeight.w700;

    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: NourishlyTarget.minTouch),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: NourishlySpace.s4,
          vertical: NourishlySpace.s3,
        ),
        child: Row(
          children: [
            if (leading != null)
              Padding(
                padding: const EdgeInsets.only(right: NourishlySpace.s3),
                child: leading,
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: text.body.copyWith(
                      color: titleColor,
                      fontWeight: titleWeight,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: text.caption.copyWith(
                        color: colors.ink3,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (value != null && value!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: NourishlySpace.s3),
                child: ConstrainedBox(
                  // Half the row at most: a long value ellipsises rather
                  // than squeezing the label it belongs to.
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width * 0.42,
                  ),
                  child: Text(
                    value!,
                    textAlign: TextAlign.right,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.caption.copyWith(color: colors.ink3),
                  ),
                ),
              ),
            if (trailing != null)
              Padding(
                padding: const EdgeInsets.only(left: NourishlySpace.s2),
                child: trailing,
              ),
            if (trailing == null && showChevron && onTap != null)
              Padding(
                padding: const EdgeInsets.only(left: NourishlySpace.s1),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: colors.ink3,
                ),
              ),
          ],
        ),
      ),
    );

    if (onTap == null) return row;

    // One node for the whole row, carrying the tap action: the row is the
    // target, so a screen reader should land on it once and be able to
    // activate it — not land on a label, then separately on a switch with
    // no name.
    return Semantics(
      button: toggled == null,
      toggled: toggled,
      label: title,
      value: [
        ?subtitle,
        if (value != null && value!.isNotEmpty) value!,
      ].join('. '),
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(onTap: onTap, child: row),
      ),
    );
  }
}

enum NourishlyRowStyle { plain, accent, danger }

/// Excluded from semantics: the row around it already announces itself as
/// a button with the right label, and a bare switch inside it would be a
/// second, unlabelled control for a screen reader to land on.
class _RowSwitch extends StatelessWidget {
  const _RowSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Switch(value: value, onChanged: onChanged),
    );
  }
}

/// A divided group of [NourishlyListRow]s inside the prototype's card —
/// hairline rules between rows, none at the ends.
class NourishlyRowGroup extends StatelessWidget {
  const NourishlyRowGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    return Material(
      color: colors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NourishlyRadius.lg),
        side: BorderSide(color: colors.line, width: NourishlyStroke.hairline),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: colors.line),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// The prototype's `.av` — a profile initial in a tinted circle. Stands in
/// for a photo the app does not store, and identifies a profile at a
/// glance without a second line of text.
class NourishlyAvatar extends StatelessWidget {
  const NourishlyAvatar({super.key, required this.name, this.size = 32});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: colors.accentSoft,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            initial,
            style: TextStyle(
              color: colors.accentSoftInk,
              fontWeight: FontWeight.w700,
              fontSize: size * 0.44,
            ),
          ),
        ),
      ),
    );
  }
}
