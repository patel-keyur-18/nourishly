import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nourishly_data/nourishly_data.dart';

/// The single [NourishlyDatabase] instance for the app's lifetime.
///
/// Nothing about `food_catalog` is exposed beyond this and
/// [foodSearchDaoProvider] yet — Phase 2's catalog+search slice only needs
/// search. Other features requiring the database watch this same provider
/// rather than opening a second connection.
final nourishlyDatabaseProvider = Provider<NourishlyDatabase>((ref) {
  final db = NourishlyDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Full-text food search (§27.4), consumed by `food_logging`'s search
/// screen. `food_catalog` owns this because reports and templates will
/// need catalog access too (§14.4) — it isn't `food_logging`-only.
final foodSearchDaoProvider = Provider<FoodSearchDao>((ref) {
  return FoodSearchDao(ref.watch(nourishlyDatabaseProvider));
});

/// Loads the bundled catalog seed and imports it on first run (§16.4).
/// `main.dart` waits on this before showing the real app — see
/// [CatalogImporter]'s doc comment for why it's safe to call on every
/// launch (a no-op once the version is already present).
final catalogReadyProvider = FutureProvider<void>((ref) async {
  final db = ref.watch(nourishlyDatabaseProvider);

  final raw = await rootBundle.loadString('assets/catalog/seed_v1.json');
  final seed = jsonDecode(raw) as Map<String, dynamic>;
  await CatalogImporter(db).importIfNeeded(seed);

  // The RDA table is a separate import on purpose — see [RdaImporter].
  // Without it, target derivation produces energy and macros but no
  // micronutrient targets, which is a working app with a thinner report
  // rather than a broken one.
  final rda = await rootBundle.loadString(
    'assets/reference/rda_icmr_nin_2020.json',
  );
  await RdaImporter(db).importFromString(rda);
});

/// The version of the food catalog on the device, for Settings' footer and
/// for the export manifest (§30.6) — an archive without it cannot be
/// re-interpreted later, and a screen that claims "catalog 2026.09" should
/// be reading the number rather than printing one.
final catalogVersionProvider = FutureProvider<int?>((ref) async {
  await ref.watch(catalogReadyProvider.future);
  final db = ref.watch(nourishlyDatabaseProvider);
  final row = await db
      .customSelect('SELECT MAX(version) AS v FROM catalog_versions')
      .getSingle();
  return row.data['v'] as int?;
});
