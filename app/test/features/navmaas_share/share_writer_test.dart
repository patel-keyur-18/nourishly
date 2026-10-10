import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly/app/providers.dart';
import 'package:nourishly/features/food_catalog/data/food_catalog_providers.dart';
import 'package:nourishly/features/navmaas_share/data/share_writer.dart';
import 'package:nourishly_data/nourishly_data.dart';
import 'package:nourishly_domain/nourishly_domain.dart';

/// Keeping the Navmaas share file in step with her log (ADR-012).
void main() {
  late NourishlyDatabase db;
  late Directory dir;
  late ProviderContainer container;
  late String ownerId;
  const wait = Duration(milliseconds: 50);

  File shared() => File('${dir.path}/nourishly-share.json');

  /// Past the debounce, with time for the file to land.
  Future<void> settle() => Future<void>.delayed(wait * 6);

  Future<void> logPoha() async {
    await db
        .into(db.foodItems)
        .insert(
          FoodItemsCompanion.insert(
            id: 'poha',
            kind: 'recipe',
            canonicalName: 'Poha',
            qualityTier: 'derived',
            provenanceSource: 'catalog_pipeline_recipe',
          ),
          mode: InsertMode.insertOrIgnore,
        );
    await db
        .into(db.foodLogEntries)
        .insert(
          FoodLogEntriesCompanion.insert(
            id: 'entry-poha',
            ownerId: ownerId,
            logDate: DateTime(2026, 10, 10),
            mealSlotId: 'breakfast',
            foodId: 'poha',
            foodRevision: 1,
            quantity: 1,
            gramsConsumed: 150,
            loggedAt: DateTime(2026, 10, 10, 8),
            source: 'manual',
          ),
        );
  }

  Future<void> share(bool on) =>
      PreferencesDao(db).update(ownerId, shareWithNavmaas: on);

  setUp(() async {
    db = NourishlyDatabase.forTesting();
    ownerId = await ensureDefaultOwner(db);
    await db
        .into(db.mealSlots)
        .insert(
          MealSlotsCompanion.insert(
            id: 'breakfast',
            key: 'breakfast',
            displayName: 'Breakfast',
            sortOrder: 0,
          ),
        );
    dir = await Directory.systemTemp.createTemp('nourishly_share');
    container = ProviderContainer(
      overrides: [
        nourishlyDatabaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(
          FakeClock(DateTime(2026, 10, 10, 9, 40)),
        ),
        navmaasShareDirectoryProvider.overrideWithValue(() async => dir),
        navmaasShareDebounceProvider.overrideWithValue(wait),
      ],
    );
    container.read(navmaasShareWriterProvider);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
    await dir.delete(recursive: true);
  });

  test('off by default: nothing is written, even after logging', () async {
    await logPoha();
    await settle();
    expect(shared().existsSync(), isFalse);
  });

  test('turned on, the file holds her food', () async {
    await logPoha();
    await share(true);
    await settle();
    final json = jsonDecode(shared().readAsStringSync()) as Map;
    expect(json['format'], 'nourishly-share');
    expect(jsonEncode(json), contains('Poha'));
  });

  test('a new log rewrites it after the debounce, not before', () async {
    await share(true);
    await settle();
    expect(
      jsonEncode(jsonDecode(shared().readAsStringSync())),
      isNot(contains('Poha')),
    );
    await logPoha();
    await Future<void>.delayed(wait ~/ 2);
    expect(shared().readAsStringSync(), isNot(contains('Poha')));
    await settle();
    expect(shared().readAsStringSync(), contains('Poha'));
  });

  test('flush writes at once', () async {
    await share(true);
    await logPoha();
    await container.read(navmaasShareWriterProvider.notifier).flush();
    expect(shared().readAsStringSync(), contains('Poha'));
  });

  test('turned off, the file is gone, even with a write pending', () async {
    await share(true);
    await settle();
    expect(shared().existsSync(), isTrue);
    await logPoha();
    await share(false);
    await settle();
    expect(shared().existsSync(), isFalse);
    expect(File('${shared().path}.tmp').existsSync(), isFalse);
  });

  test('"Delete everything" removes the shared copy too', () async {
    await logPoha();
    await share(true);
    await settle();
    expect(shared().existsSync(), isTrue);
    await ProfileEraser(db).eraseEverything(ownerId);
    await settle();
    expect(shared().existsSync(), isFalse);
  });
}
