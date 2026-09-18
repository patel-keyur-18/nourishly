# Design

*[Architecture index](../architecture/README.md) · [Catalog specification](../catalog/README.md)*

## 1. Theme — decided: **Indigo**

**[`tokens/nourishly-indigo.json`](./tokens/nourishly-indigo.json)** is the single source of truth for the design system: colour for both modes, type scale, spacing, radii, stroke widths, elevation, motion, touch targets, and the rules the UI must honour.

Everything downstream reads that file. The prototype generates its CSS from it, and any future Flutter `ThemeData` is generated from it too — so the spec, the prototype and the app cannot drift apart by hand-editing.

| | Light | Dark |
|---|---|---|
| Accent | `#3b4d9e` | `#8b99ea` |
| Surface | `#ffffff` | `#161927` |
| Ink | `#161829` | `#e9ebf6` |
| Protein / Carbs / Fat / Fibre | `#c1572d` `#1f6fa5` `#c7961a` `#0f8a5e` | `#d16536` `#3f92cf` `#bb8a0c` `#2a9b6e` |

Both series palettes pass all six checks of the data-visualisation validator — lightness band, chroma floor, colour-blindness separation, normal-vision floor, and contrast against their own surface.

<details>
<summary>The four themes that were not chosen</summary>

Indigo was picked from five candidates compared side by side on the same dashboard. The comparison page has been removed now that the decision is made; the reasoning is kept here.

| Candidate | Direction | Why not |
|---|---|---|
| **Haldi** | Turmeric on warm paper — the only palette drawn from the kitchen rather than software convention | The most characterful option, but warm grounds date faster and gold-on-white needs constant care to stay legible |
| **Neem** | Green-forward, crisp; the conventional health-app read | Safe and instantly legible, but unmemorable, and its accent sat close to the "on target" status hue |
| **Kora** | Near-colourless chrome; colour means data and nothing else | Strongest chart reading of the five, but little personality — it relies entirely on typography and spacing being right |
| **Nilgiri** | Teal, dark-first, light mode derived from it | Best dark mode by design, but the light half was the weaker one, and teal reads "tech product" more than "household app" |

Indigo won on being legible under dense numbers while still having a point of view, and on keeping four macro hues clearly separated against cool neutrals.

</details>

## 2. Screens — decided

**[`decisions.md`](./decisions.md)** records the chosen treatment for each of the 13 screens, what the set adds up to, and two refinements worth settling before implementation.

**[`prototype.html`](./prototype.html)** opens showing only the approved screens. Toggle **Show all 28 options** in the header to see the alternatives — they are retained rather than deleted, because the reasoning behind a rejection is worth keeping and a rejected layout is often right for a later variant.

| # | Screen | Chosen |
|---|---|---|
| 1 | Onboarding | B — Single promise screen |
| 2 | Profile setup | A — One question per step *(all 5 steps steppable)* |
| 3 | Daily dashboard | A — Ring-led |
| 4 | Add food | B — Full screen, search first |
| 5 | Food search | A — Grouped by source |
| 6 | Portion & food detail | A — Serving chips + stepper |
| 7 | Meal templates | A — Cards with contents |
| 8 | Water | A — Fill visual |
| 9 | Daily report | C — Full table |
| 10 | Weekly report | A — Charts first |
| 11 | Monthly report | A — Trend line |
| 12 | Goals & targets | B — Card per target |
| 13 | Settings & data | A — Grouped list |

Regenerate after any token or decision change:

```
python3 docs/design/_build_prototype.py
```

## Design rules the screens demonstrate

These come from the architecture rather than from taste:

| Rule | Where you see it | Source |
|---|---|---|
| Bars are read against a target, not filled to an edge | The tick on every bar sits at 100% of target; the track runs to 125% so overshoot has somewhere to go | §27.11 |
| Over-target is never alarming | `above` uses a violet. Red is reserved for destructive actions | §21.8 |
| Never colour alone | Every status carries a dot **and** a label | NFR-A-04 |
| Unknown is not zero | "Calcium — no data" on the daily report | AP-4 |
| The score withholds itself when data is too thin | "Micronutrients: not scored, only 58% covered" | §21.5 |
| Energy shows remaining, not consumed | "410 kcal left" is the large number | UX-3 |
| Numbers align | Tabular figures throughout | §27.11 |

---

## Files

| File | Purpose |
|---|---|
| `tokens/nourishly-indigo.json` | **The approved design system.** Source of truth for everything else |
| `decisions.md` | The 13 screen decisions and their consequences |
| `prototype.html` | Generated. Approved screens, with alternatives behind a toggle |
| `_build_prototype.py` | Generates `prototype.html` from the token file |
