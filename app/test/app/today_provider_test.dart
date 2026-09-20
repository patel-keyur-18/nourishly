import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly/app/providers.dart';
import 'package:nourishly_domain/nourishly_domain.dart';

/// The day boundary while the app is open (FR-U-08).
///
/// `testWidgets` rather than `test`: it runs the body inside a fake async
/// zone, so [Today]'s rollover timer is under the test's control instead
/// of waiting out a real night.
void main() {
  ProviderContainer containerAt(FakeClock clock, {int rolloverMinutes = 0}) {
    return ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(clock),
        dayRolloverMinutesProvider.overrideWithValue(rolloverMinutes),
      ],
    );
  }

  testWidgets('the day moves on when the rollover passes', (tester) async {
    final clock = FakeClock(DateTime(2026, 9, 19, 23, 50));
    final container = containerAt(clock);
    addTearDown(container.dispose);

    expect(container.read(todayProvider), DateTime(2026, 9, 19));

    clock.set(DateTime(2026, 9, 20, 0, 1));
    await tester.pump(const Duration(minutes: 11));

    expect(
      container.read(todayProvider),
      DateTime(2026, 9, 20),
      reason: 'a dashboard left open overnight must not still say Today',
    );
    container.dispose();
  });

  testWidgets('a 4am rollover holds the day until 4am', (tester) async {
    final clock = FakeClock(DateTime(2026, 9, 19, 23, 50));
    final container = containerAt(clock, rolloverMinutes: 4 * 60);
    addTearDown(container.dispose);

    expect(container.read(todayProvider), DateTime(2026, 9, 19));

    clock.set(DateTime(2026, 9, 20, 0, 30));
    await tester.pump(const Duration(minutes: 45));
    expect(
      container.read(todayProvider),
      DateTime(2026, 9, 19),
      reason: 'midnight is not the boundary when the profile set one',
    );

    clock.set(DateTime(2026, 9, 20, 4, 5));
    await tester.pump(const Duration(hours: 4));
    expect(container.read(todayProvider), DateTime(2026, 9, 20));
    container.dispose();
  });

  testWidgets('a resume after the boundary catches up', (tester) async {
    final clock = FakeClock(DateTime(2026, 9, 19, 23, 50));
    final container = containerAt(clock);
    addTearDown(container.dispose);

    expect(container.read(todayProvider), DateTime(2026, 9, 19));

    // What a suspended device looks like: the clock jumped, the timer
    // never fired. This is the call `NourishlyApp` makes on resume.
    clock.set(DateTime(2026, 9, 21, 9, 0));
    container.read(todayProvider.notifier).refresh();

    expect(container.read(todayProvider), DateTime(2026, 9, 21));
    container.dispose();
  });
}
