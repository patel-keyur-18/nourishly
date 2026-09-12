import 'dart:convert';

import 'database.dart';

/// Reading `FoodItems.cuisineTags`, which the catalog pipeline writes as a
/// JSON list of prefixed tags: `["cuisine:gujarati", "course:gravy"]`.
///
/// Either may be absent — a food whose heading spans too many courses to
/// label gets a cuisine and no course, and a component-only row gets
/// neither — so callers must handle both being missing.
///
/// **The prefixes are why this file holds no list of cuisines.** Reading
/// bare tags would mean matching against a vocabulary kept in step with
/// the pipeline's, and the first time the two drifted, a cuisine the
/// pipeline had just learned would show up here as a course. A tag that
/// says what it is cannot be misread.
extension FoodItemCuisineTags on FoodItem {
  /// The tags, or empty when the column is absent, malformed, or written
  /// by a seed built before tags existed.
  ///
  /// Never throws. This is display metadata on a food someone is trying to
  /// log; a stray character in it is not a reason to fail a search.
  List<String> get tags {
    try {
      final decoded = jsonDecode(cuisineTags);
      if (decoded is! List) return const [];
      return [
        for (final tag in decoded)
          if (tag is String && tag.isNotEmpty) tag,
      ];
    } on FormatException {
      return const [];
    }
  }

  /// Where this dish is from — `gujarati`, `italian` — or null.
  String? get cuisine => _tagged(cuisineTagPrefix);

  /// What kind of dish it is — `gravy`, `bread`, `ingredient` — or null.
  String? get course => _tagged(courseTagPrefix);

  String? _tagged(String prefix) {
    for (final tag in tags) {
      if (tag.startsWith(prefix) && tag.length > prefix.length) {
        return tag.substring(prefix.length);
      }
    }
    return null;
  }
}

/// Tag prefixes, matching `cuisine_tags.dart` in `tools/catalog_pipeline`.
/// An unprefixed tag — anything a seed written before this convention
/// carries — is simply neither, which is the right answer for a value
/// nobody can interpret.
const cuisineTagPrefix = 'cuisine:';
const courseTagPrefix = 'course:';
