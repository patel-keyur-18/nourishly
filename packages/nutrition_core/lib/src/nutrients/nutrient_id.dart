/// A stable nutrient slug, e.g. `protein`, `vitamin_b12` (§22.5 `Nutrient.id`).
///
/// A typedef rather than a wrapper class: nutrient ids are read-only
/// registry keys, not a value type with its own behaviour, and the
/// registry itself (content, not code — AP-6) is a Phase 2 concern.
typedef NutrientId = String;
