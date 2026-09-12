/// A catalog row's stable identity: `<file number>:<slug of its name>`,
/// e.g. `01:besan-gram-flour`, `03:coconut-rice`, `04:coconut-rice`.
///
/// Why an identity at all. Everything in this pipeline used to key on the
/// prose name, and prose names are not identities: two files legitimately
/// carry a "Coconut rice" (catalog spec §0.6 — regional variants of a dish
/// are separate foods), while `build_seed` mints a fresh random id per row
/// on every run, so a rebuild rewrites the whole seed and the diff shows
/// nothing. A key fixes both: it survives rebuilds, it distinguishes rows
/// a name cannot, and it is what `ingredient_targets.dart` points at so
/// that adding a row can no longer change what an existing ingredient
/// means.
///
/// Why this shape, and why it needed no edit to any table. The file number
/// makes uniqueness a *local* property: a key is unique across the catalog
/// as long as no single file repeats a name, which no file does today and
/// which `--check` enforces from here on. Names may still repeat across
/// files, because they should — the app tells those apart by cuisine, not
/// by renaming the dish.
library;

/// The leading number of a catalog filename: `02-gujarat.md` -> `02`.
///
/// Falls back to the whole basename (minus `.md`, slugged) for a file that
/// does not start with digits, so an unnumbered file still produces a
/// usable key rather than a silent collision on an empty prefix.
String catalogFilePrefix(String sourceFile) {
  final basename = sourceFile.split('/').last.replaceAll(RegExp(r'\.md$'), '');
  final digits = RegExp(r'^(\d+)').firstMatch(basename);
  return digits != null ? digits.group(1)! : slugify(basename);
}

/// Lowercases and reduces to `a-z0-9-`: `Besan, gram flour` ->
/// `besan-gram-flour`, `Chana, whole (kabuli)` -> `chana-whole-kabuli`.
String slugify(String raw) {
  final slug = raw
      .toLowerCase()
      .replaceAll(RegExp(r"[’'`]"), '')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return slug;
}

/// The key for one row. [sourceFile] is the basename as
/// [CatalogSourceEntry.sourceFile] carries it.
String catalogRowKey(String sourceFile, String foodName) =>
    '${catalogFilePrefix(sourceFile)}:${slugify(foodName)}';
