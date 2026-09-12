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

## Two refinements — approved and applied

Both were proposed after the screen choices were made, approved on 2026-09-09, and are now reflected in the prototype.

### Daily report — C is a layout, not a replacement for the insights ✅

Option C shows every tracked nutrient against target in one scan, which is exactly what it should do. But as first drawn it dropped two things the architecture requires: the one-sentence verdict (FR-D-07, §27.8) and the 2–4 plain-language insights.

Those are not decoration. The verdict is what makes the report readable by someone who does not want to parse a table, and the insight engine is the only place the app turns a number into a suggested action.

**Applied.** The screen now reads: verdict and score → the full nutrient table → *What to do about it* (the insights) → meals. C's density with A's ability to be understood in two seconds. The table replaced A's *narrative body*, not the verdict or the insight engine.

### Goals — B needs a length strategy ✅

A card per target reads well for the six headline targets. Applied to all 24 tracked nutrients it becomes a very long screen.

**Applied.** Cards for the six headline targets — energy, protein, carbs, fat, fibre, water — under a *The six you look at* heading, then the remaining 18 micronutrients as a compact list that opens as a card when tapped. B's clarity where targets are actually adjusted, without a screen that scrolls forever.

## One deliberate departure from the prototype

### Screen 13 — one profile per phone ✅

*Decided 2026-09-12, during Phase 5.*

Prototype 13A opens with a **Profiles on this phone** group: two avatars,
an Active marker, and **+ Add a profile**. The built screen has no such
group, and will not get one.

The household runs one profile per phone, which is also what §0.4 calls
the typical case. With that settled, a switcher is not a simplification
of anything — it is a second concept ("whose data am I looking at?")
threaded through every screen, every query and every export, in service
of a case that does not arise. The schema keeps `owner_id` on every owned
row regardless, so nothing here forecloses adding profiles later; it is
the *UI* that is not built.

Everything else on screen 13 follows the prototype: the grouped-list
treatment, Preferences with its **Reminders** row, the **Your data**
group with export, backup and the destructive row in red, and the centred
version footer.

**This is the one place the implementation deliberately diverges from an
approved screen.** It is recorded here rather than in a code comment so
that the next person to compare the app against `prototype.html` finds
the answer where they will look for it.

## What happens next

These decisions become the implementation targets, one feature module per screen under the structure in §12.3 of the architecture. The prototype is the reference for layout and hierarchy; `tokens/nourishly-indigo.json` is the reference for every value.

**No implementation has begun, and none will until it is approved.**
