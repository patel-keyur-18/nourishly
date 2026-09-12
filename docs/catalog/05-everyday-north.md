# Everyday North Indian

*[Catalog index](./README.md) · ~13 items · Tier 1 daily items marked **①***

The everyday North Indian cooking this household actually does — plain dals, chana and bean sabzis, stuffed parathas, and the one street dish that is cooked at home often enough to belong here.

Two things about this file, both deliberate:

- **It is short on purpose.** Catalog spec [§0.5](./README.md#05-priority-tiers) and risk R-1 both say to curate against what the kitchen cooks, not against the length of a cuisine's repertoire. There is no dal makhani, no rajma dish, no paneer gravy and no naan here because nobody asked for them. They go in when a search for them fails ([§31.6](../architecture/09-privacy-scalability.md)), not before.
- **Oil is groundnut oil and it is named.** Every gram of fat in a row here is pan oil, which is a choice the cook makes — never absorbed frying oil, which is not ([§0.6](./README.md#06-conventions)). That distinction is what lets the same dish be recorded as this household cooks it, with less of it.

---

## 1. Dal

The plain dal this file adds was a real gap: the catalog had a sweet `Gujarati dal` and a `Dal dhokli`, but no plain tempered dal at all — while [§0.6](./README.md#06-conventions) used "Dal, cooked" as its worked example of a row that ought to exist.

| Food | Also | Serving | g | Composition |
|---|---|---|---|---|
| **①** Dal tadka, plain | toor dal tadka, dal fry, normal dal | 1 katori | 150 | Toor dal 30 g, groundnut oil 5 g, turmeric, cumin, salt |
| **①** Moong dal, cooked | moong dal tadka, yellow dal | 1 katori | 150 | Moong dal 30 g, groundnut oil 5 g, turmeric, cumin |
| Palak dal | dal palak, spinach dal | 1 katori | 160 | Toor dal 25 g, spinach 50 g, groundnut oil 5 g, garlic, cumin |

> **The row most worth weighing.** `Dal tadka, plain` puts 35 g of ingredients into a 150 g katori — a yield of 4.3×, against the sweeter, thicker Gujarati dal's 2.4×. That is the honest arithmetic for a dal with no jaggery, tamarind, tomato or peanuts in it, but a thicker or thinner dal moves it a long way, it is eaten several times a week, and the two rows above are written against it. One session with a kitchen scale fixes all three ([§0.3](./README.md#03-serving-weights-starting-estimates-to-be-calibrated-once)).

---

## 2. Chana, beans and everyday sabzi

| Food | Also | Serving | g | Composition |
|---|---|---|---|---|
| **①** Chhole | chole, chana masala, chholay | 1 katori | 150 | Kabuli chana 40 g, tomato 35 g, onion 30 g, groundnut oil 10 g, garam masala, ginger |
| Kabuli chana subji | chana nu shaak, chickpea sabzi | 1 katori | 140 | Kabuli chana 40 g, tomato 25 g, onion 20 g, groundnut oil 8 g, coriander |
| Cowpea subji | chawli nu shaak, lobia subji, alasande palya | 1 katori | 140 | Chawli 40 g, tomato 25 g, onion 20 g, groundnut oil 8 g, garlic |
| **①** Tomato subji | tameta nu shaak, thakkali subji | 1 katori | 130 | Tomato 110 g, onion 20 g, groundnut oil 8 g, mustard, turmeric |
| Mushroom subji | khumb masala, mushroom sabzi | 1 katori | 130 | Mushroom 110 g, onion 25 g, tomato 20 g, groundnut oil 9 g, garam masala |
| Raw banana fry | kacha kela fry, vazhaikkai varuval, balekayi palya | 1 katori | 110 | Raw banana 100 g, groundnut oil 10 g, turmeric, chilli powder |

`Chhole` and `Kabuli chana subji` are the same pulse cooked two ways and are separate rows for the reason [§0.6](./README.md#06-conventions) gives: the gravy version carries meaningfully more oil and more masala than the drier everyday one, and fat is where portion estimates go most wrong.

---

## 3. Stuffed parathas

A stuffed paratha is its own food, not a chapati with something on it — it carries 9 g of fat a chapati does not ([§0.6](./README.md#06-conventions)).

| Food | Also | Serving | g | Composition |
|---|---|---|---|---|
| Sweet potato paratha | shakarkand paratha | 1 piece | 95 | Wheat flour 40 g, sweet potato 40 g, groundnut oil 9 g, ajwain, salt |
| Palak paneer paratha | palak paneer stuffed paratha | 1 piece | 105 | Wheat flour 40 g, paneer 25 g, spinach 20 g, groundnut oil 9 g, garlic |

---

## 4. Egg

| Food | Also | Serving | g | Composition |
|---|---|---|---|---|
| Egg bhurji | anda bhurji, scrambled egg masala | 1 katori | 130 | Egg 100 g, onion 25 g, tomato 20 g, groundnut oil 8 g, green chilli |

---

## 5. Street food cooked at home

| Food | Also | Serving | g | Composition |
|---|---|---|---|---|
| Pav bhaji | — | 1 plate | 300 | Pav 90 g, potato 90 g, tomato 50 g, onion 30 g, capsicum 25 g, green peas 20 g, butter 20 g |

> **20 g of butter is the whole point of the dish, and the whole opportunity.** Pav bhaji carries more added fat than anything else in this file by a wide margin, which makes it the first dish worth recording a lighter household version of.

---

## 6. Meal templates worth defining

Not rows — these are plates, and the app's `MealTemplates` tables exist for them. **The template feature is not built yet**, so until it is, logging one of these is two entries rather than one. They are written down here so that the spec is ready when the feature is.

| Template | Contents |
|---|---|
| **Dal and rice** | Dal tadka 1 katori + rice 1 katori |
| **Moong dal and rice** | Moong dal 1 katori + rice 1 katori |
| **Palak dal and rice** | Palak dal 1 katori + rice 1 katori |
| **Chhole and chapati** | Chhole 1 katori + 2 chapati |
