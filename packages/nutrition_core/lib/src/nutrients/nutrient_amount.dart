import '../units/quantity.dart';

/// A nutrient's amount, which is either [KnownAmount] or [UnknownAmount].
///
/// This is the type-level expression of AP-4: **unknown is not zero**. A
/// food that does not report a nutrient must never be represented as
/// having zero of it — the absence has to be visible everywhere the value
/// is used, not just at the database row (§22.4). Aggregation, scoring,
/// and display all switch on this sealed type instead of testing a
/// nullable double against zero.
sealed class NutrientAmount {
  const NutrientAmount();
}

/// The nutrient was measured or estimated, with [quantity] in the
/// nutrient's canonical unit.
final class KnownAmount extends NutrientAmount {
  const KnownAmount(this.quantity);

  final Quantity quantity;

  @override
  bool operator ==(Object other) =>
      other is KnownAmount && other.quantity == quantity;

  @override
  int get hashCode => quantity.hashCode;

  @override
  String toString() => 'KnownAmount($quantity)';
}

/// No source reported this nutrient. Renders as an em dash, never `0`
/// (tokens.rules.unknownIsNotZero), and is excluded — not zero-filled —
/// from any sum or average over it.
final class UnknownAmount extends NutrientAmount {
  const UnknownAmount();

  @override
  bool operator ==(Object other) => other is UnknownAmount;

  @override
  int get hashCode => 0;

  @override
  String toString() => 'UnknownAmount';
}
