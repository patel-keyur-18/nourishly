@Tags(['perf'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly_data/nourishly_data.dart' hide ReminderRule;
import 'package:uuid/uuid.dart';

/// §7.4's performance budgets, measured against a database with a year of
/// logging in it rather than against the empty one every other test uses.
///
/// **On the numbers.** NFR-P-03 through NFR-P-07 are stated for "a 2022
/// mid-range Android"; this runs on whatever CI happens to be. Asserting
/// the literal budgets would produce a test that fails for reasons nobody
/// can act on, so each assertion is the budget times [ciHeadroom] — which
/// makes these order-of-magnitude regression guards, not device
/// benchmarks. A query that was 40 ms and becomes 60 ms will not fail
/// here; one that becomes 4 s will, and that is the class of mistake
/// worth catching automatically. The real device numbers belong to Phase
/// 6, on the phone the app actually ships to.
///
/// Every run prints its measurement, so the trend is visible in CI logs
/// even while the assertion stays loose.
void main() {
  /// CI machines are shared, cold, and frequently virtualised.
  const ciHeadroom = 10;

  const uuid = Uuid();
  late Directory dir;
  late NourishlyDatabase db;
  late String ownerId;
  final today = DateTime(2026, 9, 9);

  setUpAll(() async {
    // File-backed, because query plans over a real B-tree are the thing
    // being measured and an in-memory database flatters them.
    dir = Directory.systemTemp.createTempSync('nourishly-perf');
    db = NourishlyDatabase(
      NativeDatabase(File('${dir.path}/nourishly.sqlite')),
    );
    ownerId = await ensureDefaultOwner(db);

    final seed = jsonDecode(
      File('../../app/assets/catalog/seed_v1.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    await CatalogImporter(db).importIfNeeded(seed);
    await RdaImporter(db).importFromString(
      File('../../app/assets/reference/rda_icmr_nin_2020.json')
          .readAsStringSync(),
    );

    await _seedYearOfLogging(db, ownerId, today, uuid);
  });

  tearDownAll(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  /// Runs [action] a few times and returns the median, so one unlucky
  /// scheduling hiccup does not decide the result.
  Future<Duration> median(
    String label,
    Future<void> Function() action, {
    int runs = 5,
  }) async {
    final timings = <int>[];
    for (var i = 0; i < runs; i++) {
      final watch = Stopwatch()..start();
      await action();
      watch.stop();
      timings.add(watch.elapsedMicroseconds);
    }
    timings.sort();
    final result = Duration(microseconds: timings[timings.length ~/ 2]);
    // ignore: avoid_print
    print('$label: ${(result.inMicroseconds / 1000).toStringAsFixed(1)} ms');
    return result;
  }

  test(
    'NFR-P-03 — food search, keystroke to results (budget 120 ms)',
    () async {
      final dao = FoodSearchDao(db);
      // Character by character, as a user actually types: the budget is per
      // keystroke, and a prefix of two letters matches far more rows than
      // the finished word does.
      final elapsed = await median('search "paneer" (6 keystrokes)', () async {
        for (final prefix in const [
          'p',
          'pa',
          'pan',
          'pane',
          'panee',
          'paneer',
        ]) {
          await dao.search(prefix);
        }
      });
      expect(
        elapsed.inMilliseconds,
        lessThan(120 * ciHeadroom),
        reason:
            'Search is typed character by character; above ~150 ms it feels '
            'laggy and users stop trusting the results. This is the '
            'requirement that forces the local FTS index (§19.5).',
      );
    },
  );

  test(
    'NFR-P-05 — daily summary recompute after an edit (budget 100 ms)',
    () async {
      final dao = DailySummaryDao(db);
      final elapsed = await median('recompute one day', () async {
        await dao.markStale(ownerId: ownerId, logDate: today);
        await dao.summaryFor(ownerId: ownerId, logDate: today);
      });
      expect(elapsed.inMilliseconds, lessThan(100 * ciHeadroom));
    },
  );

  test(
    'NFR-P-04 — a logged entry is visible in the summary (budget 200 ms)',
    () async {
      final logging = FoodLoggingDao(db);
      final summaries = DailySummaryDao(db);
      final food = await (db.select(db.servingSizes)..limit(1)).getSingle();

      final elapsed = await median('log an entry, then read the day', () async {
        await logging.logFood(
          ownerId: ownerId,
          foodId: food.foodId,
          servingId: food.id,
          quantity: 1,
          mealSlotId: (await db.select(db.mealSlots).get()).first.id,
          logDate: today,
        );
        await summaries.summaryFor(ownerId: ownerId, logDate: today);
      });
      expect(elapsed.inMilliseconds, lessThan(200 * ciHeadroom));
    },
  );

  test(
    'NFR-P-06 — weekly report from materialised dailies (budget 400 ms)',
    () async {
      final dao = PeriodSummaryDao(db);
      final elapsed = await median('weekly report', () async {
        await dao.week(ownerId: ownerId, containing: today, now: today);
      });
      expect(
        elapsed.inMilliseconds,
        lessThan(400 * ciHeadroom),
        reason:
            'The whole point of materialising daily summaries (§25.4) is '
            'that a period report is a range scan rather than a '
            're-aggregation.',
      );
    },
  );

  test('NFR-P-07 — monthly report (budget 800 ms)', () async {
    final dao = PeriodSummaryDao(db);
    final elapsed = await median('monthly report', () async {
      await dao.month(ownerId: ownerId, containing: today, now: today);
    });
    expect(elapsed.inMilliseconds, lessThan(800 * ciHeadroom));
  });

  test('the hot queries use their indexes rather than scanning', () async {
    // The measurement above says "fast on this machine today". This says
    // "fast for the right reason", which is what survives the table
    // growing — and it is cheap and deterministic, unlike a timing.
    Future<String> planFor(String sql, List<Variable<Object>> vars) async {
      final rows = await db
          .customSelect('EXPLAIN QUERY PLAN $sql', variables: vars)
          .get();
      return rows.map((r) => r.data['detail']).join(' | ');
    }

    final dayPlan = await planFor(
      'SELECT * FROM food_log_entries WHERE owner_id = ? AND log_date = ?',
      [Variable<String>(ownerId), Variable<int>(1757376000)],
    );
    expect(
      dayPlan,
      contains('food_log_entries_owner_date'),
      reason: 'the dashboard\'s query must not scan the entry table: $dayPlan',
    );

    final rangePlan = await planFor(
      'SELECT * FROM daily_summaries WHERE owner_id = ? '
      'AND log_date BETWEEN ? AND ?',
      [
        Variable<String>(ownerId),
        Variable<int>(1754784000),
        Variable<int>(1757376000),
      ],
    );
    expect(
      rangePlan,
      contains('daily_summaries_owner_date'),
      reason: 'the period reports must not scan the summary table: $rangePlan',
    );

    final nutrientPlan = await planFor(
      'SELECT * FROM food_nutrient_values WHERE food_id = ?',
      [const Variable<String>('x')],
    );
    expect(nutrientPlan, contains('food_nutrient_values_food'));
  });

  test('NFR-P-09 — the database stays a sensible size', () async {
    // Not the installed app size, which is a build-time number, but the
    // part that grows with use and that nothing else measures.
    await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
    final bytes = File('${dir.path}/nourishly.sqlite').lengthSync();
    // ignore: avoid_print
    print(
      'Catalog + a year of logging + summaries: '
      '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB',
    );
    expect(bytes, lessThan(25 * 1024 * 1024));
  });
}

/// A year of one person's logging: three meals a day, two waters, and the
/// daily summaries a year of opening the app would have materialised.
Future<void> _seedYearOfLogging(
  NourishlyDatabase db,
  String ownerId,
  DateTime today,
  Uuid uuid,
) async {
  final slots = await db.select(db.mealSlots).get();
  final servings = await (db.select(db.servingSizes)..limit(40)).get();

  await db.batch((batch) {
    for (var day = 0; day < 365; day++) {
      final date = today.subtract(Duration(days: day));
      for (var meal = 0; meal < slots.length; meal++) {
        final serving = servings[(day + meal) % servings.length];
        batch.insert(
          db.foodLogEntries,
          FoodLogEntriesCompanion.insert(
            id: uuid.v7(),
            ownerId: ownerId,
            logDate: date,
            mealSlotId: slots[meal].id,
            foodId: serving.foodId,
            foodRevision: 1,
            servingSizeId: Value(serving.id),
            quantity: 1,
            gramsConsumed: serving.grams,
            loggedAt: date.add(Duration(hours: 8 + meal * 4)),
            source: 'manual',
          ),
        );
      }
      for (var pour = 0; pour < 2; pour++) {
        batch.insert(
          db.waterLogEntries,
          WaterLogEntriesCompanion.insert(
            id: uuid.v7(),
            ownerId: ownerId,
            logDate: date,
            loggedAt: date.add(Duration(hours: 9 + pour * 5)),
            volumeMl: 500,
            source: 'quick_add',
          ),
        );
      }
    }
  });

  // The nutrient snapshots every entry carries (I-1). Written in one
  // batch rather than through the DAO: this is a fixture, and going
  // through logFood 1,460 times would make the setup longer than the
  // measurements.
  final entries = await db.select(db.foodLogEntries).get();
  final values = await db.select(db.foodNutrientValues).get();
  final byFood = <String, List<FoodNutrientValue>>{};
  for (final value in values) {
    byFood.putIfAbsent(value.foodId, () => []).add(value);
  }
  await db.batch((batch) {
    for (final entry in entries) {
      for (final value in byFood[entry.foodId] ?? const []) {
        batch.insert(
          db.logEntryNutrients,
          LogEntryNutrientsCompanion.insert(
            entryId: entry.id,
            nutrientId: value.nutrientId,
            amount: value.amountPer100g * entry.gramsConsumed / 100,
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    }
  });

  // And the materialised dailies the reports read (§25.4).
  final dao = DailySummaryDao(db);
  for (var day = 0; day < 40; day++) {
    await dao.summaryFor(
      ownerId: ownerId,
      logDate: today.subtract(Duration(days: day)),
    );
  }
}
