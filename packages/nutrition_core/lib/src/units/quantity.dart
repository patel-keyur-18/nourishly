import 'package:meta/meta.dart';

import 'unit.dart';

/// An immutable amount in a specific [Unit].
///
/// This is the shared value object for anything with a magnitude and a
/// unit — a nutrient amount, a serving weight, a target. It deliberately
/// carries no conversion behaviour yet (§20.6 defines the conversion
/// rules); that arrives with the calculation pipeline in a later phase.
@immutable
class Quantity {
  const Quantity(this.amount, this.unit);

  final double amount;
  final Unit unit;

  @override
  bool operator ==(Object other) =>
      other is Quantity && other.amount == amount && other.unit == unit;

  @override
  int get hashCode => Object.hash(amount, unit);

  @override
  String toString() => '$amount${unit.symbol}';
}
