import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly_data/nourishly_data.dart';

void main() {
  late NourishlyDatabase db;
  late WaterLogDao dao;
  const ownerId = 'test-owner';
  final logDate = DateTime(2026, 1, 1);

  setUp(() async {
    db = NourishlyDatabase.forTesting();
    await db
        .into(db.users)
        .insert(
          UsersCompanion.insert(
            id: ownerId,
            displayName: 'Test',
            avatarColor: '#000',
          ),
        );
    dao = WaterLogDao(db);
  });
  tearDown(() => db.close());

  test('logs water and the total reflects it', () async {
    await dao.logWater(ownerId: ownerId, volumeMl: 250, logDate: logDate);
    await dao.logWater(ownerId: ownerId, volumeMl: 500, logDate: logDate);

    final total = await dao
        .watchTodayTotal(ownerId: ownerId, logDate: logDate)
        .first;
    expect(total, 750);
  });

  test('total is a live SUM, not a stored counter (I-9) — undo drops it immediately', () async {
    final id = await dao.logWater(
      ownerId: ownerId,
      volumeMl: 250,
      logDate: logDate,
    );
    await dao.logWater(ownerId: ownerId, volumeMl: 500, logDate: logDate);

    await dao.undo(id);

    final total = await dao
        .watchTodayTotal(ownerId: ownerId, logDate: logDate)
        .first;
    expect(total, 500);
  });

  test('entries on another day do not count toward today\'s total', () async {
    await dao.logWater(
      ownerId: ownerId,
      volumeMl: 250,
      logDate: DateTime(2026, 1, 2),
    );

    final total = await dao
        .watchTodayTotal(ownerId: ownerId, logDate: logDate)
        .first;
    expect(total, 0);
  });
}
