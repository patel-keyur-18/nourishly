import 'package:nourishly_domain/nourishly_domain.dart';
import 'package:test/test.dart';

void main() {
  group('SystemClock', () {
    test('returns a value close to the real current time', () {
      const clock = SystemClock();
      final before = DateTime.now();
      final result = clock.now();
      final after = DateTime.now();

      expect(
        result.isAfter(before.subtract(const Duration(seconds: 1))),
        isTrue,
      );
      expect(result.isBefore(after.add(const Duration(seconds: 1))), isTrue);
    });
  });

  group('FakeClock', () {
    test('defaults to a fixed instant', () {
      final clock = FakeClock();
      expect(clock.now(), DateTime(2026, 1, 1));
    });

    test('can be constructed with an initial instant', () {
      final clock = FakeClock(DateTime(2026, 3, 4, 23, 59));
      expect(clock.now(), DateTime(2026, 3, 4, 23, 59));
    });

    test('set() pins the clock to an exact instant', () {
      final clock = FakeClock();
      clock.set(DateTime(2026, 9, 10, 5, 30));
      expect(clock.now(), DateTime(2026, 9, 10, 5, 30));
    });

    test('advance() moves the clock forward across a day boundary', () {
      final clock = FakeClock(DateTime(2026, 9, 10, 23, 55));
      clock.advance(const Duration(minutes: 10));
      expect(clock.now(), DateTime(2026, 9, 11, 0, 5));
    });

    test('advance() with a negative duration moves the clock backward', () {
      final clock = FakeClock(DateTime(2026, 9, 10, 0, 5));
      clock.advance(const Duration(minutes: -10));
      expect(clock.now(), DateTime(2026, 9, 9, 23, 55));
    });
  });
}
