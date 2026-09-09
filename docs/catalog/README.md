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

## 0.4 Column meanings

| Column | Meaning |
|---|---|
| **Food** | Canonical name as it should appear in search |
| **Also** | Alternate names, regional spellings, transliterations. **These matter** — they feed `FoodAltName` and the FTS index, and they are why "panir", "paneer" and "पनीर" all find the same food (§22.5) |
| **Serving** | The default serving offered when logging |
| **g** | Estimated grams for that serving (§0.3) |
| **Composition** | Ingredient breakdown per serving, or the sourcing basis |

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
