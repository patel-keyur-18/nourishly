import 'package:meta/meta.dart';

/// The fraction of a day's energy that comes from foods reporting a given
/// nutrient — "coverage" in the ubiquitous language (§22.1). Not to be
/// confused with how complete a day's *logging* is.
///
/// A validated `0..1` value object; the rules for computing it from a set
/// of log entries (§20.7-20.8) belong to the aggregation engine, built in
/// Phase 2 once the catalog and logging flows exist.
@immutable
class Coverage {
  factory Coverage(double fraction) {
    if (fraction < 0 || fraction > 1) {
      throw ArgumentError.value(fraction, 'fraction', 'must be within 0..1');
    }
    return Coverage._(fraction);
  }

  const Coverage._(this.fraction);

  static const Coverage none = Coverage._(0);
  static const Coverage complete = Coverage._(1);

  final double fraction;

  @override
  bool operator ==(Object other) =>
      other is Coverage && other.fraction == fraction;

  @override
  int get hashCode => fraction.hashCode;

  @override
  String toString() => 'Coverage(${(fraction * 100).toStringAsFixed(0)}%)';
}
