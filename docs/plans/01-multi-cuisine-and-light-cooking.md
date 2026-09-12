# Plan — Multi-cuisine catalog expansion, and "our kitchen" light-cooking versions

*Draft 0.1 · 2026-09-12 · awaiting approval · [Catalog spec](../catalog/README.md) · [Food & nutrition](../architecture/05-food-and-nutrition.md) · [Scope](../architecture/00-scope.md)*

Two requests, planned together because they meet in the same place — `recipe_components`:

1. **Widen the catalog** beyond Gujarat / Tamil Nadu / Karnataka — Punjabi, Kathiyawadi, Italian, Chinese, and the everyday dishes that don't belong to any of the four current files (tawa pulav, veg biryani, paneer biryani).
2. **Record how this household actually cooks** — the same dish with 1 tbsp of oil where the standard recipe says 2.

Nothing here is implemented. This document is the plan to approve or change.

---

## 1. Where the code actually stands

Established by reading the repo, not assumed:

| Fact | Where |
|---|---|
| 383 foods in the bundled seed — 134 USDA ingredients, **249 recipes** | `app/assets/catalog/seed_v1.json` |
| Every regional dish is already a recipe with a component list | `recipe_components`, 711 rows |
| The pipeline discovers catalog files by globbing, not a hardcoded list | `fetch_catalog.dart:246` |
| `FoodItems.cuisineTags` exists in the schema and **nothing writes it or reads it** | `catalog_tables.dart:20` |
| A user recipe is computed by the same maths as a catalog recipe | `RecipeDao.saveRecipe` |
| A log entry snapshots its nutrients, so edits never rewrite history | `LogEntryNutrients`, §20.5 |

That last pair is the good news for request 2: **the machinery for "her version of the dish" is already built and shipped.** What is missing is a way to start from a catalog dish instead of an empty form.

---

## 2. Four things that break before a single new food is written

These are not hypotheticals; they are properties of the current pipeline that only bite once the catalog grows or ships a second time.

### P1 — A second seed version duplicates the whole catalog on an existing phone

`build_seed.dart` mints a fresh `uuid.v7()` for every entry on every run, and `CatalogImporter.importIfNeeded` is version-gated: a device that already has v1 sees v2, inserts all ~700 rows, and **keeps the 383 old ones**. Search then shows "Gujarati dal" twice, with different ids.

**Fix:** derive each food id deterministically (uuid v5 over `sourceFile + section + foodName`), then make the import an upsert-by-id plus a tombstone pass for rows the new seed dropped. Diffs between seed versions become readable, which they currently are not.

### P2 — Every rebuild needs ~600 live FDC lookups and an API key

There is no response cache. Rebuilding the seed today means re-fetching everything from `api.nal.usda.gov`, which makes the build slow, non-reproducible, and impossible in any environment without network (including CI and most of my sessions).

**Fix:** an on-disk FDC response cache. Worth **committing** it — it is public-domain USDA data, which §0.7 of the scope doc already says is safe to redistribute, and it makes the seed reproducible byte-for-byte from the repo alone.

### P3 — New cuisines collide with existing names, and the collision is silent

`CatalogIndex` drops any name that two rows claim, rather than guessing. That is the right rule, but "puri", "pulav", "biryani", "paratha", "noodles" are about to become multi-claimant names, and each collision quietly demotes an ingredient to a plain FDC search — the exact failure §0.3b was written to stop.

**Fix:** make `parse_catalog` fail the build on a newly ambiguous name, an unresolved ingredient, or a yield factor outside 0.5×–15×, and wire it into CI. Cheap, and it turns a silent wrong number into a red check.

### P4 — At ~700 rows, search-only browsing stops working

383 foods is small enough that you already know what's in there. 700 across seven cuisines is not. `cuisineTags` is the column for this and it has never been populated.

**Fix:** the pipeline emits tags from the source file and section; the importer writes them; the log screen gets cuisine filter chips.

---

## 3. Part A — the catalog expansion

### 3.1 File layout

One file per cuisine, same five-column table format, so the existing parser needs no change:

| File | Contents | Rows |
|---|---|---|
| `05-punjabi.md` | Dal makhani, rajma, chole, the paneer gravies, sarson da saag, naan/kulcha/bhature, lassi, tandoori | ~75 |
| `06-kathiyawadi.md` | Lasaniya bataka, khichu, masala rotlo, sev tameta (Kathiyawadi cut), dungri methi, gud-ghee, chaas | ~45 |
| `07-rice-and-biryani.md` | **Tawa pulav, veg biryani, paneer biryani**, jeera rice, ghee rice, veg pulav, tehri | ~25 |
| `08-indo-chinese.md` | Hakka/schezwan noodles, fried rice, manchurian, chilli paneer, momos, the soups, honey chilli potato | ~40 |
| `09-italian.md` | Pasta in four sauces, baked pasta, pizza, risotto, minestrone, garlic bread, tiramisu | ~40 |
| `10-street-and-maharashtrian.md` | Pav bhaji, misal, vada pav, dabeli, sabudana khichdi, thalipeeth, puran poli | ~40 |
| `11-pantry-non-indian.md` | The **ingredients** the four above need: pasta, olive oil, mozzarella, parmesan, passata, soy sauce, noodles, tofu, sesame oil, vinegar, cornflour, pizza base, sweet corn, baby corn, mushroom | ~45 |
| | **Added** | **~310** |
| | **Catalog total** | **~690** |

`11-pantry-non-indian.md` **ships first and alone**. Every dish in the four new cuisine files resolves its ingredients through it; without it, `fetch_catalog` reports failures for the whole wave.

### 3.2 Conventions that need adding to the catalog spec

The current spec (§0.3) only defines Indian household measures. Four additions:

- **New serving units** — plate (pasta, noodles, fried rice), slice (pizza, 1/8 of a 10-inch), bowl (soup, 200 ml), piece (momo, spring roll, vada pav).
- **Indo-Chinese is labelled as such, honestly.** Gobi manchurian is not a Chinese dish and the file should say so in its header. A row for a genuinely Chinese preparation (steamed rice, stir-fried tofu) goes in as its own row, not as a "more authentic" version of an Indian one.
- **Deep-fried rows state absorbed oil separately from cooking oil.** This matters for Part B: absorbed oil in a puri or a manchurian ball is physics, not a dial the cook turns. The light-cooking feature must not let it be halved.
- **Every dish row keeps declaring its fat explicitly** (already the convention, §0.6) — Part B has nothing to edit otherwise.

### 3.3 Curation order — and the one rule that governs it

Catalog spec §0.5 and risk R-1 both say the same thing: **curate against what the household actually eats, not against the list's length.** ~310 rows written speculatively is exactly the failure mode that document warns about.

So the waves are sized by what gets cooked, not by what is on the list:

| Wave | What | Rows | Gate |
|---|---|---|---|
| **1** | `11-pantry` + `07-rice-and-biryani` + the ~30 Punjabi dishes actually cooked | ~90 | You name the dishes |
| **2** | Kathiyawadi + the rest of Punjabi | ~90 | After wave 1 is in daily use |
| **3** | Indo-Chinese + Italian | ~80 | ditto |
| **4** | Street/Maharashtrian + whatever search failures have queued up | ~50 | Let the app tell you |

Wave 1 is the only one worth committing to now. Waves 2–4 should be re-scoped from a month of real logging — the search-failure queue (§31.6) writes them better than either of us can.

---

## 4. Part B — "our kitchen" light-cooking versions

### 4.1 The design question

A dish cooked with 1 tbsp of oil instead of 2 is ~110 kcal and ~12 g of fat lighter per batch. Where does that fact live?

| | Option | Verdict |
|---|---|---|
| **A** | A second catalog row per dish — "Bataka nu shaak, light oil" | ✗ Doubles the catalog, puts a choice in front of you at every log, and the "light" figure is still a guess about somebody else's kitchen, not a measurement of hers |
| **B** | A global preference — "our kitchen uses 60% of the catalog's oil" | ✗ One number silently rewrites every dish in the app, including deep-fried ones where absorbed oil isn't a choice — and it breaks the rule the whole design rests on, that a dish's nutrients equal the sum of its listed components |
| **C** | **Fork the catalog recipe into one you own** | ★ **Recommended** |
| **D** | A per-entry modifier at log time (Standard / Ours / Extra) | ~ Good ergonomics, but it needs a new per-entry concept and re-poses B's problem unless it resolves to a C fork underneath. Build it as sugar over C, later |

### 4.2 The recommended mechanism

**One new action on a catalog dish: "Make this our version".**

It opens the existing recipe builder pre-filled with that dish's `recipe_components` — every ingredient, every gram. She changes `Groundnut oil 8 g` to `4 g` and saves. From there it is an ordinary user recipe: `RecipeDao.saveRecipe` recomputes from ingredients, applies the yield factor, gates on component coverage, and writes a `FoodItems` row you own.

Nothing about the honesty guarantees changes, because nothing about the computation changes. The number is still the sum of what went in the pot — it is just her pot.

Three pieces on top of that:

- **A "lighter oil" preset.** One tap halves every fat ingredient in the pre-filled form (and leaves *absorbed* oil alone, per §3.2). She still sees and confirms the numbers before saving — the preset is a starting point, not an assertion.
- **Search prefers your version.** Both rows are in the index; the one you own sorts first with a *Yours* badge. The standard row stays reachable, because sometimes you eat the dish somebody else cooked.
- **A household default.** "When I fork a recipe, halve the fat" — so dish twenty takes one tap instead of three.

### 4.3 The feature that makes it worth doing

Because both rows exist and both are computed from components, the app can say something no nutrition app can:

> **Your paneer butter masala** — 118 kcal and 11 g of fat less per katori than the standard recipe.
> **This week:** 84 g of oil not eaten, across 11 meals. ≈ 740 kcal.

That is a join over two `FoodItems` rows and the log — no new data, no new maths, and it is the reason the cooking is worth recording rather than merely tolerated. It belongs in the weekly report next to the existing insights.

### 4.4 The guardrail

If a fork drops a *fried* dish's fat below ~30% of the catalog value, warn: deep-fry absorption is not a dial, and a puri made with less oil in the pan absorbs about the same. Warn, do not block — §19.8's rule is offer, never impose.

---

## 5. Work packages

Each one is independently shippable and leaves the app better than it found it.

| # | Package | Why here | Size |
|---|---|---|---|
| **WP0** | Stable ids · upsert import · FDC cache · `parse_catalog` CI gate | **Blocks everything.** §2's four problems | ~1 day |
| **WP1** | Catalog spec §0.3/§0.6 additions (§3.2) | New units before rows use them | ~2 h |
| **WP2** | `11-pantry-non-indian.md` + `07-rice-and-biryani.md` | Tawa pulav, veg biryani, paneer biryani — named, and the pantry every later wave needs | ~4 h |
| **WP3** | `cuisineTags` populated + browse chips on the log screen | Needed at ~500 rows, not 700 | ~half day |
| **WP4** | Punjabi wave 1 (~30 dishes you name) | First real cuisine, on a proven path | ~4 h |
| **WP5** | Light cooking: fork action + preset + *Yours* ranking | Part B | ~1 day |
| **WP6** | Oil-saved insight in the weekly report | §4.3 — the payoff | ~half day |
| **WP7** | Waves 2–4, re-scoped from real search failures | Deliberately unscheduled | — |

**Order:** WP0 → WP1 → WP2 → WP4 → WP3 → WP5 → WP6 → WP7.
WP5 can move ahead of WP2 if the light-cooking feature matters more to you than the new dishes — it only depends on WP0.

---

## 6. What I need from you

| # | Question | My recommendation |
|---|---|---|
| 1 | **Name 30–40 dishes** you two actually cook across Punjabi / Kathiyawadi / Italian / Chinese | These become Tier 1 and wave 1; the rest waits for real search failures |
| 2 | Chinese — Indo-Chinese, or authentic? | Indo-Chinese, labelled honestly, plus 3–4 genuinely Chinese rows |
| 3 | Kathiyawadi — own file, or a section in `02-gujarat.md`? | Own file. §0.6 says regional variants of a dish are separate foods, and Kathiyawadi genuinely runs hotter on oil and garlic |
| 4 | Non-veg in the new cuisines (butter chicken, chilli chicken)? | Include; `DietClassifier` already handles it from components |
| 5 | Commit the FDC response cache to the repo? | Yes — public-domain, and it makes the build reproducible offline |
| 6 | **Does she measure the oil, or estimate it?** | If she measures even roughly, the forked numbers stop being estimates and the whole feature gets sharply better. A tablespoon and one week is all it takes (§0.3) |
| 7 | Light version replaces the standard in search, or sits beside it? | Beside, ranked first. You still eat other people's cooking |

---

## 7. Explicitly not in this plan

- **Nutrient retention factors** (vitamin C loss on boiling). Still a §9.2 should-have, still not attempted — yield is the effect that matters and it is handled.
- **Per-entry cooking modifiers** (option D). Revisit once forking is in daily use and the shape of the need is known.
- **Re-curating the existing 383 rows.** They work. Leave them.
- **Any implementation.** Nothing in this document has been built.
