import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly_ui/nourishly_ui.dart';

/// NFR-A-01: "WCAG 2.2 AA contrast for all text and meaningful UI."
///
/// Checked here, against the tokens, rather than on a rendered screen.
/// Flutter's `textContrastGuideline` reports "3.52 at font size 12" — true,
/// but it names neither the ink nor the ground, and the fix is always a
/// token rather than a screen. This version names the pair.
///
/// **One pair currently fails, and is listed in [knownGaps] rather than
/// quietly excluded.** `ink3` is the secondary-text grey used for every
/// caption and every subtitle in the app, and at 3.90:1 on a card it is
/// below AA's 4.5:1 for text at that size. Darkening it to about `#686d84`
/// would clear the bar at 5.1:1 and is very close to indistinguishable —
/// but `tokens/nourishly-indigo.json` is the approved design system, the
/// prototype is generated from it, and a palette change is a design
/// decision rather than an implementation one. So it is recorded, not
/// taken.
void main() {
  /// WCAG 2.2 1.4.3: 4.5:1 for body text, 3:1 for large text (18pt, or
  /// 14pt bold) and for meaningful non-text graphics.
  const bodyMinimum = 4.5;
  const largeMinimum = 3.0;

  /// Pairs that do not meet the bar today, each with the reason it is
  /// still here. Anything not on this list must pass.
  const knownGaps = <String>{
    // The measured ratios, so the size of the gap is on the record: dark
    // mode is nearly there, light mode is not. Note `dark: ink3 on bg`
    // is absent — it passes at 4.90:1, which is why this list is
    // enumerated rather than written as "ink3 everywhere".
    'light: ink3 on surface', // 3.90:1
    'light: ink3 on bg', // 3.52:1
    'light: ink3 on surface2', // 3.28:1
    'dark: ink3 on surface', // 4.34:1
    'dark: ink3 on surface2', // 3.92:1
    // Disabled text is exempt from WCAG 1.4.3 by the specification
    // itself, and the token exists to look unavailable.
    'light: inkDisabled on surface',
    'light: inkDisabled on bg',
    'light: inkDisabled on surface2',
    'dark: inkDisabled on surface',
    'dark: inkDisabled on bg',
    'dark: inkDisabled on surface2',
  };

  for (final (mode, colors) in [
    ('light', NourishlyColors.light()),
    ('dark', NourishlyColors.dark()),
  ]) {
    group('$mode mode', () {
      final grounds = <String, Color>{
        'surface': colors.surface,
        'bg': colors.bg,
        'surface2': colors.surface2,
      };

      test('body text meets AA on every ground it is used on', () {
        final failures = <String>[];
        for (final ink in <String, Color>{
          'ink': colors.ink,
          'ink2': colors.ink2,
          'ink3': colors.ink3,
          'inkDisabled': colors.inkDisabled,
        }.entries) {
          for (final ground in grounds.entries) {
            final name = '$mode: ${ink.key} on ${ground.key}';
            final ratio = contrastRatio(ink.value, ground.value);
            if (ratio < bodyMinimum && !knownGaps.contains(name)) {
              failures.add('$name is ${ratio.toStringAsFixed(2)}:1');
            }
          }
        }
        expect(
          failures,
          isEmpty,
          reason:
              'These text colours are below WCAG AA (4.5:1). Fix the token '
              'in docs/design/tokens/nourishly-indigo.json and regenerate: '
              '${failures.join('; ')}',
        );
      });

      test('the accent carries white or near-black text legibly', () {
        expect(
          contrastRatio(colors.accentInk, colors.accent),
          greaterThanOrEqualTo(bodyMinimum),
          reason: 'the primary button label must be readable on the button',
        );
        expect(
          contrastRatio(colors.accentSoftInk, colors.accentSoft),
          greaterThanOrEqualTo(bodyMinimum),
        );
      });

      test('status colours are distinguishable as graphics (3:1)', () {
        // NFR-A-04 means status is never *only* a colour, but a dot that
        // cannot be seen is still a dot that cannot be seen.
        for (final status in <String, Color>{
          'statusOk': colors.statusOk,
          'statusLow': colors.statusLow,
          'statusHigh': colors.statusHigh,
          'danger': colors.danger,
        }.entries) {
          expect(
            contrastRatio(status.value, colors.surface),
            greaterThanOrEqualTo(largeMinimum),
            reason: '$mode: ${status.key} on surface',
          );
        }
      });

      test('the known gaps are still exactly the ones recorded', () {
        // If somebody fixes ink3, this fails and says to update the list
        // and the note above — a gap that has been closed should not go
        // on being described as open.
        final stillFailing = <String>{};
        for (final ink in <String, Color>{
          'ink3': colors.ink3,
          'inkDisabled': colors.inkDisabled,
        }.entries) {
          for (final ground in grounds.entries) {
            final name = '$mode: ${ink.key} on ${ground.key}';
            if (contrastRatio(ink.value, ground.value) < bodyMinimum) {
              stillFailing.add(name);
            }
          }
        }
        expect(
          stillFailing,
          knownGaps.where((g) => g.startsWith('$mode:')).toSet(),
          reason:
              'The recorded WCAG gaps have changed. If a token was '
              'darkened, remove it from knownGaps and from the note at the '
              'top of this file.',
        );
      });
    });
  }
}

/// WCAG 2.x relative luminance and contrast ratio.
@visibleForTesting
double contrastRatio(Color a, Color b) {
  final la = _relativeLuminance(a);
  final lb = _relativeLuminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

double _relativeLuminance(Color color) {
  double channel(double value) =>
      value <= 0.03928 ? value / 12.92 : math.pow((value + 0.055) / 1.055, 2.4)
          as double;
  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}
