import 'package:catalog_pipeline/catalog_pipeline.dart';
import 'package:test/test.dart';

void main() {
  group('nutrientRegistry', () {
    test('has exactly 24 nutrients: 5 macros + saturated fat + sugar + 17 micronutrients (§0.3)', () {
      expect(nutrientRegistry, hasLength(24));
    });

    test('every id is unique', () {
      final ids = nutrientRegistry.map((n) => n.id).toSet();
      expect(ids, hasLength(nutrientRegistry.length));
    });

    test('every nutrient names at least one FDC nutrient string', () {
      for (final n in nutrientRegistry) {
        expect(n.fdcNames, isNotEmpty, reason: n.id);
      }
    });

    test('every groupId is one of the declared nutrient groups', () {
      final groupIds = nutrientGroups.map((g) => g.$1).toSet();
      for (final n in nutrientRegistry) {
        expect(groupIds, contains(n.groupId), reason: n.id);
      }
    });
  });
}
