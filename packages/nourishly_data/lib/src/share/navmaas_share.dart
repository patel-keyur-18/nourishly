import 'package:drift/drift.dart';

import '../dao/daily_summary_dao.dart';
import '../dao/log_status.dart';
import '../database.dart';

/// The day totals Navmaas shows (docs/navmaas-share.md), in their
/// canonical units: kcal, g, mg, mg, µg, g.
const navmaasShareNutrients = [
  'energy',
  'protein',
  'iron',
  'calcium',
  'folate',
  'fibre',
];

/// How many log dates the file covers, today's included.
const navmaasShareDays = 90;

/// Builds the Navmaas share file for [ownerId] (ADR-012): each day's meals
/// and six day totals for the last [navmaasShareDays] log dates up to
/// [today]. Only what she ate: no targets, scores, insights, profile,
/// water or plans ever go in.
Future<Map<String, Object?>> buildNavmaasShare({
  required NourishlyDatabase db,
  required String ownerId,
  required DateTime today,
  required DateTime now,
}) async {
  final last = DateTime(today.year, today.month, today.day);
  final first = DateTime(
    last.year,
    last.month,
    last.day - navmaasShareDays + 1,
  );
  final e = db.foodLogEntries;
  final rows =
      await (db.select(e).join([
              innerJoin(db.foodItems, db.foodItems.id.equalsExp(e.foodId)),
              innerJoin(db.mealSlots, db.mealSlots.id.equalsExp(e.mealSlotId)),
              leftOuterJoin(
                db.servingSizes,
                db.servingSizes.id.equalsExp(e.servingSizeId),
              ),
            ])
            ..where(
              e.ownerId.equals(ownerId) &
                  isActual(e) &
                  e.logDate.isBetweenValues(first, last),
            )
            ..orderBy([
              OrderingTerm.desc(e.logDate),
              OrderingTerm.asc(db.mealSlots.sortOrder),
              OrderingTerm.asc(e.loggedAt),
              // Ids are UUID v7, so this keeps logging order on a tie.
              OrderingTerm.asc(e.id),
            ]))
          .get();

  final precision = {
    for (final n in await db.select(db.nutrients).get())
      n.id: n.displayPrecision,
  };
  final summaries = DailySummaryDao(db);
  final days = <Map<String, Object?>>[];
  DateTime? date;
  late List<Map<String, Object?>> meals;
  for (final row in rows) {
    final entry = row.readTable(e);
    if (entry.logDate != date) {
      date = entry.logDate;
      meals = [];
      days.add({
        'date': _date(entry.logDate),
        'meals': meals,
        ...await _totals(summaries, ownerId, entry.logDate, now, precision),
      });
    }
    final slot = row.readTable(db.mealSlots).displayName;
    if (meals.isEmpty || meals.last['slot'] != slot) {
      meals.add({'slot': slot, 'items': <Map<String, Object?>>[]});
    }
    (meals.last['items']! as List).add({
      'name': row.readTable(db.foodItems).canonicalName,
      'amount': _amount(
        entry.quantity,
        row.readTableOrNull(db.servingSizes)?.label,
        entry.gramsConsumed,
      ),
    });
  }
  return {
    'format': 'nourishly-share',
    'version': 1,
    'generatedAt': _stamp(now),
    'days': days,
  };
}

/// The six totals, the same numbers the dashboard shows. A nutrient with
/// no data that day is left out; one some foods lacked is `partial`.
Future<Map<String, Object?>> _totals(
  DailySummaryDao summaries,
  String ownerId,
  DateTime date,
  DateTime now,
  Map<String, int> precision,
) async {
  final day = await summaries.summaryFor(
    ownerId: ownerId,
    logDate: date,
    now: now,
  );
  final totals = <String, num>{};
  final partial = <String>[];
  for (final id in navmaasShareNutrients) {
    final n = day.nutrient(id);
    if (n == null || n.coverage <= 0) continue;
    totals[id] = _round(n.amount, precision[id] ?? 1);
    if (n.coverage < 1) partial.add(id);
  }
  return {'totals': totals, 'partial': partial};
}

num _round(double v, int digits) =>
    digits <= 0 ? v.round() : double.parse(v.toStringAsFixed(digits));

/// `1 katori · 150 g`, `2 × 1 piece · 60 g`, or `88 g` for an exact weight.
String _amount(double quantity, String? label, double grams) {
  final g = '${grams.round()} g';
  if (label == null) return g;
  final q = quantity == quantity.roundToDouble()
      ? '${quantity.round()}'
      : double.parse(quantity.toStringAsFixed(2)).toString();
  return quantity == 1 ? '$label · $g' : '$q × $label · $g';
}

String _two(int n) => n.toString().padLeft(2, '0');

String _date(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

/// Local time with its UTC offset, e.g. `2026-10-10T09:40:00.000+05:30`.
String _stamp(DateTime now) {
  final o = now.timeZoneOffset;
  final sign = o.isNegative ? '-' : '+';
  final m = o.inMinutes.abs();
  final local = now.toIso8601String().replaceAll('Z', '');
  return '$local$sign${_two(m ~/ 60)}:${_two(m % 60)}';
}
