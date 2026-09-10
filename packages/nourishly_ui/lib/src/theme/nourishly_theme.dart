import 'package:flutter/material.dart';

import '../tokens.g.dart';
import 'nourishly_colors.dart';
import 'nourishly_typography.dart';

/// Builds the light and dark [ThemeData] for Nourishly, generated from
/// `docs/design/tokens/nourishly-indigo.json`. Both themes share shape and
/// motion tokens; only colour differs.
abstract final class NourishlyTheme {
  static ThemeData light() => _build(NourishlyColors.light(), Brightness.light);

  static ThemeData dark() => _build(NourishlyColors.dark(), Brightness.dark);

  static ThemeData _build(NourishlyColors colors, Brightness brightness) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: colors.accent,
      onPrimary: colors.accentInk,
      secondary: colors.accentSoft,
      onSecondary: colors.accentSoftInk,
      error: colors.danger,
      onError: brightness == Brightness.light ? Colors.white : colors.ink,
      errorContainer: colors.dangerSoft,
      onErrorContainer: colors.danger,
      surface: colors.surface,
      onSurface: colors.ink,
      surfaceContainerHighest: colors.surface2,
      surfaceContainerHigh: colors.surface2,
      surfaceContainer: colors.surface,
      surfaceContainerLow: colors.surface,
      surfaceContainerLowest: colors.bg,
      onSurfaceVariant: colors.ink2,
      outline: colors.line,
      outlineVariant: colors.lineStrong,
      shadow: Colors.black,
      scrim: colors.scrim,
      inverseSurface: colors.ink,
      onInverseSurface: colors.surface,
      inversePrimary: colors.accentSoft,
      primaryContainer: colors.accentSoft,
      onPrimaryContainer: colors.accentSoftInk,
      secondaryContainer: colors.surface2,
      onSecondaryContainer: colors.ink,
      tertiary: colors.statusHigh,
      onTertiary: colors.surface,
    );

    final textTheme = buildNourishlyTextTheme(colors.ink, colors.ink3);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colors.bg,
      canvasColor: colors.bg,
      fontFamily: NourishlyFontTokens.display,
      textTheme: textTheme,
      dividerColor: colors.line,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        backgroundColor: colors.bg,
        foregroundColor: colors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleLarge,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NourishlyRadius.lg),
          side: BorderSide(color: colors.line, width: NourishlyStroke.hairline),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.surface2,
        labelStyle: textTheme.bodySmall?.copyWith(
          color: colors.ink2,
          fontWeight: FontWeight.w600,
        ),
        side: BorderSide(color: colors.line, width: NourishlyStroke.hairline),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(
          horizontal: NourishlySpace.s3,
          vertical: NourishlySpace.s1,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.accent,
          foregroundColor: colors.accentInk,
          disabledBackgroundColor: colors.inkDisabled,
          minimumSize: const Size.fromHeight(NourishlyTarget.minTouch),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(NourishlyRadius.pill),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.ink,
          minimumSize: const Size.fromHeight(NourishlyTarget.minTouch),
          side: BorderSide(color: colors.line, width: NourishlyStroke.hairline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(NourishlyRadius.pill),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.accent,
          minimumSize: const Size(0, NourishlyTarget.minTouchCompact),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.accent,
        foregroundColor: colors.accentInk,
        elevation: 2,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colors.surface,
        selectedItemColor: colors.accent,
        unselectedItemColor: colors.ink3,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: textTheme.labelSmall,
        unselectedLabelStyle: textTheme.labelSmall,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surface,
        indicatorColor: colors.accentSoft,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            color: selected ? colors.accent : colors.ink3,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? colors.accent : colors.ink3);
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.accent,
        linearTrackColor: colors.track,
        circularTrackColor: colors.track,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NourishlyRadius.xl),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.ink,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: colors.surface),
        actionTextColor: colors.accentSoft,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NourishlyRadius.md),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colors.line,
        thickness: NourishlyStroke.hairline,
        space: 1,
      ),
      focusColor: colors.focus,
      extensions: [colors],
    );
  }
}

/// Convenience accessors: `context.nourishlyColors`, `context.nourishlyText`.
extension NourishlyThemeContext on BuildContext {
  NourishlyColors get nourishlyColors =>
      Theme.of(this).extension<NourishlyColors>()!;

  NourishlyTypography get nourishlyText =>
      NourishlyTypography.forInk(nourishlyColors.ink);
}
