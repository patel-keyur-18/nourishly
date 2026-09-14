# Plan — Importing the regional food CSVs

*Draft 0.1 · 2026-09-14 · awaiting approval · branch `feature/regional-food-csv-import` · [Catalog spec](../catalog/README.md)*

13 CSVs in `app/assets/regional_food/`, **3,840 rows**, in exactly the five-column shape the catalog uses. Nothing has been imported. This is what I found and what I propose.

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

Catalog **416 → ~1,400 foods**, about 3.4×.

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

## 7. Proposed waves

Sized by data quality, because §2 says that is the only division that matters.

| Wave | What | Rows | Why |
|---|---|---|---|
| **0** | Pipeline: CSV reader, move files, cuisine tags for the new regions, dedup tooling | — | Nothing imports until this exists |
| **A** | The four clean files — `indian`, `common_international`, and the two `karnataka_tamilnadu_gujarat` | **~450 unique** | 0–1% composition reuse. These are usable as they stand |
| **B** | The 148 shared compositions: confirm or correct, one at a time | 381 dishes touched | The gate for wave C |
| **C** | The eleven state files, minus what wave B rejected | ~800 | Only after B |
| **D** | The 342 ingredient mappings and any new ingredient rows | — | Runs alongside A–C; `--suggest` generates the candidates |

**Wave A alone roughly doubles the catalog** — 416 → ~870 — with data I would defend. That is a good place to stop and use the app for a while before deciding whether wave C is worth the review effort.

---

## 8. What I need from you

| # | Question | My recommendation |
|---|---|---|
| 1 | **Where did the state files come from?** If they were generated, that explains §2 and tells us how much to trust the rest | Decides whether wave C is a review or a rewrite |
| 2 | **Wave A only, or push on to C?** | Wave A now, live with ~870 foods for a few weeks, then decide |
| 3 | **The 103 existing dishes** — rule A, B, or case-by-case? | A by default, B where composition genuinely differs |
| 4 | **`spice mix` ×412 and `spices` ×166** — negligible mass, or a blend row? | Negligible, matching what the catalog already does |
| 5 | **34 rows fall outside the 0.5×–15× yield band**, nearly all reduced-milk sweets at 0.49× | These are physically right — milk really does boil down. I would widen the floor to 0.4× rather than bend the rows |

---

## 9. What I have not done

Nothing has been imported, converted, moved or changed. The branch holds this document only.
