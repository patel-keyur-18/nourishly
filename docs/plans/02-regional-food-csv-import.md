# Plan — Importing the regional food CSVs

*Draft 0.3 · 2026-09-15 · **built** · branch `feature/regional-food-csv-import` · [Catalog spec](../catalog/README.md)*

13 CSVs in `app/assets/regional_food/`, **3,840 rows**, in exactly the five-column shape the catalog uses. Nothing has been imported. This is what I found and what I propose.

---

## 0. The rules, as decided

1. **The CSVs are the source of truth.** Where a dish exists in both the old markdown catalog and a CSV, **the CSV wins.**
2. **One row per food, globally.** Duplicates between CSVs collapse to a single entry.
3. **Nothing is dropped.** Every food in every CSV must end up in the app with a working ingredient list.
4. **More CSVs are coming.** Dropping a new file in must work without code changes.

Rule 1 supersedes my §2 concern about templated compositions — raised once, decided, and I have built to the decision. What I have done instead of arguing it again is make the **file precedence order** explicit (§0.2), so that where a dish appears in several CSVs the better-sourced file wins automatically. That is inside the rules, not around them.

Rule 2 supersedes catalog spec [§0.6](../catalog/README.md#06-conventions)'s "regional variants of the same dish are separate foods". `Coconut rice` was three rows; it is now one. The spec is updated to say so.

### 0.1 What "nothing is dropped" actually demands

A dish only enters the seed if **every one of its ingredients resolves**. So rule 3 is not a policy, it is 331 decisions: that many ingredient strings in the CSVs have no home in our catalog today. Each one is either mapped to a row we have, or given a row of its own. Any that is left unmapped silently takes its dishes down with it — which is why `--check` fails on a single unmapped ingredient, and why the acceptance test for this work is **zero unresolved rows**, not "most of them".

### 0.2 Precedence, when the same food appears twice

Deterministic and declared, highest first:

```
1. app/assets/regional_food/nourishly_indian_food_catalog.csv
2. app/assets/regional_food/nourishly_karnataka_tamilnadu_gujarat_food_catalog.csv
3. app/assets/regional_food/nourishly_karnataka_tamilnadu_gujarat_additions_only.csv
4. app/assets/regional_food/nourishly_common_international_food_catalog.csv
5. every other CSV, alphabetically
6. docs/catalog/*.md   (the old catalog — loses to any CSV)
```

The first four are ordered ahead because they are the files with **0–1% composition reuse**; the eleven state files run 17–24% (§2). Where `Gajar halwa` appears in both, the one that is actually carrot-based wins. A new CSV lands at rank 5 unless someone promotes it.

The markdown catalog stays, and still matters: **all 141 ingredient rows live there**, and the CSVs contain none. The CSVs are the dish layer; the markdown is the ingredient layer plus whatever dishes no CSV covers.

---

## 1. What is actually in there

| | |
|---|---|
| Rows | **3,840** across 13 files |
| Distinct dish names | **1,200** |
| Unique `(name, serving weight, composition)` | **1,383** |
| **Redundant rows** (identical name + weight + composition in another file) | **2,457 — 64%** |
| Already a name in our catalog | 103 |
| Matches only an `Also` synonym we already have | 35 |
| **Genuinely new dishes** | **1,062** |

The eleven per-state files are each ~341 rows because they share a pan-Indian core: `Tawa roti`, `Butter naan`, `Aloo paratha` and 470 others appear in up to 11 files at a time. So the import is **1,383 rows, not 3,840** — de-duplication is the first step, not an optimisation.

Every row parses as a recipe. Six rows reference another dish by name and would land in the existing manual-review pile. No row breaks the format.

---

## 2. The finding that decides everything else

**In the state files, different dishes share identical ingredient lists.** Not similar — identical.

```
Rice kheer    1 serving  100 g   Full-Fat Milk 160 g, Rice 25 g,   Sugar 20 g, Cardamom 1 g
Gajar halwa   1 serving  100 g   Full-Fat Milk 160 g, Carrot 25 g, Sugar 20 g, Cardamom 1 g
Doodhpak      1 serving  100 g   Full-Fat Milk 160 g, Rice 25 g,   Sugar 20 g, Cardamom 1 g
```

Gajar halwa is not 160 g of milk and 25 g of carrot. It is carrot-dominant, finished with ghee and khoya. Our own `nourishly_indian_food_catalog.csv` has it right — `Carrot 110 g, milk 30 g, sugar 12 g, ghee 5 g, khoya 8 g, nuts 4 g` — which is roughly **twice the energy** and a completely different fat figure.

This is not a rounding problem. It is the exact failure catalog spec [§0.2](../catalog/README.md#02-how-dishes-get-their-nutrients-recipes-not-tables) exists to prevent: the pipeline would faithfully compute nutrients from a wrong ingredient list and badge the result `derived`, **indistinguishable from a row that is right**. A wrong number that looks sourced is worse than a gap, because a gap is visible.

Measured across all files:

| | Compositions reused by a *different* dish | |
|---|---|---|
| **148** | distinct compositions | shared by **381 dishes** |

The worst: nine dishes share `Rice Flour 55 g, Coconut 20 g, Water 60 g, Salt 1 g` (puttu, kadubu, bhapa pitha, pidi kozhukattai, …). Six share one dal line — including `Gujarati dal`, which we already have with jaggery, tamarind and peanuts in it, as Gujarati dal actually is.

**Some of this reuse is legitimate.** Medu vada and garelu genuinely are the same dish under two names; puttu and kadubu are both steamed rice flour and coconut. The 148 need a human decision each, not a blanket verdict.

### The quality split maps cleanly onto files

| File | Rows | Compositions reused within the file |
|---|---|---|
| `indian_food_catalog` | 185 | **0%** |
| `common_international_food_catalog` | 156 | **0%** |
| `karnataka_tamilnadu_gujarat_additions_only` | 120 | **0%** |
| `karnataka_tamilnadu_gujarat_food_catalog` | 305 | 1% |
| The 11 per-state files | ~341 each | **17–24%** |

That is a clean line, and it is what the waves in §7 are built on.

---

## 3. Ingredient resolution — the real mechanical cost

490 distinct ingredient strings are used. Only **97** are already mapped.

| | |
|---|---|
| Match an existing catalog row or synonym exactly → one target line each | **51** |
| No catalog match at all | **342** |

The 342 divide into three kinds, and only the third is real work:

- **Spelling and naming variants of things we already have** — `yogurt` → curd, `cumin` → cumin seeds, `chili` → chilli, `whole wheat flour` → wheat flour atta, `refined wheat flour` → maida, `basmati rice` → rice white raw, `eggplant` → brinjal, `gram flour` → besan. Mechanical, but each is a decision someone records.
- **Genuinely new foods needing their own row** — soy sauce, spring onion, baking powder, cashews, cream, green beans, sattu, and perhaps 40–60 more.
- **Things that are not foods** — `spice mix` ×412, `spices` ×166, `pickle masala`. These need either a decision (treat as negligible mass, as our catalog already does for unquantified spices) or a blend row.

**One structural difference worth noting:** these CSVs quantify salt (×3,308), cumin, turmeric. Our catalog names spices without a quantity and treats them as negligible. Quantifying them is *better* data — sodium is a limit nutrient we track — but it means every spice needs a real FDC row rather than being skipped.

---

## 4. What this does to the app

Catalog **416 → 1,613 foods**, about 3.9×.

| | Now | After |
|---|---|---|
| Seed file | 2.6 MB | ~8–9 MB (bundled in the APK) |
| Nutrient value rows | 9,285 | ~31,000 |
| First-run import | — | needs measuring; it is a single batched transaction today |

Three things to check rather than assume, and all are testable before shipping:

1. **First-run import time.** The importer inserts everything in one transaction. At 3.4× it may cross into "the app looks frozen on first launch" territory and need a progress indicator.
2. **Search quality.** 1,400 foods behind a prefix match means typing "pa" returns a great many things. The cuisine ranking from WP5 helps, but this needs a real look.
3. **Browse.** Seventeen cuisine chips instead of seven, and `pan-indian` would hold several hundred foods — the browse list needs a course filter under it.

---

## 5. How the CSVs should enter the pipeline

**Teach `CatalogSourceParser` to read CSV directly.** Same five columns, so it is a small change, and it keeps one source of truth. Converting CSV → markdown would leave two copies of every row and guarantee they drift.

**Move the files out of `app/assets/`.** They are build-time input, not app assets. They are not declared in `pubspec.yaml` so they are not shipping in the APK today, but `app/assets/` is where someone will eventually add them to it. `docs/catalog/regional/` is where they belong, next to the markdown they are peers of.

Everything downstream then works unchanged: row keys, `--suggest`, `--check`, the lock, cuisine tags, the seed build.

**Cuisine tags** need eleven new file→cuisine entries (andhra, telangana, kerala, bihar, west-bengal, maharashtra, …), plus a decision on the two Karnataka/Tamil Nadu/Gujarat files, which overlap regions we already have as `02`, `03` and `04`.

---

## 6. The 103 dishes we already have

These need a rule, not a case-by-case fight. Three options:

| | Option | |
|---|---|---|
| **A** | Keep ours, drop the CSV row | ★ Ours were curated against this household's cooking and carry real serving weights |
| **B** | Keep both, distinguished by cuisine tag | Right where the dish genuinely differs by region — `Coconut rice` already works this way |
| **C** | Replace ours with the CSV row | ✗ Trades curated data for templated data |

**Recommendation: A by default, B where the composition genuinely differs** — and `--check` will list every collision, so this is a review, not a guess.

---

## 7. How it is built

| | | |
|---|---|---|
| **A** | `CsvSourceParser` + unified source discovery | Same five columns, so it reuses the composition parser, the keys, the lock and the tags unchanged. Files are found by glob, so a new CSV needs no code |
| **B** | Global dedup with declared precedence (§0.2) | One row per food, CSV over markdown, better file over worse |
| **C** | Cuisine registry for the CSV files | Filename → cuisine. `--check` **fails** on an unregistered file rather than defaulting, so a new CSV cannot slip in untagged |
| **D** | The 331 ingredients (§3) | Synonyms mapped; genuinely new foods get their own rows with FDC-searchable names |
| **E** | Yield band floor 0.5× → 0.4× | The 34 out-of-range rows are nearly all reduced-milk sweets at 0.49×, and milk really does boil down. Widening keeps them accurate rather than bending the rows |

### Where the CSVs live

They stay in `app/assets/regional_food/`, because that is where you put them and where you will add the next one. They are not declared in `pubspec.yaml`, so they are not shipped inside the APK — only the built seed is.

---

## 8. What you run afterwards

```
dart run tools/catalog_pipeline/bin/parse_catalog.dart --check      # offline
FDC_API_KEY=... dart run tools/catalog_pipeline/bin/fetch_catalog.dart
dart run tools/catalog_pipeline/bin/build_seed.dart
dart run tools/catalog_pipeline/bin/parse_catalog.dart --write-lock
```

This fetch is a big one — several hundred new ingredients, all uncached. Every run after it is small again.

---

## 9. Adding the next CSV

1. Drop it in `app/assets/regional_food/`.
2. Add one line to the cuisine registry — `--check` will tell you if you forget.
3. `--check`, which lists any ingredient nobody has mapped.
4. `--suggest` prints the mapping lines; paste the ones that are right.
5. `--check` again, then fetch and build.

No code changes at any step.

---

## 10. What was actually built

| | Planned | Built |
|---|---|---|
| Rows in the catalog | ~1,400 | **1,613** |
| Duplicate rows collapsed | — | 2,757 |
| Distinct CSV food names shipped | all | **1,200 of 1,200** |
| Ingredient strings with no target | 0 | **0** |
| New ingredient rows | "40–60 more" | 89, in `docs/catalog/08-regional-pantry.md` |
| Target lines written | 331 | 380, plus 10 repointed and 5 new water ingredients |
| Rows that cannot be computed | 0 from CSV | 0 from CSV (22 pre-existing markdown rows, unchanged) |

Four things the plan did not anticipate:

1. **A count is not a weight.** Three CSV rows open `Egg 2 pieces`, which the composition parser read as a reference to another dish, and two more buried a counted egg mid-list where it was silently dropped as a negligible-mass note. `piece` is now a unit, and what one piece weighs is read off the target row's own serving columns (`Egg, boiled | 1 large | 50 g`) — never a constant. A segment that states both, like Misal pav's `pav 1 piece 60 g`, keeps the grams it was given.

2. **An ingredient row must survive a dish of the same name.** `Coconut water` is a CSV dish whose only ingredient is coconut water, and plain precedence would have had it displace the row it needs. A direct-USDA row now wins over a recipe row of the same name, which also let `08`'s real Curry leaves row replace `01`'s `Negligible; include for completeness` placeholder.

3. **Ten existing targets pointed at markdown rows a CSV superseded.** Repointed by hand rather than redirected automatically: what an ingredient means stays something a person wrote down (catalog spec §0.3b). `--check` now names the superseding row, so the next one is a one-line fix.

4. **Some ingredients are not in FoodData Central at all** — kokum, ker, sangri, ajwain, kachampuli, parwal, horse gram, kachri, wood apple. None got an invented row. Each is settled in `ingredient_targets.dart` against the closest row the catalog already measures, with the reason on its line.
