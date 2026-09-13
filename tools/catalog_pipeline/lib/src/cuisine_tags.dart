/// The tags a catalog row carries into `FoodItems.cuisineTags`.
///
/// Two facts the source files already hold and the pipeline used to throw
/// away — the column has existed in the schema since Phase 1 and nothing
/// has ever written it.
///
/// * **Cuisine**, from the file the row is in. A file that is not one
///   cuisine (pasta and overnight oats in the same file) overrides it per
///   section.
/// * **Course**, from the `## N.` heading the row sits under — except for
///   a direct-USDA row, which is an ingredient and is tagged as one
///   whatever section it was filed in. "Dals and pulses" is a shelf, not
///   a course.
///
/// **Tags say where a dish is from, never what is in it.** No tag may
/// imply a nutrient: "Italian ⇒ high fat" is exactly the invented number
/// catalog spec §0.2 exists to prevent. They are for telling two dishes
/// apart in a search result, for browsing, and for ranking.
///
/// The first job is the one that fixes something already broken: the
/// shipped catalog has twelve display names carried by two or three rows
/// each — `Coconut rice` is a Tamil dish *and* a Kannadiga dish *and* a
/// pan-Indian one — and search shows them as identical, unchoosable
/// lines. A cuisine tag is what makes them tell apart, which is why they
/// do not need renaming.
library;

/// File number -> cuisine, for files that are a single cuisine.
const _cuisineByFile = <String, String>{
  '01': 'pan-indian',
  '02': 'gujarati',
  '03': 'tamil',
  '04': 'kannadiga',
  '05': 'north-indian',
  '06': 'pan-indian',
};

/// `<file>|<lowercased section>` -> cuisine, where a file spans several.
///
/// Only `07-pasta-and-modern.md` needs this: its pasta is Italian, its
/// vermicelli is Indian, and overnight oats is from nowhere at all.
const _cuisineBySection = <String, String>{
  '07|pantry': 'modern',
  '07|pasta': 'italian',
  '07|vermicelli': 'pan-indian',
  '07|modern breakfast': 'modern',
};

/// Section-heading keyword -> course, first match wins. Ordered, because
/// "Rice dishes and biryani" and "Dal, kadhi and everyday liquids" both
/// contain words that appear in other entries.
const _courseKeywords = <(String, String)>[
  ('biryani', 'rice'),
  ('pulav', 'rice'),
  ('rice', 'rice'),
  ('tiffin', 'tiffin'),
  ('breakfast', 'tiffin'),
  ('dal', 'gravy'),
  ('kadhi', 'gravy'),
  ('kuzhambu', 'gravy'),
  ('sambar', 'gravy'),
  ('rasam', 'gravy'),
  ('saaru', 'gravy'),
  ('huli', 'gravy'),
  ('gravy', 'gravy'),
  ('chana', 'gravy'),
  ('bread', 'bread'),
  ('rotla', 'bread'),
  ('rotti', 'bread'),
  ('paratha', 'bread'),
  ('shaak', 'sabzi'),
  ('sabzi', 'sabzi'),
  ('subji', 'sabzi'),
  ('poriyal', 'sabzi'),
  ('palya', 'sabzi'),
  ('vegetable', 'sabzi'),
  ('sweet', 'sweet'),
  ('mithai', 'sweet'),
  ('payasam', 'sweet'),
  ('farsan', 'snack'),
  ('snack', 'snack'),
  ('street', 'snack'),
  ('chutney', 'accompaniment'),
  ('podi', 'accompaniment'),
  ('accompaniment', 'accompaniment'),
  ('condiment', 'accompaniment'),
  ('beverage', 'beverage'),
  ('pasta', 'pasta'),
  ('vermicelli', 'tiffin'),
  ('egg', 'egg'),
  ('coastal', 'non-veg'),
  ('pantry', 'ingredient'),
  ('dairy', 'dairy'),
  ('staples', 'staple'),
];

/// Headings that genuinely span several courses, where the honest answer
/// is no course tag at all rather than a made-up one.
///
/// `01-common.md` §9 holds khichdi, upma, poha, four rice dishes, two
/// sabzis and five chutneys under one heading. There is no course that
/// covers those, and picking the first keyword that matched would label a
/// coconut chutney a rice dish. A dish here is searchable and taggable by
/// cuisine like any other; it simply does not appear under a course
/// filter, which is better than appearing under the wrong one.
const _sectionsWithoutOneCourse = <String>{
  'everyday preparations shared across all three states',
};

/// The cuisine for one row, or null when neither the file nor its section
/// is mapped — a new file nobody has classified yet, which is a gap to
/// notice rather than a default to invent.
String? cuisineFor({required String sourceFile, required String section}) {
  final prefix = sourceFile.split('-').first;
  final override = _cuisineBySection['$prefix|${_normalize(section)}'];
  if (override != null) return override;
  return _cuisineByFile[prefix];
}

/// The course for one row, or null when its heading covers too many to
/// pick one honestly ([_sectionsWithoutOneCourse]).
///
/// A direct-USDA row is an `ingredient` whatever heading it sits under:
/// in `01-common.md` the headings are shelves — "Dals and pulses",
/// "Vegetables" — not courses, and tagging raw toor dal as a gravy would
/// be false.
String? courseFor({required String section, required bool isIngredient}) {
  if (isIngredient) return 'ingredient';
  final normalized = _normalize(section);
  if (_sectionsWithoutOneCourse.contains(normalized)) return null;
  for (final (keyword, course) in _courseKeywords) {
    if (normalized.contains(keyword)) return course;
  }
  return null;
}

/// Both tags for one row, **prefixed**, with absent ones dropped:
/// `['cuisine:gujarati', 'course:gravy']`.
///
/// The prefix is what makes a tag readable on its own. Written bare, the
/// list's meaning would depend on position and on a vocabulary of known
/// cuisines kept in step between this file and whatever reads it — and
/// the first time the two drifted, a cuisine this pipeline had learned
/// would be read as a course by the app. Prefixes delete that failure
/// instead of documenting it.
List<String> cuisineTagsFor({
  required String sourceFile,
  required String section,
  required bool isIngredient,
}) => [
  if (cuisineFor(sourceFile: sourceFile, section: section) case final c?)
    '$cuisineTagPrefix$c',
  if (courseFor(section: section, isIngredient: isIngredient) case final c?)
    '$courseTagPrefix$c',
];

/// Prefixes for [cuisineTagsFor]. `nourishly_data` reads the same two.
const cuisineTagPrefix = 'cuisine:';
const courseTagPrefix = 'course:';

String _normalize(String section) =>
    section.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
