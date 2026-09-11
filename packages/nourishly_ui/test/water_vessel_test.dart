import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly_ui/nourishly_ui.dart';

/// The bug these cover: the vessel used to paint `accentSoft` over
/// `track`, two tokens four hex values apart, so the water was rendered
/// and invisible — the number went up and the glass stayed empty.
void main() {
  Widget host(Widget child) => MaterialApp(
    theme: NourishlyTheme.light(),
    home: Scaffold(body: Center(child: child)),
  );

  WaterVesselPainter painterIn(WidgetTester tester) => tester
      .widgetList<CustomPaint>(
        find.descendant(
          of: find.byType(WaterVessel),
          matching: find.byType(CustomPaint),
        ),
      )
      .map((w) => w.painter)
      .whereType<WaterVesselPainter>()
      .single;

  testWidgets('the level rises to the logged proportion', (tester) async {
    await tester.pumpWidget(
      host(const WaterVessel(totalMl: 1300, goalMl: 2600)),
    );

    // Starts empty and pours in, rather than snapping to the answer.
    expect(painterIn(tester).level, 0);
    await tester.pump(const Duration(milliseconds: 300));
    final partway = painterIn(tester).level;
    expect(partway, greaterThan(0));
    expect(partway, lessThan(0.5));

    await tester.pumpAndSettle();
    expect(painterIn(tester).level, closeTo(0.5, 1e-9));
  });

  testWidgets('adding water raises the level rather than leaving it', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const WaterVessel(totalMl: 500, goalMl: 2000)),
    );
    await tester.pumpAndSettle();
    expect(painterIn(tester).level, closeTo(0.25, 1e-9));

    await tester.pumpWidget(
      host(const WaterVessel(totalMl: 1000, goalMl: 2000)),
    );
    await tester.pump(const Duration(milliseconds: 200));
    final rising = painterIn(tester).level;
    expect(rising, greaterThan(0.25));
    expect(rising, lessThan(0.5));

    await tester.pumpAndSettle();
    expect(painterIn(tester).level, closeTo(0.5, 1e-9));
  });

  testWidgets('the water is drawn in the accent, not in a track shade', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const WaterVessel(totalMl: 1300, goalMl: 2600)),
    );
    await tester.pumpAndSettle();

    final painter = painterIn(tester);
    expect(painter.color, NourishlyLightColors.accent);
    expect(painter.color, isNot(NourishlyLightColors.track));
    expect(painter.color, isNot(NourishlyLightColors.accentSoft));
  });

  testWidgets('overshooting the goal fills the vessel and stops there', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const WaterVessel(totalMl: 4000, goalMl: 2600)),
    );
    await tester.pumpAndSettle();
    expect(painterIn(tester).level, 1);
  });

  testWidgets('the surface stills instead of rippling forever', (tester) async {
    await tester.pumpWidget(
      host(const WaterVessel(totalMl: 1300, goalMl: 2600)),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(painterIn(tester).ripple, greaterThan(0));
    expect(painterIn(tester).ripple, lessThan(1));

    // An animation that never ends is an animation that drains a battery
    // on a screen people leave open — and one no test can settle.
    await tester.pumpAndSettle();
    expect(painterIn(tester).ripple, 1);
  });

  testWidgets('a goal of zero paints nothing rather than dividing by it', (
    tester,
  ) async {
    await tester.pumpWidget(host(const WaterVessel(totalMl: 500, goalMl: 0)));
    await tester.pumpAndSettle();
    expect(painterIn(tester).level, 0);
  });
}
