# Design

*[Architecture index](../architecture/README.md) · [Catalog specification](../catalog/README.md)*

## 1. Theme — decided: **Indigo**

**[`tokens/nourishly-indigo.json`](./tokens/nourishly-indigo.json)** is the single source of truth for the design system: colour for both modes, type scale, spacing, radii, elevation, motion, touch targets, and the rules the UI must honour.

Everything downstream reads that file. The prototype generates its CSS from it, and any future Flutter `ThemeData` is generated from it too — so the spec, the prototype and the app cannot drift apart by hand-editing.

| | Light | Dark |
|---|---|---|
| Accent | `#3b4d9e` | `#8b99ea` |
| Surface | `#ffffff` | `#161927` |
| Ink | `#161829` | `#e9ebf6` |
| Protein / Carbs / Fat / Fibre | `#c1572d` `#1f6fa5` `#c7961a` `#0f8a5e` | `#d16536` `#3f92cf` `#bb8a0c` `#2a9b6e` |

Both series palettes pass all six checks of the data-visualisation validator — lightness band, chroma floor, colour-blindness separation, normal-vision floor, and contrast against their own surface.

## 2. Screen prototype — awaiting per-screen decisions

**[`prototype.html`](./prototype.html)** — all 13 screens, each with two or three alternative treatments of the same content, in one page. Light/dark toggle applies to every screen at once.

Choices are recorded in the browser and can be copied out as a plain list from the **My choices** panel.

| # | Screen | Options |
|---|---|---|
| 1 | Onboarding | Value cards · Single promise |
| 2 | Profile setup | One question per step · Single form |
| 3 | Daily dashboard | Ring-led · Meals-led · Numbers grid |
| 4 | Add food | Sheet with tabs · Full screen search |
| 5 | Food search | Grouped by source · Flat ranked |
| 6 | Portion & food detail | Serving chips · Amount first |
| 7 | Meal templates | Cards · Compact rows |
| 8 | Water | Fill visual · Glass grid |
| 9 | Daily report | Verdict first · Score breakdown · Full table |
| 10 | Weekly report | Charts first · Findings first |
| 11 | Monthly report | Trend line · Calendar heat-map |
| 12 | Goals & targets | Grouped list · Card per target |
| 13 | Settings & data | Grouped list · Cards with reasons |

Regenerate after any token change:

```
python3 docs/design/_build_prototype.py
```

## 3. Theme comparison (superseded)

**[`theme-options.html`](./theme-options.html)** — the five candidates that were compared before Indigo was chosen. Kept as the record of what was weighed.

| Option | Direction | Character |
|---|---|---|
| **Haldi** | Turmeric on warm paper | The only palette drawn from the kitchen rather than from software convention |
| **Neem** | Green-forward, crisp | The conventional health-app read, executed with restraint |
| **Indigo** | Deep indigo, cool neutrals | Reads as an instrument you consult, not an app that nags |
| **Kora** | Near-colourless chrome | Colour means data and nothing else |
| **Nilgiri** | Teal, dark-first | Dark mode designed first, light derived from it |

### What was decided before the colours were picked

Each theme is a complete token set: surfaces, ink at three weights, an accent, and **four macro hues** for protein, carbs, fat and fibre.

Those four hues are the part that had to be right rather than pretty. All ten palettes (five themes × two modes) were checked programmatically for colour-blindness separation, chroma floor, lightness band, and contrast against their own surface. **Every one passes in both modes**, so the choice is purely about character — no option costs legibility.

Two collisions were caught and fixed this way: Indigo's accent originally matched its carbohydrate hue, and Nilgiri's teal accent matched its fibre hue. An accent that doubles as a data colour makes "brand" and "measurement" indistinguishable on screen.

### Design rules the previews demonstrate

These hold whichever theme is chosen, and they come from the architecture rather than from taste:

| Rule | Where you see it | Source |
|---|---|---|
| Bars are read against a target, not filled to an edge | The tick mark on every macro bar sits at 100% of target; the track runs to 125% so overshoot has somewhere to go | §27.11 |
| Over-target is never alarming | `above` uses a violet, not red. A food tracker must not scold | §21.8 |
| Never colour alone | Every status chip carries a dot **and** a label | NFR-A-04 |
| The score is withheld when the data is too thin | The "Micros: 58% covered — not scored" chip is coverage gating showing its work | §21.5 |
| Energy shows remaining, not consumed | "410 kcal left" is the large number; eaten and target sit beside it | UX-3 |
| Numbers align | Tabular figures throughout | §27.11 |

---

## Files

| File | Purpose |
|---|---|
| `tokens/nourishly-indigo.json` | **The approved design system.** Source of truth for everything below |
| `prototype.html` | Generated. All 13 screens with options |
| `_build_prototype.py` | Generates `prototype.html` from the token file |
| `theme-options.html` | Generated. The five-way comparison, superseded |
| `_generate.py` | Generates `theme-options.html` |
