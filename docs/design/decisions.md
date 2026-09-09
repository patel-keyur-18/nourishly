# Screen Decisions

*Approved 2026-09-09 · [Design index](./README.md) · [Prototype](./prototype.html) · [Tokens](./tokens/nourishly-indigo.json)*

The chosen treatment for each of the 13 screens. Discarded options remain in the prototype — toggle **Show all 28** in its header — because the reasoning behind a rejection is worth keeping, and a rejected layout is often the right answer for a later variant.

| # | Screen | Chosen | Not chosen |
|---|---|---|---|
| 1 | Onboarding | **B — Single promise screen** | A — Value cards first |
| 2 | Profile setup | **A — One question per step** | B — Single scrollable form |
| 3 | Daily dashboard | **A — Ring-led** | B — Meals-led · C — Numbers grid |
| 4 | Add food | **B — Full screen, search first** | A — Sheet with tabs |
| 5 | Food search | **A — Grouped by source** | B — Flat ranked list |
| 6 | Portion & food detail | **A — Serving chips + stepper** | B — Amount first |
| 7 | Meal templates | **A — Cards with contents** | B — Compact rows |
| 8 | Water | **A — Fill visual** | B — Glass grid |
| 9 | Daily report | **C — Full table** | A — Verdict first · B — Score breakdown first |
| 10 | Weekly report | **A — Charts first** | B — Findings first |
| 11 | Monthly report | **A — Trend line** | B — Calendar heat-map |
| 12 | Goals & targets | **B — Card per target** | A — Grouped list |
| 13 | Settings & data | **A — Grouped list** | B — Cards with reasons |

## What the set adds up to

The choices are coherent, which is worth saying because 13 independent decisions need not be. Three patterns run through them:

**Density over narrative.** Full table for the daily report, charts before findings for the week, a trend line over a heat-map. The reader of these screens is assumed to be comfortable with numbers and to want them without a preamble.

**Progressive where the stakes are high, direct everywhere else.** Setup takes five steps because getting targets wrong is costly and each answer deserves an explanation. Everything after that is direct: full-screen search, chips and a stepper, one tap to add water.

**Structure that shows provenance.** Grouped search results and cards-with-contents for templates both spend vertical space to make the *source* of something visible. That matches the architecture's position that data quality has to be legible, not assumed (§19.11).

## Two refinements worth settling before implementation

Neither blocks anything, and both are noted rather than decided.

### Daily report — C is a layout, not a replacement for the insights

Option C shows every tracked nutrient against target in one scan, which is exactly what it should do. But as drawn it drops two things the architecture requires: the one-sentence verdict (FR-D-07, §27.8) and the 2–4 plain-language insights.

Those are not decoration. The verdict is what makes the report readable by someone who does not want to parse a table, and the insight engine is the only place the app turns a number into a suggested action.

> **Proposed:** keep C's table as the body of the screen, and retain the verdict line above it and the insights below it. That is C's density with A's ability to be understood in two seconds — the table replaces A's *narrative body*, not the verdict or the insight engine.

### Goals — B needs a length strategy

A card per target reads well for the six headline targets. Applied to all 24 tracked nutrients it becomes a very long screen.

> **Proposed:** cards for energy, protein, carbs, fat, fibre and water; the remaining micronutrients as a compact list below, expandable to a card when edited. This keeps B's clarity where the user actually adjusts things without a screen that scrolls forever.

## What happens next

These decisions become the implementation targets, one feature module per screen under the structure in §12.3 of the architecture. The prototype is the reference for layout and hierarchy; `tokens/nourishly-indigo.json` is the reference for every value.

**No implementation has begun, and none will until it is approved.**
