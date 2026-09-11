import 'dart:convert';

import 'package:drift/drift.dart';

import '../database.dart';

/// Reads and writes the one [UserPreferences] row per profile (§22.5).
///
/// Defaults are created on first read rather than at profile creation, so a
/// profile that predates a new preference gets it without a migration.
class PreferencesDao {
  PreferencesDao(this._db);

  final NourishlyDatabase _db;

  /// §22.5's defaults: metric, Monday week start, midnight rollover, the
  /// score shown, energy shown, and the quick-add amounts the water screen
  /// already offers.
  static const defaultQuickAddMl = [250.0, 500.0];
  static const defaultFocusNutrients = <String>['fibre', 'iron', 'sodium'];

  Future<UserPreference> forOwner(String ownerId) async {
    final rows = await (_db.select(
      _db.userPreferences,
    )..where((p) => p.ownerId.equals(ownerId))).get();
    if (rows.isNotEmpty) return rows.first;

    await _db
        .into(_db.userPreferences)
        .insert(
          UserPreferencesCompanion.insert(
            ownerId: ownerId,
            unitSystem: 'metric',
            volumeUnit: 'ml',
            massUnit: 'kg',
            heightUnit: 'cm',
            energyUnit: 'kcal',
            weekStartDay: DateTime.monday,
            dayRolloverTime: 0,
            focusNutrientIds: jsonEncode(defaultFocusNutrients),
            quickAddWaterAmounts: jsonEncode(defaultQuickAddMl),
          ),
        );
    return (_db.select(
      _db.userPreferences,
    )..where((p) => p.ownerId.equals(ownerId))).getSingle();
  }

  Stream<UserPreference?> watch(String ownerId) {
    return (_db.select(
      _db.userPreferences,
    )..where((p) => p.ownerId.equals(ownerId))).watchSingleOrNull();
  }

  Future<void> update(
    String ownerId, {
    bool? showScore,
    bool? hideEnergy,
    int? weekStartDay,
    int? dayRolloverTime,
    String? unitSystem,
    List<String>? focusNutrientIds,
  }) async {
    await forOwner(ownerId);
    await (_db.update(
      _db.userPreferences,
    )..where((p) => p.ownerId.equals(ownerId))).write(
      UserPreferencesCompanion(
        showScore: showScore == null ? const Value.absent() : Value(showScore),
        hideEnergy: hideEnergy == null
            ? const Value.absent()
            : Value(hideEnergy),
        weekStartDay: weekStartDay == null
            ? const Value.absent()
            : Value(weekStartDay),
        dayRolloverTime: dayRolloverTime == null
            ? const Value.absent()
            : Value(dayRolloverTime),
        unitSystem: unitSystem == null
            ? const Value.absent()
            : Value(unitSystem),
        // §27.12 caps this at three: the dashboard has room for three rows
        // between the water card and the meals list, and a "focus" list of
        // ten focuses on nothing.
        focusNutrientIds: focusNutrientIds == null
            ? const Value.absent()
            : Value(jsonEncode(focusNutrientIds.take(3).toList())),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> renameProfile(String ownerId, String displayName) {
    return (_db.update(_db.users)..where((u) => u.id.equals(ownerId))).write(
      UsersCompanion(
        displayName: Value(displayName),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}

/// Decodes [UserPreferences.focusNutrientIds], which is stored as JSON
/// because the schema keys nutrients by slug and a list column would need
/// a join table for three strings.
List<String> focusNutrientsOf(UserPreference preferences) {
  final decoded = jsonDecode(preferences.focusNutrientIds);
  return [for (final id in decoded as List) id as String];
}

/// The date a moment belongs to, given the profile's rollover time
/// (FR-U-08).
///
/// A rollover of 04:00 means 1am on Saturday still logs to Friday — which
/// is what a person eating a late dinner means by "today", and the reason
/// the setting exists at all.
DateTime logDateFor(DateTime moment, {required int rolloverMinutes}) {
  final shifted = moment.subtract(Duration(minutes: rolloverMinutes));
  return DateTime(shifted.year, shifted.month, shifted.day);
}
