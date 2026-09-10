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

  /// The FDC nutrient `name` strings that map to this nutrient. More than
  /// one where USDA's own naming has varied across dataTypes/API versions
  /// (e.g. `Sugars, total including NLEA` vs. the older `Sugars, total`).
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
  NutrientDef(
    id: 'energy',
    groupId: 'macronutrients',
    displayName: 'Energy',
    canonicalUnit: 'kcal',
    fdcNames: ['Energy'],
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
    fdcNames: ['Sugars, total including NLEA', 'Sugars, total'],
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
