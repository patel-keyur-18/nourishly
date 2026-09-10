import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly_data/nourishly_data.dart';

void main() {
  late NourishlyDatabase db;

  setUp(() => db = NourishlyDatabase.forTesting());
  tearDown(() => db.close());

  test('creates a default profile when none exists', () async {
    final id = await ensureDefaultOwner(db);

    final users = await db.select(db.users).get();
    expect(users, hasLength(1));
    expect(users.single.id, id);
  });

  test(
    'returns the existing profile rather than creating a second one',
    () async {
      final first = await ensureDefaultOwner(db);
      final second = await ensureDefaultOwner(db);

      expect(second, first);
      expect(await db.select(db.users).get(), hasLength(1));
    },
  );
}
