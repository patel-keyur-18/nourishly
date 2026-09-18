import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly_data/nourishly_data.dart';

void main() {
  late NourishlyDatabase db;
  late WaterLogDao dao;
  late String ownerId;
  late DateTime logDate;

  setUp(() async {
    db = NourishlyDatabase.forTesting();
    ownerId = await ensureDefaultOwner(db);
    dao = WaterLogDao(db);
    logDate = DateTime(2026, 1, 1);
  });
  tearDown(() => db.close());

  test('edit replaces the amount (FR-W-07)', () async {
    final id = await dao.logWater(
      ownerId: ownerId,
      volumeMl: 250,
      logDate: logDate,
    );

    await dao.edit(entryId: id, volumeMl: 400);

    final today = await dao
        .watchToday(ownerId: ownerId, logDate: logDate)
        .first;
    expect(today, hasLength(1));
    expect(today.single.volumeMl, 400);
    expect(
      await dao.watchTodayTotal(ownerId: ownerId, logDate: logDate).first,
      400,
    );
  });

  test(
    'the original row survives as a soft-deleted fact, not an overwrite',
    () async {
      final id = await dao.logWater(
        ownerId: ownerId,
        volumeMl: 250,
        logDate: logDate,
      );

      final replacementId = await dao.edit(entryId: id, volumeMl: 400);

      expect(replacementId, isNot(id));
      final original = await (db.select(
        db.waterLogEntries,
      )..where((e) => e.id.equals(id))).getSingle();
      expect(
        original.volumeMl,
        250,
        reason: 'the original amount is untouched',
      );
      expect(original.deletedAt, isNotNull);
    },
  );

  test('an edited entry keeps its place in the day', () async {
    final first = await dao.logWater(
      ownerId: ownerId,
      volumeMl: 250,
      logDate: logDate,
    );
    await dao.logWater(ownerId: ownerId, volumeMl: 500, logDate: logDate);

    await dao.edit(entryId: first, volumeMl: 300);

    final today = await dao
        .watchToday(ownerId: ownerId, logDate: logDate)
        .first;
    expect(today.map((e) => e.volumeMl), [500, 300]);
  });

  test('undo then restore brings an entry back', () async {
    final id = await dao.logWater(
      ownerId: ownerId,
      volumeMl: 250,
      logDate: logDate,
    );

    await dao.undo(id);
    expect(
      await dao.watchToday(ownerId: ownerId, logDate: logDate).first,
      isEmpty,
    );

    await dao.restore(id);
    expect(
      await dao.watchToday(ownerId: ownerId, logDate: logDate).first,
      hasLength(1),
    );
  });
}
