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
