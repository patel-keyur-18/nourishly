import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nourishly_data/nourishly_data.dart';
import 'package:nourishly_domain/nourishly_domain.dart';

import '../features/food_catalog/data/food_catalog_providers.dart';
import '../features/profile/data/profile_providers.dart';

/// The one [ClockPort] instance for the app — day-boundary logic (§14.6)
/// reads "now" through this rather than calling `DateTime.now()` directly,
/// so it stays swappable for tests.
final clockProvider = Provider<ClockPort>((ref) => const SystemClock());

/// The `log_date` a moment belongs to (§22.5), honouring the profile's
/// rollover time (FR-U-08).
///
/// With a 04:00 rollover, 1am on Saturday still logs to Friday — a late
/// dinner belongs to the day you ate it, not to the calendar. Falls back
/// to midnight while preferences are still loading, which is also the
/// default.
final dayRolloverMinutesProvider = Provider<int>((ref) {
  return ref.watch(preferencesProvider).value?.dayRolloverTime ?? 0;
});

final todayProvider = Provider<DateTime>((ref) {
  return logDateFor(
    ref.watch(clockProvider).now(),
    rolloverMinutes: ref.watch(dayRolloverMinutesProvider),
  );
});

/// The device's local profile (§0.4), created on first use — see
/// [ensureDefaultOwner]'s doc comment for why this stands in for
/// Phase 3's profile creation UI.
final defaultOwnerProvider = FutureProvider<String>((ref) {
  return ensureDefaultOwner(ref.watch(nourishlyDatabaseProvider));
});

final foodLoggingDaoProvider = Provider<FoodLoggingDao>((ref) {
  return FoodLoggingDao(ref.watch(nourishlyDatabaseProvider));
});

final waterLogDaoProvider = Provider<WaterLogDao>((ref) {
  return WaterLogDao(ref.watch(nourishlyDatabaseProvider));
});

final customFoodDaoProvider = Provider<CustomFoodDao>((ref) {
  return CustomFoodDao(ref.watch(nourishlyDatabaseProvider));
});

/// The four meal slots, seeded by the catalog import (§16.4) — the picker
/// on the portion-selection screen reads this rather than hardcoding them.
final mealSlotsProvider = FutureProvider<List<MealSlot>>((ref) async {
  final db = ref.watch(nourishlyDatabaseProvider);
  return (db.select(
    db.mealSlots,
  )..orderBy([(m) => OrderingTerm.asc(m.sortOrder)])).get();
});

/// Today's logged foods (§27.2) — a Drift reactive stream wrapped in a
/// Riverpod [StreamProvider] per §14.5, not a raw `StreamBuilder` calling
/// the DAO fresh on every build (that pattern resubscribes on every
/// rebuild). Deliberately not `.autoDispose`, matching
/// [nourishlyDatabaseProvider]'s own lifetime: an autoDispose provider
/// wrapping a drift `.watch()` stream can get disposed and immediately
/// recreated while its upstream `defaultOwnerProvider` future is still
/// resolving, and drift's stream-cleanup schedules a timer on disposal
/// that `flutter_test`'s strict pending-timer check then flags as leaked.
final todayFoodLogProvider = StreamProvider<List<LoggedFood>>((ref) async* {
  final ownerId = await ref.watch(defaultOwnerProvider.future);
  final dao = ref.watch(foodLoggingDaoProvider);
  yield* dao.watchToday(ownerId: ownerId, logDate: ref.watch(todayProvider));
});

/// Today's water entries, for the Water screen's list + inline undo.
final todayWaterLogProvider = StreamProvider<List<WaterLogEntry>>((ref) async* {
  final ownerId = await ref.watch(defaultOwnerProvider.future);
  final dao = ref.watch(waterLogDaoProvider);
  yield* dao.watchToday(ownerId: ownerId, logDate: ref.watch(todayProvider));
});

/// Today's water total (I-9: always a live `SUM`, never a stored counter).
final todayWaterTotalProvider = Provider<double>((ref) {
  final entries = ref.watch(todayWaterLogProvider).value ?? const [];
  return entries.fold(0.0, (sum, e) => sum + e.volumeMl);
});
