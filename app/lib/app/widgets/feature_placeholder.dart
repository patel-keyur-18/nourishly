import 'package:flutter/material.dart';
import 'package:nourishly_ui/nourishly_ui.dart';

/// A feature screen whose implementation lands in a later phase.
///
/// It says plainly what is coming and when, instead of showing an empty
/// screen — the same honesty rule the data model follows (AP-4): an
/// absence is stated, never disguised.
class FeaturePlaceholder extends StatelessWidget {
  const FeaturePlaceholder({
    super.key,
    required this.title,
    this.subtitle,
    this.showTitle = true,
    this.appBar = false,
  });

  final String title;
  final String? subtitle;

  /// Whether to render [title] as an inline heading above the card. Off
  /// when [appBar] already shows it.
  final bool showTitle;

  /// Whether this is a pushed screen that needs a back-navigable app bar
  /// (e.g. `/profile/goals`) rather than a root tab.
  final bool appBar;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;

    return Scaffold(
      appBar: appBar ? AppBar(title: Text(title)) : null,
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            NourishlySpace.s4,
            NourishlySpace.s2,
            NourishlySpace.s4,
            NourishlySpace.s4,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showTitle) Text(title, style: text.title),
              Expanded(
                child: Center(
                  child: NourishlyCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: NourishlySpace.s5,
                      vertical: NourishlySpace.s7,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.hourglass_empty_rounded,
                          color: colors.ink3,
                          size: 28,
                        ),
                        const SizedBox(height: NourishlySpace.s4),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: text.body.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: NourishlySpace.s2),
                        Text(
                          subtitle ?? 'Coming in a later phase.',
                          textAlign: TextAlign.center,
                          style: text.caption.copyWith(color: colors.ink3),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
