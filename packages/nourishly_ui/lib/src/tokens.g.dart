// GENERATED CODE — do not hand-edit.
// Source: docs/design/tokens/nourishly-indigo.json (version 1.0.0, approved)
// Regenerate with: dart run tools/token_gen/generate_tokens.dart
// ignore_for_file: public_member_api_docs

import 'package:flutter/widgets.dart'
    show BoxShadow, Color, Cubic, Curve, Offset;

class NourishlyFontTokens {
  const NourishlyFontTokens._();

  static const String display = 'IBM Plex Sans';
  static const String body = 'IBM Plex Sans';
  static const String mono = 'IBM Plex Mono';
  static const String fallback =
      'system-ui, -apple-system, \'Segoe UI\', Roboto, sans-serif';
}

class NourishlyTypeStyleSpec {
  const NourishlyTypeStyleSpec({
    required this.size,
    required this.lineHeight,
    required this.weight,
    required this.tracking,
    this.uppercase = false,
    this.tabularNumerals = false,
  });

  /// Font size in logical pixels.
  final double size;

  /// Line height as a multiplier of [size].
  final double lineHeight;

  /// Font weight, 100-900.
  final int weight;

  /// Letter spacing in logical pixels, already resolved from the token's
  /// em-relative tracking value.
  final double tracking;

  final bool uppercase;
  final bool tabularNumerals;
}

class NourishlyTypeScale {
  const NourishlyTypeScale._();

  static const NourishlyTypeStyleSpec display = NourishlyTypeStyleSpec(
    size: 30.0,
    lineHeight: 1.12,
    weight: 700,
    tracking: -0.600000,
    uppercase: false,
    tabularNumerals: false,
  );

  static const NourishlyTypeStyleSpec title = NourishlyTypeStyleSpec(
    size: 21.0,
    lineHeight: 1.22,
    weight: 700,
    tracking: -0.315000,
    uppercase: false,
    tabularNumerals: false,
  );

  static const NourishlyTypeStyleSpec heading = NourishlyTypeStyleSpec(
    size: 17.0,
    lineHeight: 1.3,
    weight: 600,
    tracking: -0.170000,
    uppercase: false,
    tabularNumerals: false,
  );

  static const NourishlyTypeStyleSpec bodyLarge = NourishlyTypeStyleSpec(
    size: 15.0,
    lineHeight: 1.5,
    weight: 400,
    tracking: 0.000000,
    uppercase: false,
    tabularNumerals: false,
  );

  static const NourishlyTypeStyleSpec body = NourishlyTypeStyleSpec(
    size: 14.0,
    lineHeight: 1.5,
    weight: 400,
    tracking: 0.000000,
    uppercase: false,
    tabularNumerals: false,
  );

  static const NourishlyTypeStyleSpec label = NourishlyTypeStyleSpec(
    size: 13.0,
    lineHeight: 1.35,
    weight: 600,
    tracking: 0.000000,
    uppercase: false,
    tabularNumerals: false,
  );

  static const NourishlyTypeStyleSpec caption = NourishlyTypeStyleSpec(
    size: 12.0,
    lineHeight: 1.4,
    weight: 400,
    tracking: 0.060000,
    uppercase: false,
    tabularNumerals: false,
  );

  static const NourishlyTypeStyleSpec overline = NourishlyTypeStyleSpec(
    size: 11.0,
    lineHeight: 1.3,
    weight: 600,
    tracking: 0.990000,
    uppercase: true,
    tabularNumerals: false,
  );

  static const NourishlyTypeStyleSpec numeral = NourishlyTypeStyleSpec(
    size: 28.0,
    lineHeight: 1.0,
    weight: 700,
    tracking: -0.560000,
    uppercase: false,
    tabularNumerals: true,
  );
}

class NourishlySpace {
  const NourishlySpace._();

  static const double s0 = 0.0;
  static const double s1 = 4.0;
  static const double s2 = 8.0;
  static const double s3 = 12.0;
  static const double s4 = 16.0;
  static const double s5 = 20.0;
  static const double s6 = 24.0;
  static const double s7 = 32.0;
  static const double s8 = 40.0;
  static const double s9 = 48.0;
}

class NourishlyRadius {
  const NourishlyRadius._();

  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 22.0;
  static const double pill = 999.0;
}

class NourishlyStroke {
  const NourishlyStroke._();

  static const double hairline = 1.0;
  static const double bar = 9.0;
  static const double ring = 11.0;
  static const double tick = 2.0;
}

class NourishlyMotion {
  const NourishlyMotion._();

  static const Duration instant = Duration(milliseconds: 0);
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration base = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 320);

  /// Cubic bezier easing curve: cubic-bezier(0.2, 0, 0, 1)
  static const Curve easing = Cubic(0.2, 0, 0, 1);
}

class NourishlyTarget {
  const NourishlyTarget._();

  static const double minTouch = 48.0;
  static const double minTouchCompact = 44.0;
}

class NourishlyChart {
  const NourishlyChart._();

  /// Every progress track runs to this multiple of the target so overshoot
  /// stays visible; never fill a bar to its own edge at target.
  static const double trackToTargetRatio = 1.25;
}

/// The light palette, straight from
/// docs/design/tokens/nourishly-indigo.json `color.light`.
class NourishlyLightColors {
  const NourishlyLightColors._();

  static const Color bg = Color(0xFFf2f3f8);
  static const Color surface = Color(0xFFffffff);
  static const Color surface2 = Color(0xFFe9ebf4);
  static const Color surface3 = Color(0xFFffffff);
  static const Color line = Color(0xFFd6d9e8);
  static const Color lineStrong = Color(0xFFb9bed6);
  static const Color ink = Color(0xFF161829);
  static const Color ink2 = Color(0xFF4b4f66);
  static const Color ink3 = Color(0xFF7b8098);
  static const Color inkDisabled = Color(0xFFa3a7bb);
  static const Color accent = Color(0xFF3b4d9e);
  static const Color accentHover = Color(0xFF334389);
  static const Color accentInk = Color(0xFFffffff);
  static const Color accentSoft = Color(0xFFdfe3f4);
  static const Color accentSoftInk = Color(0xFF2c3a7a);
  static const Color track = Color(0xFFe3e6f1);
  static const Color focus = Color(0xFF3b4d9e);
  static const Color scrim = Color(0x70101222);
  static const Color danger = Color(0xFFa52a1f);
  static const Color dangerSoft = Color(0xFFf7e2df);

  // Status colours are reserved and never reused as a series colour; they
  // always ship with a label and a dot, never colour alone.
  static const Color statusOk = Color(0xFF2e7d4f);
  static const Color statusLow = Color(0xFFa06d0c);
  static const Color statusHigh = Color(0xFF7a5ea8);
  static const Color statusUnknown = Color(0xFF7b8098);

  // Series order is fixed: protein, carbs, fat, fibre. Hues are assigned by
  // slot and never cycled or reassigned by rank.
  static const Color seriesProtein = Color(0xFFc1572d);
  static const Color seriesCarbs = Color(0xFF1f6fa5);
  static const Color seriesFat = Color(0xFFc7961a);
  static const Color seriesFibre = Color(0xFF0f8a5e);

  static const List<BoxShadow> elevation0 = <BoxShadow>[];
  static const List<BoxShadow> elevation1 = <BoxShadow>[
    BoxShadow(
      color: Color(0x0F161829),
      offset: Offset(0, 1),
      blurRadius: 2,
      spreadRadius: 0,
    ),
  ];
  static const List<BoxShadow> elevation2 = <BoxShadow>[
    BoxShadow(
      color: Color(0x0F161829),
      offset: Offset(0, 2),
      blurRadius: 4,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Color(0x2E161829),
      offset: Offset(0, 8),
      blurRadius: 20,
      spreadRadius: -12,
    ),
  ];
  static const List<BoxShadow> elevation3 = <BoxShadow>[
    BoxShadow(
      color: Color(0x57161829),
      offset: Offset(0, 8),
      blurRadius: 34,
      spreadRadius: -14,
    ),
  ];
}

/// The dark palette, straight from
/// docs/design/tokens/nourishly-indigo.json `color.dark`.
class NourishlyDarkColors {
  const NourishlyDarkColors._();

  static const Color bg = Color(0xFF0f1119);
  static const Color surface = Color(0xFF161927);
  static const Color surface2 = Color(0xFF1e2233);
  static const Color surface3 = Color(0xFF222639);
  static const Color line = Color(0xFF2b3045);
  static const Color lineStrong = Color(0xFF3b4160);
  static const Color ink = Color(0xFFe9ebf6);
  static const Color ink2 = Color(0xFFa8adc4);
  static const Color ink3 = Color(0xFF787e96);
  static const Color inkDisabled = Color(0xFF5b6079);
  static const Color accent = Color(0xFF8b99ea);
  static const Color accentHover = Color(0xFF9da9ef);
  static const Color accentInk = Color(0xFF0e1018);
  static const Color accentSoft = Color(0xFF232847);
  static const Color accentSoftInk = Color(0xFFc3cbf7);
  static const Color track = Color(0xFF242940);
  static const Color focus = Color(0xFF8b99ea);
  static const Color scrim = Color(0x9E04050A);
  static const Color danger = Color(0xFFf0a49c);
  static const Color dangerSoft = Color(0xFF3a1f1c);

  // Status colours are reserved and never reused as a series colour; they
  // always ship with a label and a dot, never colour alone.
  static const Color statusOk = Color(0xFF4aa873);
  static const Color statusLow = Color(0xFFd0a03a);
  static const Color statusHigh = Color(0xFFa893d8);
  static const Color statusUnknown = Color(0xFF787e96);

  // Series order is fixed: protein, carbs, fat, fibre. Hues are assigned by
  // slot and never cycled or reassigned by rank.
  static const Color seriesProtein = Color(0xFFd16536);
  static const Color seriesCarbs = Color(0xFF3f92cf);
  static const Color seriesFat = Color(0xFFbb8a0c);
  static const Color seriesFibre = Color(0xFF2a9b6e);

  static const List<BoxShadow> elevation0 = <BoxShadow>[];
  static const List<BoxShadow> elevation1 = <BoxShadow>[
    BoxShadow(
      color: Color(0x80000000),
      offset: Offset(0, 1),
      blurRadius: 2,
      spreadRadius: 0,
    ),
  ];
  static const List<BoxShadow> elevation2 = <BoxShadow>[
    BoxShadow(
      color: Color(0x73000000),
      offset: Offset(0, 2),
      blurRadius: 4,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Color(0xB3000000),
      offset: Offset(0, 8),
      blurRadius: 20,
      spreadRadius: -12,
    ),
  ];
  static const List<BoxShadow> elevation3 = <BoxShadow>[
    BoxShadow(
      color: Color(0xCC000000),
      offset: Offset(0, 8),
      blurRadius: 34,
      spreadRadius: -14,
    ),
  ];
}
