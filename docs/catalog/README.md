# Nourishly Food Catalog Specification

*Revision 0.1 · 2026-09-09 · [Architecture index](../architecture/README.md) · [Personal-Use Scope](../architecture/00-scope.md)*

The curated food list for the household catalog, covering **Gujarat, Tamil Nadu and Karnataka** plus the pan-Indian staples all three share.

| File | Contents | Items |
|---|---|---|
| [`01-common.md`](./01-common.md) | Pan-Indian staples: grains, dals, dairy, vegetables, fruit, oils, beverages, non-veg, snacks | ~130 |
| [`02-gujarat.md`](./02-gujarat.md) | Gujarati dishes, farsan, sweets | ~85 |
| [`03-tamil-nadu.md`](./03-tamil-nadu.md) | Tamil dishes, tiffin, kuzhambu, sweets | ~80 |
| [`04-karnataka.md`](./04-karnataka.md) | Kannadiga dishes, North Karnataka and coastal | ~70 |
| | **Total** | **~365** |

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

An ingredient string in a Composition cell is resolved in this order, and no other:

1. **A row in this catalog**, matched on its own name, then an `Also` synonym, then the leading segment before a `,` or `/`. A name several rows claim inside a tier is *not* guessed at.
2. **`ingredientAliases`** (`tools/catalog_pipeline/lib/src/ingredient_aliases.dart`) — one curated line per ambiguity, reviewable in a diff. This is where `oil` → `Groundnut oil` and `rice` → `Rice, white, raw` are settled.
3. **Nothing.** The pipeline reports the dish and the ingredient as a failure and drops the dish from the draft.

There used to be a fourth step: search FoodData Central for the raw ingredient string. It is gone, and its removal is the point of this section. FDC has never heard of `sev`, `khoya` or `idli batter`, but its search returns whatever shares a word — so `batter` resolved to *APPLEBEE'S, fish, hand battered*, `rice` to *Rice noodles, cooked*, `milk` to *Crackers, milk*, and `potato filling` to *Dumpling, potato- or cheese-filled, frozen*. Every one of those matched, so the pipeline reported **zero failures** while computing 55 dishes — idli, every dosa, curd rice, every rice dish — from the wrong food, and shipping them under a `verified` quality badge.

That is precisely the failure §0.2 exists to prevent, and it is worse than a gap because it is invisible. A dish the catalog cannot yet resolve is now simply absent, which the app already handles (AP-4, §21.5); a dish resolved from the wrong food is a number that looks sourced and is not.

**An unresolved ingredient is a curation task, not a pipeline bug.** Close it one of two ways:

- If it is a real, distinct food — `Pav`, `Broken wheat`, `Hung curd`, `Colocasia leaves` — give it its own row here, with its own USDA basis. Do not alias it to a near neighbour.
- If it is another name for a row that already exists — `dosa`, `podi`, `chickpeas` — add a line to `ingredientAliases` saying which row, and why.

Some cannot honestly be closed either way and are deliberately left failing: the slashed alternates (`oil/ghee`, `dudhi/methi`), the concentrations (`toor dal water`, `milk reduced`), the spice powders (`sambar podi`, `vangi bath powder`), and the composite pastes and fillings. Each needs a proportion nobody has written down, and a plausible-looking invented number is exactly what this catalog refuses to carry.

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
