import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly_ui/nourishly_ui.dart';

void main() {
  group('NourishlyTheme', () {
    test(
      'light theme carries the NourishlyColors extension with token values',
      () {
        final theme = NourishlyTheme.light();
        final colors = theme.extension<NourishlyColors>();
        expect(colors, isNotNull);
        expect(colors!.accent, NourishlyLightColors.accent);
        expect(colors.bg, NourishlyLightColors.bg);
        expect(theme.brightness, Brightness.light);
      },
    );

    test(
      'dark theme carries the NourishlyColors extension with token values',
      () {
        final theme = NourishlyTheme.dark();
        final colors = theme.extension<NourishlyColors>();
        expect(colors, isNotNull);
        expect(colors!.accent, NourishlyDarkColors.accent);
        expect(colors.bg, NourishlyDarkColors.bg);
        expect(theme.brightness, Brightness.dark);
      },
    );

    test('overTargetIsNotRed: statusHigh is distinct from danger in both themes', () {
      // architecture rule (tokens.rules.overTargetIsNotRed / §21.8): exceeding
      // a target must never render in the destructive-action colour.
      expect(
        NourishlyLightColors.statusHigh,
        isNot(NourishlyLightColors.danger),
      );
      expect(NourishlyDarkColors.statusHigh, isNot(NourishlyDarkColors.danger));
    });

    test('series colours are distinct from the accent in both themes', () {
      // "An earlier draft had the accent equal to the carbs hue, which made
      // brand and measurement indistinguishable on screen." — tokens.validation.notes
      for (final series in [
        NourishlyLightColors.seriesProtein,
        NourishlyLightColors.seriesCarbs,
        NourishlyLightColors.seriesFat,
        NourishlyLightColors.seriesFibre,
      ]) {
        expect(series, isNot(NourishlyLightColors.accent));
      }
    });

    testWidgets(
      'NourishlyTypography.forInk resolves tabular numerals on numeral',
      (tester) async {
        final typography = NourishlyTypography.forInk(NourishlyLightColors.ink);
        expect(
          typography.numeral.fontFeatures,
          contains(const FontFeature.tabularFigures()),
        );
        expect(typography.body.fontFeatures, isNull);
      },
    );

    testWidgets('context.nourishlyColors resolves inside a themed app', (
      tester,
    ) async {
      late BuildContext capturedContext;
      await tester.pumpWidget(
        MaterialApp(
          theme: NourishlyTheme.light(),
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(
        capturedContext.nourishlyColors.accent,
        NourishlyLightColors.accent,
      );
    });
  });
}
