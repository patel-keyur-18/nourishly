# Pasta, millets and modern breakfast

*[Catalog index](./README.md) · ~9 items*

The part of this household's cooking that belongs to no regional tradition: pasta in a milk or pumpkin sauce, the millet versions of pasta and vermicelli, and an overnight-oats breakfast.

**Cuisine tagging:** the pasta rows are `italian`, everything else is `modern` — a section-level tag, because this file is not one cuisine and overnight oats is not from anywhere ([§0.8](./README.md#08-cuisine-and-course-tags)).

---

## 1. Pantry

| Food | Also | Serving | g | Composition |
|---|---|---|---|---|
| Pasta, dry | penne, spaghetti, macaroni, fusilli | 100 g | 100 | USDA pasta dry enriched |
| Millet pasta, dry | jowar pasta, sorghum pasta | 100 g | 100 | Jowar flour 100 g — 100% jowar, no wheat |
| Millet vermicelli, raw | jowar semiya, millet semiya, millet shavige | 50 g | 50 | Jowar flour 50 g — 100% jowar, no wheat |

> **The two millet rows are composed, not matched.** FoodData Central has no "millet pasta" or "millet vermicelli". Matching them to durum wheat would be wrong in exactly the quiet way [§0.2](./README.md#02-how-dishes-get-their-nutrients-recipes-not-tables) exists to prevent — same shape, different grain, no warning anywhere — so instead they are built from a flour the catalog already carries, which is what the recipe mechanism is for.
>
> **The millet is jowar, confirmed by the household, and both products are 100% millet with no wheat.** So `Jowar flour` here is the real ingredient, not a placeholder. If a different packet ever comes home, changing that one ingredient name is the whole edit and everything downstream recomputes.

---

## 2. Pasta

| Food | Also | Serving | g | Composition |
|---|---|---|---|---|
| White sauce pasta | béchamel pasta, creamy pasta | 1 plate | 280 | Pasta 80 g, milk 120 ml, cheese 15 g, butter 12 g, refined flour 10 g, black pepper |
| Pumpkin sauce pasta | — | 1 plate | 280 | Pasta 80 g, pumpkin 90 g, milk 60 ml, groundnut oil 10 g, garlic |
| Millet pasta, cooked | — | 1 plate | 260 | Millet pasta 80 g, tomato 60 g, capsicum 25 g, groundnut oil 10 g, garlic |

---

## 3. Vermicelli

The catalog already has `Semiya upma` and `Shavige bath` for plain wheat vermicelli; these are the two other ways it is made here.

| Food | Also | Serving | g | Composition |
|---|---|---|---|---|
| Lemon vermicelli | lemon semiya, elumichai sevai | 1 katori | 150 | Vermicelli 45 g, groundnut oil 8 g, peanuts 8 g, lemon, curry leaves, turmeric |
| Millet vermicelli upma | millet semiya upma | 1 katori | 150 | Millet vermicelli 45 g, groundnut oil 8 g, vegetables 25 g, mustard |

---

## 4. Modern breakfast

| Food | Also | Serving | g | Composition |
|---|---|---|---|---|
| Overnight oats | soaked oats, oats bowl | 1 bowl | 250 | Oats 21 g, milk 120 ml, banana 80 g, dates 8 g, honey 7 g, chia seeds 2.5 g, pumpkin seeds 2.5 g, watermelon seeds 2.5 g, sunflower seeds 2.5 g |

Two things worth recording about this row:

**The 21 g of oats is measured, not estimated.** Everything else in the line is a [§0.3](./README.md#03-serving-weights-starting-estimates-to-be-calibrated-once) starting estimate — the milk from the usual 1 : 1.5 soak, the banana from "1 small" against the catalog's 100 g medium, the date from the catalog's own 2-pieces-16-g row. 246 g of ingredients into a 250 g bowl: a cold assembly, so there is no cooking loss to model and the yield lands at 1.0.

**The four seeds are four ingredients, not one "mixed seeds" line.** Their energy is close enough that lumping them together would barely move the calorie count — but chia is fibre and omega-3, pumpkin is zinc and magnesium, sunflower is vitamin E, and those are exactly the numbers this app exists to track. Splitting them costs nothing and keeps the micronutrients real.
