# Nourishly Food Catalog Specification

*Revision 0.3 · 2026-09-15 · [Architecture index](../architecture/README.md) · [Personal-Use Scope](../architecture/00-scope.md)*

The curated food list for the household catalog, covering **Gujarat, Tamil Nadu and Karnataka** plus the pan-Indian staples all three share, and the everyday North Indian, rice and non-regional cooking this household actually does.

| File | Contents | Items |
|---|---|---|
| [`01-common.md`](./01-common.md) | Pan-Indian staples: grains, dals, dairy, vegetables, fruit, oils, beverages, non-veg, snacks | ~190 |
| [`02-gujarat.md`](./02-gujarat.md) | Gujarati dishes, farsan, sweets | ~77 |
| [`03-tamil-nadu.md`](./03-tamil-nadu.md) | Tamil dishes, tiffin, kuzhambu, sweets | ~79 |
| [`04-karnataka.md`](./04-karnataka.md) | Kannadiga dishes, North Karnataka and coastal | ~68 |
| [`05-everyday-north.md`](./05-everyday-north.md) | Plain dals, chana and bean sabzis, stuffed parathas, egg bhurji, pav bhaji | ~13 |
| [`06-rice-and-biryani.md`](./06-rice-and-biryani.md) | Paneer, egg and mushroom biryani; pudina and tawa pulav | ~5 |
| [`07-pasta-and-modern.md`](./07-pasta-and-modern.md) | Pasta and its sauces, millet pasta and vermicelli, overnight oats | ~9 |
| [`08-regional-pantry.md`](./08-regional-pantry.md) | Ingredient rows the regional CSVs need: spices, western pantry, fish and meat, cheeses | 89 |
| `app/assets/regional_food/*.csv` | **The regional dish catalogs.** Thirteen files, one per state plus pan-Indian and international — see [§0.9](#09-the-regional-csv-catalogs) | 1,062 |
| [`catalog.lock.json`](./catalog.lock.json) | Generated. What every row's ingredients resolve to — see [§0.7](#07-row-keys-and-why-adding-a-row-is-now-safe) | 1,613 |
| | **Total** | **1,613** |

---

## 0.1 What this document is, and is not

**It is** the catalog specification: which foods exist, what they are called (including regional variants for search), what a normal serving is, and — for the dishes eaten most often — the ingredient composition the pipeline should compute nutrients from.

**It is not a nutrient table, deliberately.** There are no calorie or nutrient values in these lists, and that is a design decision, not an omission.

> **Why no nutrient numbers here.** This whole architecture rests on the claim that Nourishly's numbers are honest — coverage gating (§21.5), quality tiers (§19.11), unknown-never-zero (AP-4). Numbers written from recall rather than measurement would be exactly the quietly-wrong data the design exists to prevent, and they would enter the system wearing the same badge as sourced values. So nutrients come from one place only: **the pipeline, computing them from sourced ingredient data.**

## 0.2 How dishes get their nutrients: recipes, not tables

Every regional dish is defined as a **recipe over ingredients**, and the pipeline computes its nutrients from ingredient composition.

```
Dish (e.g. Dal dhokli, 1 katori)
  └── toor dal, raw           30 g   → USDA
  └── wheat flour              25 g   → USDA
  └── groundnut oil             5 g   → USDA
  └── jaggery                   4 g   → USDA
  └── tomato                   20 g   → USDA
  └── spices, negligible mass
        ↓  sum, apply yield factor for cooking water
   per-portion nutrients, quality_tier = derived
```

This has four advantages over copying dish composition tables, and they compound:

1. **Every value traces to US Government public-domain data** (USDA FoodData Central). No licence, no attribution requirement, no restriction on redistribution — which is what makes the public repository safe (§0.7 of the scope document).
2. **Nothing is invented.** A dish's energy is the sum of what went into it, not a remembered figure.
3. **It matches how your household actually cooks.** If your dal dhokli uses more jaggery than the reference, change one number and every past and future entry recomputes correctly.
4. **The data model already supports it** — `FoodItem.kind = 'recipe'` plus `RecipeComponent` (§19.10, §22.5). No new machinery.

**Where the ingredient breakdown is given below**, the dish is ready for the pipeline. **Where it is not** (the less-frequently-eaten items), the entry names its composition basis instead, and the breakdown gets filled in when you first log it. Curate against what the household actually eats, not against the list's length (R-1).

## 0.3 Serving weights: starting estimates, to be calibrated once

Every gram weight in these lists is a **reasonable starting estimate, not a measurement.** Household portions vary by 20–30% between kitchens (§19.6, A-4), and yours will differ from these.

> **The single highest-value hour you can spend on data quality:** put a kitchen scale on the counter for one week and weigh your own katori of dal, your own rotli, your own idli, your own dosa. Then correct these numbers once. Everything downstream — every daily total, every score, every trend — inherits that accuracy. No public nutrition app can do this; you can, because you cook the food.

Standard measures used throughout:

| Measure | Convention used here | Notes |
|---|---|---|
| Katori (small bowl) | 150 ml capacity | Weight varies by contents: thin dal ≈ 150 g, thick sabzi ≈ 120 g |
| Vaatki (Gujarati) | 150 ml | Same as katori |
| Glass | 200 ml | |
| Cup (tea/coffee) | 120 ml | Indian tea cup, not a 240 ml US cup |
| Tumbler (S. Indian coffee) | 100 ml | Coffee is served small and strong |
| Tbsp / tsp | 15 ml / 5 ml | Volume→mass via per-food density |
| Piece | Per food | Roti, idli, vada, dosa each have their own weight |
| Plate | Per food | Pasta, noodles, fried rice — a main-course portion, not a katori |
| Bowl | 250 ml | Larger than a katori: overnight oats, soup, a cereal bowl |

## 0.3a Cooking yield factor (resolved 2026-09-10)

§0.2's "sum, apply yield factor for cooking water" step needed two decisions before the pipeline could resolve recipe entries at all — both settled from a household kitchen-scale check rather than a per-dish measurement, same spirit as §0.3's serving weights:

- **Tumbler-to-gram.** Where a recipe measures a raw grain or dal by tumbler (the S. Indian raw-measure cup used for things like idli batter — not the 100 ml coffee-serving tumbler above), 1 tumbler ≈ 160–180 g depending on the grain. The pipeline uses **170 g** (the midpoint) as a single starting estimate rather than weighing each grain separately.
- **Cooking method, which drives evaporation.** Dal (and other pulses) is always pressure-cooked — sealed, so evaporation is negligible. Rice and everything else is simmered or boiled in an **open, uncovered pot** — including rice itself, which is not treated as a special case.

This gives two yield factors (raw dry ingredient weight → cooked weight), applied broadly across rice-based and other grain dishes, not just dal:

| Cooking method | Applies to | Yield factor |
|---|---|---|
| Pressure cooker (sealed) | Dal and other pulses | 2.5× |
| Open pot (uncovered simmer) | Rice and everything else | 2.75× |

Both are starting estimates, not measurements — per §0.3, correct a specific dish's own factor once it's actually weighed. Implemented in `tools/catalog_pipeline/lib/src/recipe_yield.dart`; `fetch_catalog.dart` now resolves recipe entries end to end (each ingredient looked up, summed, yield-adjusted) instead of skipping them.

### 0.3a-i Superseded: each row states its own yield factor (revised)

The two constants above are now the **fallback**, not the primary source. A dish's yield factor is:

```
yield factor = the row's g column  ÷  the ingredient grams in its Composition column
```

That is not a new estimate — it is what §0.4 already says those two columns mean: **g** is "estimated grams for that serving", **Composition** is the "ingredient breakdown **per serving**". Their ratio is what the pot actually did for that specific dish, and it is available for every recipe row in this catalog.

Measured across all 249 recipe rows, the constants were right for about an eighth of them:

| Row's own factor | Rows | What the constants did |
|---|---|---|
| 0.8–1.2× | 143 | applied 2.75×, deflating per-100g values ~2.75× |
| 1.2–1.8× | 67 | applied 2.5–2.75× |
| 1.8–2.6× | 31 | roughly right |
| >2.6× | 8 | applied 2.5×, concentrating rasam and thin dal 2–4× |

The reason so many sit near 1.0× is that most rows are not "raw dry ingredients that will absorb water" at all — a 40 g piece of mohanthal is made from 42 g of besan, ghee and sugar, and a 100 g plate of bhel from 100 g of components. Applying an open-pot factor to those claimed the mohanthal weighed 115 g and cut its energy density by nearly two thirds. The rows at the other end (pepper rasam, 12 g of solids in a 150 g katori) are the reverse case: the water is real, and deliberately not listed as an ingredient because water has no nutrients.

The constants still apply where a caller has no serving weight, or where a row's two weight columns imply a factor outside **0.5×–15×** — a range wide enough to admit every real row (the catalog spans 0.81× to 12.5×) and narrow enough to catch a typo. Such a row is reported as `yieldWarning` in the draft seed; fix the weight column rather than the pipeline.

§0.3's advice is unchanged and now matters more: weighing your own katori corrects the yield factor directly, because the serving weight *is* the yield factor.

## 0.3b Where a recipe ingredient's nutrients come from (resolved 2026-09-10)

An ingredient string in a Composition cell resolves to a catalog row through **one** mechanism: a line in `ingredientTargets` (`tools/catalog_pipeline/lib/src/ingredient_targets.dart`) naming that row's key. If there is no line, the pipeline reports the dish and the ingredient and leaves the dish out — it does not guess.

> **Revised 2026-09-12.** This used to try four things in order — the row's own name, an `Also` synonym, the leading segment before a `,` or `/`, and only then the curated map. Those first three are inference, and inference made an existing dish's meaning depend on which *other* rows existed: adding a row named `Besan` silently moved twenty dishes onto a different food, no error anywhere. They now live in `parse_catalog.dart --suggest`, which proposes lines for a human to paste, and resolve nothing at build time. See §0.7.

There used to be one more step: search FoodData Central for the raw ingredient string. It is gone. FDC has never heard of `sev`, `khoya` or `idli batter`, but its search returns whatever shares a word — `batter` matched *APPLEBEE'S, fish, hand battered*, `rice` matched *Rice noodles, cooked*, `milk` matched *Crackers, milk*. Every one of those matched, so the pipeline reported **zero failures** while computing 55 dishes — idli, every dosa, curd rice, every rice dish — from the wrong food, under a `verified` badge. That is the failure §0.2 exists to prevent, and it is worse than a gap because it is invisible.

Everything else is settled in `ingredientTargets` with the closest sensible row, because this is a household tracker: `oil/ghee` means oil, a 3 g tempering is mostly oil, a coconut filling is mostly coconut, and a sambar podi is a spice blend. Being a little off on 5 g of powder changes nothing anyone would do about it. The rule that stays is the narrow one — a name maps to a row **someone chose**, never to whatever a text search returned.

All recipe rows resolve every ingredient, and a test asserts it. When a new row does not, run `--suggest` and paste the line it prints, saying which row and why; give the ingredient a row of its own only if it is a genuinely distinct food (that is where `Pav`, `Broken wheat`, `Hung curd` and `Colocasia leaves` came from).

## 0.3c The `USDA` hint, and why a bare `USDA` is not enough

A row whose composition is `USDA <descriptor>` is looked up in FoodData
Central. The descriptor is not decoration: **it is the query**, and
without it the pipeline searches the row's own name, which is an Indian
name for a food USDA catalogues under an American one.

Measured against the shipped catalog, that put 33 ingredient rows on the
wrong food. Every one of them matched *something*, so nothing failed and
all of them shipped marked `verified`:

| Row | What it was sourced from | Recipes affected |
|---|---|---|
| Salt | `Butter, salted` | 999 |
| Groundnut oil | `Oil, peanut` — 90 nutrients, no proximates | 787 |
| Garam masala | `SMART SOUP, Indian Bean Masala` | 238 |
| Green chilli | `Asparagus, green, raw` | 171 |
| Rice, white, raw | `Potatoes, au gratin, home-prepared` | 129 |
| Potato | `Bread, potato` | 79 |

So: **write the descriptor the way FoodData Central names the food.**
`USDA potatoes flesh and skin raw`, not `USDA`. A trailing ` — note`
after a spaced em-dash is a curator's note and is not part of the query.

Two mechanical guards back this up, in `fdc_match.dart`:

- **A candidate that names a different food is refused.** One identifying
  word must be shared between the result and the row's name, synonyms or
  hint — plurals allowed, preparation words and colours ignored. The
  search then moves on to the next query and the next data type.
- **A candidate carrying no energy, protein, fat or carbohydrate is
  refused.** Some FDC Foundation records are specialised analyses — a
  fatty-acid profile, a mineral panel — with dozens of nutrients and no
  proximates. `Oil, peanut` is one.

Refusing a candidate moves the search on to the next one FDC returned,
then to the next query in the ladder, then to the unrestricted data
types. The cache keeps every candidate's id and description for that
reason — descriptions arrive free with the search, and the one details
call is spent on whichever candidate is accepted.

Both guards are a floor, not a judge. They will not catch a wrong record
that happens to contain the food's name (`Bread, potato` for potato), and
they are not meant to: the hint is what gets the right record, and the
guards stop the obviously wrong one from being summed in silence.

**A record that names the right food in the wrong form is refused too.**
`Fish oil, sardine` really is sardine and `Drumstick leaves` really is
drumstick, so the first guard passes both; a second one reads the words
that describe a *form* — oil, leaves, salted, sticks, toasted, frozen,
dehydrated, puffs — and refuses a record carrying one the row does not.

This began as a warning and became a gate once the evidence came in: the
right record is usually sitting directly behind the wrong one. `sweet
potato raw unprepared` returns frozen puffs, then the real thing;
`bread white commercially prepared` returns the toasted loaf, then the
plain one. Refusing the first simply takes the second.

**A row that means the form says so in its hint**, and is not stopped:
ghee names butter *oil*, breadcrumbs name dry grated *bread*. That makes
acknowledging a form a one-word edit, and it keeps the refusal list worth
reading — a list that always has eight known-fine lines in it is a list
nobody reads.

The same words are ignored when deciding whether two names agree, unless
the row itself used one. `Asparagus, frozen, unprepared` once answered a
search for sweet potato on the word "unprepared" alone, and `Drumstick
leaves` answered both curry leaves and mint leaves on "leaves"; but Pav's
hint says `bread white commercially prepared`, so for that row "bread" is
the identity and not noise.

**A food FoodData Central does not measure gets the nearest food that it
does, named on the row.** Jaggery's only FDC record carries zero
nutrients, so the row reads `USDA sugars brown — no FDC record for gur
carries nutrients at all`. That is a sourced number with its reasoning
attached, which §0.2 allows; an invented one it does not. A row where
nothing survives resolves to nothing and is reported as a curation gap,
per §0.2 — a named missing food beats an invented one. `fetch_catalog`
prints every refused candidate.

## 0.4 Column meanings

| Column | Meaning |
|---|---|
| **Food** | Canonical name as it should appear in search |
| **Also** | Alternate names, regional spellings, transliterations. **These matter** — they feed `FoodAltName` and the FTS index, and they are why "panir", "paneer" and "पनीर" all find the same food (§22.5) |
| **Serving** | The default serving offered when logging |
| **g** | Estimated grams for that serving (§0.3) |
| **Composition** | Ingredient breakdown per serving, or the sourcing basis |

Two conventions inside a **Composition** cell, both of which the parser now honours:

- **A spaced em-dash ends the ingredient list.** Everything after ` — ` is the curator's note about the dish, not food: `…chilli, sesame — usually eaten with 5 g oil or ghee added` is four ingredients and a remark, not five ingredients.
- **A parenthetical restates, it does not add.** `Idli batter 90 g (rice 45 g + urad 16 g raw basis)` is 90 g of ingredients, not 151 g.


## 0.5 Priority tiers

Curate in this order. Tier 1 alone makes the app usable.

| Tier | What | Count | When |
|---|---|---|---|
| **1 — Daily** | Rice, rotli, dals, curd, milk, tea, coffee, everyday sabzis, idli, dosa, sambar, rasam, khichdi | ~90 | Phase 2, before first use |
| **2 — Weekly** | Tiffin items, common farsan, regional dishes eaten a few times a month | ~140 | Phase 2 continuing |
| **3 — Occasional** | Festival sweets, elaborate dishes, seasonal items | ~135 | After the app is in daily use — let search failures drive the queue (§31.6) |

**Tier 3 is not a launch requirement.** Custom food creation covers anything missing, and it is one tap from a failed search (UX-6).

## 0.6 Conventions

- **Cooked and raw are different foods**, never a conversion (§19.5). "Toor dal, raw" and "Dal, cooked" are separate entries.
- **Regional variants of the same dish are separate foods** where composition genuinely differs. Sambar and huli are close but not identical; Mysore masala dosa has a spread that plain masala dosa does not.
- **A dish's stated weight is as served**, including absorbed water and cooking fat.
- **Fat matters more than people expect.** A paratha, a benne dose, or a puri carries 5–15 g of added fat that its plain counterpart does not. These are separate foods for that reason alone.
- **Sweetness matters in Gujarati cooking** — jaggery and sugar appear in dal, kadhi and shaak where other cuisines use none. The recipes below reflect this.
- **Absorbed oil is named separately from cooking oil.** A row that deep-fries writes `absorbed oil 6 g`, never folding it into the pan oil. The two are different things: pan oil is a choice the cook makes, absorbed oil is what the food takes up, and a puri fried in half the oil absorbs about the same. Keeping them apart is what lets a household record cooking lighter (`docs/plans/01-multi-cuisine-and-light-cooking.md` §7) without claiming a fried dish got lighter too.
- **One row per food, across every source.** A food is its name, normalized. Whichever source names it first — in the precedence order of §0.9 — is the row that ships; the rest are collapsed and reported by `--check --superseded`. This supersedes the older rule below.

> **Revised 2026-09-15.** This section used to read *"regional variants of the same dish are separate foods"* and *"names are unique within a file; they may repeat across files"* — so `Coconut rice` could be a Tamil row and a Kannadiga row at once, told apart by cuisine tag. The regional CSVs describe 1,525 foods between them and repeat 2,757 rows doing it, and a search for "coconut rice" that returns six indistinguishable lines is worse than one that returns the best one. Names may still repeat *within the sources*; what ships is one row. Keys are still per-file and still unique, so nothing below changes.

## 0.7 Row keys, and why adding a row is now safe

Every row has a stable identity derived from its file and its name:

```
key = <file number>:<slug of the Food cell>      01:besan-gram-flour
                                                 03:coconut-rice
                                                 04:coconut-rice
```

Nothing in the tables changed to get this — the key is computed, not written down. It is unique as long as no single file repeats a name, which is the rule above and which `--check` enforces.

**What the key is for.** An ingredient in a `Composition` cell resolves to a row through `ingredientTargets` (`tools/catalog_pipeline/lib/src/ingredient_targets.dart`), which maps each ingredient string to exactly one key. It used to be inferred from names instead, and that made the meaning of an existing dish depend on which *other* rows existed: adding a pantry row literally named `Besan` silently moved twenty dishes onto a different USDA food, with no error anywhere. Pointing at keys removes the coupling rather than detecting it.

### Adding rows: the loop

```
1. write the rows                    docs/catalog/*.md, or drop a CSV in
                                     app/assets/regional_food/
2. dart run .../parse_catalog.dart --suggest      ← lines to paste for new ingredients
3. paste them into ingredient_targets.dart        ← one decision per line, by hand
4. dart run .../parse_catalog.dart --check        ← offline. No key, no network.
5. dart run .../fetch_catalog.dart                ← fetches only what the cache lacks
6. dart run .../build_seed.dart
7. dart run .../parse_catalog.dart --write-lock   ← record the new resolution
```

Steps 1–4 need no API key and no network, which is the point: **a new row can be proved harmless before anyone spends a fetch on it.** `--check` fails on a duplicate key, an ingredient nobody mapped, a target pointing at no row, a yield outside 0.4×–15×, a source file nobody has given a cuisine, or any change to what an existing row's ingredients resolve to. That last one is the guard: `docs/catalog/catalog.lock.json` is the committed record of every row's resolution, and a change to it has to be deliberate.

## 0.8 Cuisine and course tags

Two facts the source files already carry, and the pipeline records as `FoodItems.cuisineTags`:

- **Cuisine**, from the file — `01-common.md` is `pan-indian`, `02-gujarat.md` is `gujarati`, and so on.
- **Course**, from the `## N.` heading a row sits under — `tiffin`, `farsan`, `sweet`, `bread`, `rice`, `gravy`, `snack`, `beverage`.

A file that is not a single cuisine says so per section instead: `06-rice-and-biryani.md` spans several, and `Overnight oats` belongs to no cuisine at all (`modern`). Tags describe **where a dish is from, never what is in it** — no tag may ever imply a nutrient.

## 0.9 The regional CSV catalogs

`app/assets/regional_food/*.csv` carries the regional dish catalogs, and **they are the source of truth for the dishes they describe.** They hold the same five columns as the markdown tables (`Food, Also, Serving, g, Composition`), so every stage downstream — composition parsing, row keys, the lock, cuisine tags, the seed build — works on them unchanged. They are read where they are rather than converted, because two copies of a row drift.

Files are discovered by glob, so **adding the next regional catalog is dropping the file in and adding one line** to `_cuisineByCsv` in `cuisine_tags.dart`. `--check` fails on a source file nobody has given a cuisine rather than defaulting to one: a silent default would file a Bengali dish under whatever bucket came first and nobody would notice until they went looking for it.

**Precedence**, highest first, from `catalog_sources.dart`:

1. `nourishly_indian_food_catalog.csv`, then the two `karnataka_tamilnadu_gujarat` files, then `nourishly_common_international_food_catalog.csv` — these four describe each dish on its own terms;
2. every other CSV, alphabetically — the per-state files, which reuse one composition across several dishes (`Gajar halwa` and `Rice kheer` are given the same line), so where both describe a dish the file that distinguishes them wins;
3. the markdown catalog.

**CSV beats markdown**, with one exception: an **ingredient** row is never displaced by a dish row of the same name. An ingredient row is infrastructure — other recipes resolve through it — so losing one breaks every dish that used it and sometimes the dish that displaced it. `Coconut water` is exactly that: a CSV row whose only ingredient is coconut water.

When a CSV does supersede a markdown row that `ingredientTargets` points at, `--check` reports it and names the row to repoint at. That is a one-line fix, and it is deliberately a fix rather than an automatic redirect: what an ingredient means stays something a person wrote down (§0.3b).

### What the CSVs do not decide

- **Ingredients still resolve through `ingredientTargets`.** A CSV naming `Curry leaves 2 g` does not create a curry leaves row; `08-regional-pantry.md` does, and the map points at it.
- **An ingredient with no FoodData Central entry gets no invented row.** Kokum, ker, sangri, ajwain and kachampuli are settled in `ingredient_targets.dart` against the closest row the catalog already measures, with the reason on the line.
- **A count is not a weight.** `Egg 2 pieces` resolves through the target row's own serving columns — `Egg, boiled | 1 large | 50 g` — and nowhere else. A row that does not count pieces makes the pipeline say so rather than pick a constant.
