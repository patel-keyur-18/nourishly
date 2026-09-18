import 'package:flutter/material.dart';

import '../tokens.g.dart';

/// One family throughout, per the Indigo direction — weight and size carry
/// hierarchy instead of a second face.
TextStyle _style(
  NourishlyTypeStyleSpec spec, {
  required Color color,
  required String fontFamily,
}) {
  return TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: const [NourishlyFontTokens.fallback],
    fontSize: spec.size,
    height: spec.lineHeight,
    fontWeight: FontWeight.values[(spec.weight ~/ 100) - 1],
    letterSpacing: spec.tracking,
    color: color,
    fontFeatures: spec.tabularNumerals
        ? const [FontFeature.tabularFigures()]
        : null,
  );
}

/// The nine named text styles from `typeScale`, resolved to concrete
/// [TextStyle]s for one ink colour. Prefer these over Material's
/// `textTheme` roles when a screen wants an exact token by name — e.g. the
/// large ring number is [numeral], not `displayLarge`.
@immutable
class NourishlyTypography {
  const NourishlyTypography({
    required this.display,
    required this.title,
    required this.heading,
    required this.bodyLarge,
    required this.body,
    required this.label,
    required this.caption,
    required this.overline,
    required this.numeral,
  });

  factory NourishlyTypography.forInk(Color ink) {
    TextStyle of(NourishlyTypeStyleSpec spec) =>
        _style(spec, color: ink, fontFamily: NourishlyFontTokens.display);
    return NourishlyTypography(
      display: of(NourishlyTypeScale.display),
      title: of(NourishlyTypeScale.title),
      heading: of(NourishlyTypeScale.heading),
      bodyLarge: of(NourishlyTypeScale.bodyLarge),
      body: of(NourishlyTypeScale.body),
      label: of(NourishlyTypeScale.label),
      caption: of(NourishlyTypeScale.caption),
      overline: of(NourishlyTypeScale.overline),
      numeral: of(NourishlyTypeScale.numeral),
    );
  }

  final TextStyle display;
  final TextStyle title;
  final TextStyle heading;
  final TextStyle bodyLarge;
  final TextStyle body;
  final TextStyle label;
  final TextStyle caption;
  final TextStyle overline;
  final TextStyle numeral;
}

/// Maps the token type scale onto Flutter's [TextTheme] roles, so ordinary
/// Material widgets (buttons, dialogs, list tiles) inherit Nourishly type
/// without every screen reaching for [NourishlyTypography] directly.
TextTheme buildNourishlyTextTheme(Color ink, Color ink3) {
  final typography = NourishlyTypography.forInk(ink);
  return TextTheme(
    displayLarge: typography.display,
    titleLarge: typography.title,
    titleMedium: typography.heading,
    bodyLarge: typography.bodyLarge,
    bodyMedium: typography.body,
    labelLarge: typography.label,
    bodySmall: typography.caption.copyWith(color: ink3),
    labelSmall: typography.overline.copyWith(color: ink3),
    headlineMedium: typography.numeral,
  );
}
