import 'package:nutrition_core/nutrition_core.dart';
import 'package:test/test.dart';

void main() {
  group('Coverage', () {
    test('accepts values within 0..1', () {
      expect(Coverage(0.58).fraction, 0.58);
      expect(Coverage.none.fraction, 0);
      expect(Coverage.complete.fraction, 1);
    });

    test('rejects values outside 0..1', () {
      expect(() => Coverage(-0.01), throwsArgumentError);
      expect(() => Coverage(1.01), throwsArgumentError);
    });

    test('formats as a percentage', () {
      expect(Coverage(0.58).toString(), 'Coverage(58%)');
    });
  });
}
