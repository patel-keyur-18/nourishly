import 'package:meta/meta.dart';

/// One row of the `Nutrient` reference table (§22.5) — the registry that
/// makes the nutrient model extensible (§22.4, AP-6, TO-3).
///
/// **This specific set of 24 nutrients — 5 macros, saturated fat, sugar,
/// and 17 micronutrients — is the standard USDA nutrient panel, not a
/// judgement call from the scoring/weighting work the architecture
/// explicitly defers to the nutrition review packet (§0.6).** Nothing here
/// asserts an RDA, a target, or a curve weight; it only names what gets
/// stored. `fdcNames` are the exact strings FoodData Central uses so the
/// normalizer can match by name rather than a numeric nutrient id this
/// pipeline can't verify without a live response to check against.
@immutable
class NutrientDef {
  const NutrientDef({
    required this.id,
    required this.groupId,
    required this.displayName,
    required this.canonicalUnit,
    required this.fdcNames,
    required this.fdcUnit,
  });

  /// Stable slug — the `Nutrient.id` primary key (§22.5).
  final String id;
  final String groupId;
  final String displayName;

  /// `kcal` | `g` | `mg` | `ug`.
  final String canonicalUnit;

  /// The FDC nutrient `name` strings that map to this nutrient, **in
  /// preference order**. More than one where USDA's own naming has varied
  /// across dataTypes/API versions (e.g. `Sugars, total including NLEA`
  /// vs. the older `Sugars, total`).
  ///
  /// Order matters where the names are not synonyms but different
  /// computations of the same quantity — see `energy`. The normalizer
  /// takes the first name the food carries, so a food with several is
  /// resolved by this list rather than by the order its nutrients
  /// happened to arrive in.
  final List<String> fdcNames;

  /// FDC's `unitName` for this nutrient (e.g. `KCAL`, `G`, `MG`, `UG`),
  /// used to disambiguate when a name alone isn't unique (Energy is
  /// reported in both `KCAL` and `KJ`).
  final String fdcUnit;
}

const nutrientGroups = [
  ('macronutrients', 'Macronutrients'),
  ('vitamins', 'Vitamins'),
  ('minerals', 'Minerals'),
  ('other', 'Other'),
];

/// The 24-nutrient registry: 5 macros + saturated fat + sugar + 17
/// micronutrients (§0.3 of the personal-use scope document).
const nutrientRegistry = <NutrientDef>[
  // --- Macronutrients (5) ---
  // Three names, and the order is the whole point. SR Legacy and the
  // older Foundation records report a plain `Energy`; newer Foundation
  // records drop it and report the two Atwater computations instead,
  // which is why 32 catalog foods shipped at 0 kcal while their macros
  // were right.
  //
  // Specific before General, because that is what the rest of the
  // catalog already uses: SR Legacy's `Energy` is itself computed with
  // Atwater specific factors, and measured against the committed FDC
  // cache 102 of 189 plain-`Energy` foods sit more than 2% below a flat
  // 4/9/4 — up to 29% below for leafy vegetables. Preferring General
  // would leave the same foods reading 7-17% higher than their
  // neighbours purely by which record USDA happened to publish.
  NutrientDef(
    id: 'energy',
    groupId: 'macronutrients',
    displayName: 'Energy',
    canonicalUnit: 'kcal',
    fdcNames: [
      'Energy',
      'Energy (Atwater Specific Factors)',
      'Energy (Atwater General Factors)',
    ],
    fdcUnit: 'KCAL',
  ),
  NutrientDef(
    id: 'protein',
    groupId: 'macronutrients',
    displayName: 'Protein',
    canonicalUnit: 'g',
    fdcNames: ['Protein'],
    fdcUnit: 'G',
  ),
  NutrientDef(
    id: 'carbs',
    groupId: 'macronutrients',
    displayName: 'Carbohydrate',
    canonicalUnit: 'g',
    fdcNames: ['Carbohydrate, by difference'],
    fdcUnit: 'G',
  ),
  NutrientDef(
    id: 'fat',
    groupId: 'macronutrients',
    displayName: 'Total fat',
    canonicalUnit: 'g',
    fdcNames: ['Total lipid (fat)'],
    fdcUnit: 'G',
  ),
  NutrientDef(
    id: 'fibre',
    groupId: 'macronutrients',
    displayName: 'Dietary fibre',
    canonicalUnit: 'g',
    fdcNames: ['Fiber, total dietary'],
    fdcUnit: 'G',
  ),
  // --- Plus (2) ---
  NutrientDef(
    id: 'saturated_fat',
    groupId: 'macronutrients',
    displayName: 'Saturated fat',
    canonicalUnit: 'g',
    fdcNames: ['Fatty acids, total saturated'],
    fdcUnit: 'G',
  ),
  NutrientDef(
    id: 'sugar',
    groupId: 'macronutrients',
    displayName: 'Sugars',
    canonicalUnit: 'g',
    fdcNames: ['Sugars, total including NLEA', 'Sugars, total', 'Total Sugars'],
    fdcUnit: 'G',
  ),
  // --- Micronutrients (17) ---
  NutrientDef(
    id: 'sodium',
    groupId: 'minerals',
    displayName: 'Sodium',
    canonicalUnit: 'mg',
    fdcNames: ['Sodium, Na'],
    fdcUnit: 'MG',
  ),
  NutrientDef(
    id: 'potassium',
    groupId: 'minerals',
    displayName: 'Potassium',
    canonicalUnit: 'mg',
    fdcNames: ['Potassium, K'],
    fdcUnit: 'MG',
  ),
  NutrientDef(
    id: 'calcium',
    groupId: 'minerals',
    displayName: 'Calcium',
    canonicalUnit: 'mg',
    fdcNames: ['Calcium, Ca'],
    fdcUnit: 'MG',
  ),
  NutrientDef(
    id: 'iron',
    groupId: 'minerals',
    displayName: 'Iron',
    canonicalUnit: 'mg',
    fdcNames: ['Iron, Fe'],
    fdcUnit: 'MG',
  ),
  NutrientDef(
    id: 'magnesium',
    groupId: 'minerals',
    displayName: 'Magnesium',
    canonicalUnit: 'mg',
    fdcNames: ['Magnesium, Mg'],
    fdcUnit: 'MG',
  ),
  NutrientDef(
    id: 'zinc',
    groupId: 'minerals',
    displayName: 'Zinc',
    canonicalUnit: 'mg',
    fdcNames: ['Zinc, Zn'],
    fdcUnit: 'MG',
  ),
  NutrientDef(
    id: 'phosphorus',
    groupId: 'minerals',
    displayName: 'Phosphorus',
    canonicalUnit: 'mg',
    fdcNames: ['Phosphorus, P'],
    fdcUnit: 'MG',
  ),
  NutrientDef(
    id: 'vitamin_a',
    groupId: 'vitamins',
    displayName: 'Vitamin A',
    canonicalUnit: 'ug',
    fdcNames: ['Vitamin A, RAE'],
    fdcUnit: 'UG',
  ),
  NutrientDef(
    id: 'vitamin_c',
    groupId: 'vitamins',
    displayName: 'Vitamin C',
    canonicalUnit: 'mg',
    fdcNames: ['Vitamin C, total ascorbic acid'],
    fdcUnit: 'MG',
  ),
  NutrientDef(
    id: 'vitamin_d',
    groupId: 'vitamins',
    displayName: 'Vitamin D',
    canonicalUnit: 'ug',
    fdcNames: ['Vitamin D (D2 + D3)'],
    fdcUnit: 'UG',
  ),
  NutrientDef(
    id: 'vitamin_e',
    groupId: 'vitamins',
    displayName: 'Vitamin E',
    canonicalUnit: 'mg',
    fdcNames: ['Vitamin E (alpha-tocopherol)'],
    fdcUnit: 'MG',
  ),
  NutrientDef(
    id: 'vitamin_b6',
    groupId: 'vitamins',
    displayName: 'Vitamin B6',
    canonicalUnit: 'mg',
    fdcNames: ['Vitamin B-6'],
    fdcUnit: 'MG',
  ),
  NutrientDef(
    id: 'vitamin_b12',
    groupId: 'vitamins',
    displayName: 'Vitamin B12',
    canonicalUnit: 'ug',
    fdcNames: ['Vitamin B-12'],
    fdcUnit: 'UG',
  ),
  NutrientDef(
    id: 'folate',
    groupId: 'vitamins',
    displayName: 'Folate',
    canonicalUnit: 'ug',
    fdcNames: ['Folate, total'],
    fdcUnit: 'UG',
  ),
  NutrientDef(
    id: 'thiamin',
    groupId: 'vitamins',
    displayName: 'Thiamin (B1)',
    canonicalUnit: 'mg',
    fdcNames: ['Thiamin'],
    fdcUnit: 'MG',
  ),
  NutrientDef(
    id: 'riboflavin',
    groupId: 'vitamins',
    displayName: 'Riboflavin (B2)',
    canonicalUnit: 'mg',
    fdcNames: ['Riboflavin'],
    fdcUnit: 'MG',
  ),
  NutrientDef(
    id: 'niacin',
    groupId: 'vitamins',
    displayName: 'Niacin (B3)',
    canonicalUnit: 'mg',
    fdcNames: ['Niacin'],
    fdcUnit: 'MG',
  ),
];
