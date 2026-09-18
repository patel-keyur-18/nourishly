import 'package:flutter/material.dart';

import '../tokens.g.dart';

/// Theme extension carrying every colour token that has no equivalent slot
/// in Flutter's [ColorScheme] — status colours, the fixed macro series, and
/// the elevation shadow sets from `nourishly-indigo.json`.
///
/// Access via `Theme.of(context).extension<NourishlyColors>()!` or the
/// `context.nourishlyColors` extension getter.
@immutable
class NourishlyColors extends ThemeExtension<NourishlyColors> {
  const NourishlyColors({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.surface3,
    required this.line,
    required this.lineStrong,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.inkDisabled,
    required this.accent,
    required this.accentHover,
    required this.accentInk,
    required this.accentSoft,
    required this.accentSoftInk,
    required this.track,
    required this.focus,
    required this.scrim,
    required this.danger,
    required this.dangerSoft,
    required this.statusOk,
    required this.statusLow,
    required this.statusHigh,
    required this.statusUnknown,
    required this.seriesProtein,
    required this.seriesCarbs,
    required this.seriesFat,
    required this.seriesFibre,
    required this.elevation0,
    required this.elevation1,
    required this.elevation2,
    required this.elevation3,
  });

  factory NourishlyColors.light() => const NourishlyColors(
    bg: NourishlyLightColors.bg,
    surface: NourishlyLightColors.surface,
    surface2: NourishlyLightColors.surface2,
    surface3: NourishlyLightColors.surface3,
    line: NourishlyLightColors.line,
    lineStrong: NourishlyLightColors.lineStrong,
    ink: NourishlyLightColors.ink,
    ink2: NourishlyLightColors.ink2,
    ink3: NourishlyLightColors.ink3,
    inkDisabled: NourishlyLightColors.inkDisabled,
    accent: NourishlyLightColors.accent,
    accentHover: NourishlyLightColors.accentHover,
    accentInk: NourishlyLightColors.accentInk,
    accentSoft: NourishlyLightColors.accentSoft,
    accentSoftInk: NourishlyLightColors.accentSoftInk,
    track: NourishlyLightColors.track,
    focus: NourishlyLightColors.focus,
    scrim: NourishlyLightColors.scrim,
    danger: NourishlyLightColors.danger,
    dangerSoft: NourishlyLightColors.dangerSoft,
    statusOk: NourishlyLightColors.statusOk,
    statusLow: NourishlyLightColors.statusLow,
    statusHigh: NourishlyLightColors.statusHigh,
    statusUnknown: NourishlyLightColors.statusUnknown,
    seriesProtein: NourishlyLightColors.seriesProtein,
    seriesCarbs: NourishlyLightColors.seriesCarbs,
    seriesFat: NourishlyLightColors.seriesFat,
    seriesFibre: NourishlyLightColors.seriesFibre,
    elevation0: NourishlyLightColors.elevation0,
    elevation1: NourishlyLightColors.elevation1,
    elevation2: NourishlyLightColors.elevation2,
    elevation3: NourishlyLightColors.elevation3,
  );

  factory NourishlyColors.dark() => const NourishlyColors(
    bg: NourishlyDarkColors.bg,
    surface: NourishlyDarkColors.surface,
    surface2: NourishlyDarkColors.surface2,
    surface3: NourishlyDarkColors.surface3,
    line: NourishlyDarkColors.line,
    lineStrong: NourishlyDarkColors.lineStrong,
    ink: NourishlyDarkColors.ink,
    ink2: NourishlyDarkColors.ink2,
    ink3: NourishlyDarkColors.ink3,
    inkDisabled: NourishlyDarkColors.inkDisabled,
    accent: NourishlyDarkColors.accent,
    accentHover: NourishlyDarkColors.accentHover,
    accentInk: NourishlyDarkColors.accentInk,
    accentSoft: NourishlyDarkColors.accentSoft,
    accentSoftInk: NourishlyDarkColors.accentSoftInk,
    track: NourishlyDarkColors.track,
    focus: NourishlyDarkColors.focus,
    scrim: NourishlyDarkColors.scrim,
    danger: NourishlyDarkColors.danger,
    dangerSoft: NourishlyDarkColors.dangerSoft,
    statusOk: NourishlyDarkColors.statusOk,
    statusLow: NourishlyDarkColors.statusLow,
    statusHigh: NourishlyDarkColors.statusHigh,
    statusUnknown: NourishlyDarkColors.statusUnknown,
    seriesProtein: NourishlyDarkColors.seriesProtein,
    seriesCarbs: NourishlyDarkColors.seriesCarbs,
    seriesFat: NourishlyDarkColors.seriesFat,
    seriesFibre: NourishlyDarkColors.seriesFibre,
    elevation0: NourishlyDarkColors.elevation0,
    elevation1: NourishlyDarkColors.elevation1,
    elevation2: NourishlyDarkColors.elevation2,
    elevation3: NourishlyDarkColors.elevation3,
  );

  final Color bg;
  final Color surface;
  final Color surface2;
  final Color surface3;
  final Color line;
  final Color lineStrong;
  final Color ink;
  final Color ink2;
  final Color ink3;
  final Color inkDisabled;
  final Color accent;
  final Color accentHover;
  final Color accentInk;
  final Color accentSoft;
  final Color accentSoftInk;
  final Color track;
  final Color focus;
  final Color scrim;
  final Color danger;
  final Color dangerSoft;

  /// Exceeding a target uses [statusHigh] (violet), never [danger]. Red is
  /// reserved for destructive actions only — a food tracker must not scold.
  final Color statusOk;
  final Color statusLow;
  final Color statusHigh;
  final Color statusUnknown;

  /// Fixed series order: protein, carbs, fat, fibre. Never cycled or
  /// reassigned by rank, and never reused for status.
  final Color seriesProtein;
  final Color seriesCarbs;
  final Color seriesFat;
  final Color seriesFibre;

  final List<BoxShadow> elevation0;
  final List<BoxShadow> elevation1;
  final List<BoxShadow> elevation2;
  final List<BoxShadow> elevation3;

  @override
  NourishlyColors copyWith({
    Color? bg,
    Color? surface,
    Color? surface2,
    Color? surface3,
    Color? line,
    Color? lineStrong,
    Color? ink,
    Color? ink2,
    Color? ink3,
    Color? inkDisabled,
    Color? accent,
    Color? accentHover,
    Color? accentInk,
    Color? accentSoft,
    Color? accentSoftInk,
    Color? track,
    Color? focus,
    Color? scrim,
    Color? danger,
    Color? dangerSoft,
    Color? statusOk,
    Color? statusLow,
    Color? statusHigh,
    Color? statusUnknown,
    Color? seriesProtein,
    Color? seriesCarbs,
    Color? seriesFat,
    Color? seriesFibre,
    List<BoxShadow>? elevation0,
    List<BoxShadow>? elevation1,
    List<BoxShadow>? elevation2,
    List<BoxShadow>? elevation3,
  }) {
    return NourishlyColors(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surface2: surface2 ?? this.surface2,
      surface3: surface3 ?? this.surface3,
      line: line ?? this.line,
      lineStrong: lineStrong ?? this.lineStrong,
      ink: ink ?? this.ink,
      ink2: ink2 ?? this.ink2,
      ink3: ink3 ?? this.ink3,
      inkDisabled: inkDisabled ?? this.inkDisabled,
      accent: accent ?? this.accent,
      accentHover: accentHover ?? this.accentHover,
      accentInk: accentInk ?? this.accentInk,
      accentSoft: accentSoft ?? this.accentSoft,
      accentSoftInk: accentSoftInk ?? this.accentSoftInk,
      track: track ?? this.track,
      focus: focus ?? this.focus,
      scrim: scrim ?? this.scrim,
      danger: danger ?? this.danger,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      statusOk: statusOk ?? this.statusOk,
      statusLow: statusLow ?? this.statusLow,
      statusHigh: statusHigh ?? this.statusHigh,
      statusUnknown: statusUnknown ?? this.statusUnknown,
      seriesProtein: seriesProtein ?? this.seriesProtein,
      seriesCarbs: seriesCarbs ?? this.seriesCarbs,
      seriesFat: seriesFat ?? this.seriesFat,
      seriesFibre: seriesFibre ?? this.seriesFibre,
      elevation0: elevation0 ?? this.elevation0,
      elevation1: elevation1 ?? this.elevation1,
      elevation2: elevation2 ?? this.elevation2,
      elevation3: elevation3 ?? this.elevation3,
    );
  }

  @override
  NourishlyColors lerp(ThemeExtension<NourishlyColors>? other, double t) {
    if (other is! NourishlyColors) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return NourishlyColors(
      bg: c(bg, other.bg),
      surface: c(surface, other.surface),
      surface2: c(surface2, other.surface2),
      surface3: c(surface3, other.surface3),
      line: c(line, other.line),
      lineStrong: c(lineStrong, other.lineStrong),
      ink: c(ink, other.ink),
      ink2: c(ink2, other.ink2),
      ink3: c(ink3, other.ink3),
      inkDisabled: c(inkDisabled, other.inkDisabled),
      accent: c(accent, other.accent),
      accentHover: c(accentHover, other.accentHover),
      accentInk: c(accentInk, other.accentInk),
      accentSoft: c(accentSoft, other.accentSoft),
      accentSoftInk: c(accentSoftInk, other.accentSoftInk),
      track: c(track, other.track),
      focus: c(focus, other.focus),
      scrim: c(scrim, other.scrim),
      danger: c(danger, other.danger),
      dangerSoft: c(dangerSoft, other.dangerSoft),
      statusOk: c(statusOk, other.statusOk),
      statusLow: c(statusLow, other.statusLow),
      statusHigh: c(statusHigh, other.statusHigh),
      statusUnknown: c(statusUnknown, other.statusUnknown),
      seriesProtein: c(seriesProtein, other.seriesProtein),
      seriesCarbs: c(seriesCarbs, other.seriesCarbs),
      seriesFat: c(seriesFat, other.seriesFat),
      seriesFibre: c(seriesFibre, other.seriesFibre),
      // Shadows don't interpolate meaningfully mid-theme-switch; snap at the
      // midpoint like most icon/asset swaps do.
      elevation0: t < 0.5 ? elevation0 : other.elevation0,
      elevation1: t < 0.5 ? elevation1 : other.elevation1,
      elevation2: t < 0.5 ? elevation2 : other.elevation2,
      elevation3: t < 0.5 ? elevation3 : other.elevation3,
    );
  }
}
