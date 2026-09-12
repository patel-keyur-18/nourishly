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

## Four deliberate departures from the prototype

### Screen 13 — an Appearance row the prototype does not draw ✅

*Decided 2026-09-12.*

Prototype 13A's Preferences group is Units, Week starts, Day rolls over,
Reminders and Show daily score. There is no appearance control anywhere on
it, and there was none in the app either.

That turned out to be a gap rather than a decision. Dark mode has been
first-class since Phase 1 — a complete dark palette in the token file, a
full `NourishlyTheme.dark()`, and `UserPreferences.theme` read and honoured
at the root of the app. **Nothing could write that column.** The only code
that ever set it was the v2→v3 migration, which pins every row to `light`.
So a priority-1 requirement (FR-S-09, "full dark mode and dynamic type
support") was built, wired, and unreachable, and the dark half of the
design system was seen only by tests.

**Applied.** A single **Appearance** row in **Preferences** — Light, Dark,
or **Match my phone**, in the same bottom sheet every other picker in the
app uses. Light stays the default, because the palette was drawn
light-first and the prototype was approved in it (§27.14); what changes is
that it is now a default rather than a sentence.

It follows 13A's own row treatment — the label, its current value on the
right, a chevron. The departure is that the row exists at all.

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

### Screen 13 — the profile is its own screen ✅

*Decided 2026-09-12, with the UX revision ([plan](./ux-revision-plan.md)).*

The built screen 13 had accumulated five groups: *You* (name, body,
diet, goals, recipes), *Weight*, *What you see*, *Units and the day*, and
*Your data*. Every one of them arrived with a feature that needed
somewhere to live, and each was defensible on its own. Together they made
the screen the place where *everything* about a profile lived — long,
with the genuinely settings-like rows (units, week start, rollover) below
the fold, and prototype 13A's "dense, scannable, nothing to read" turned
into an explanatory subtitle under almost every row.

**Applied.** Two screens where there was one:

- **Settings** is 13A again — an app bar titled *Settings*, three groups
  (*Profile*, *Preferences*, *Your data*) of uniform label-plus-value
  rows, and the centred fine print. The first group's row is the profile,
  and opens it. **Your recipes** stays here.
- **Profile** (`/profile/me`) is new, and holds what the prototype's
  profile row implies you would find behind it: name, date of birth and
  reference values; height and weight with the weight series; activity
  and goal, with a way through to *Goals & targets*; and the stated diet.

There is no prototype screen for the profile — the approved set covers the
thirteen screens of the logging and reporting flow. It is drawn in the same
idiom as the rest, and borrows the one element worth keeping from the
unchosen 13B: its `.prof` block, an avatar with a name and the single line
that says what this profile is set up for.

### Screen 13 — switches for the two safety toggles ✅

*Decided 2026-09-12.*

13A draws *Show daily score* as a value and a chevron, like every other
row in Preferences. Applied to a boolean that reads as a promise of a
screen behind it, and there should not be one: choosing between On and Off
does not deserve a sheet. Both §21.8 toggles — *Show daily score* and
*Hide energy* — keep the row shape and take a trailing switch, and the
whole row is the target rather than the switch alone (NFR-A-03).

### Everything else on 13 follows the prototype

The grouped-list treatment, Preferences with its **Reminders** row, the
**Your data** group with export, backup and the destructive row in red,
and the centred version footer.

**These four are the only places the implementation deliberately diverges
from an approved screen.** They are recorded here rather than only in a
code comment, so that the next person holding the app next to
`prototype.html` finds the answer where they will look for it.

## One pattern for dialogs and messages

*Decided 2026-09-12, with the same revision.*

Not a screen decision, but a design-system one, and the prototype has
nothing to say about either: **every dialog in the app is one shape, and
no message is permanent.**

`NourishlyDialog` is that shape — an optional icon, a short question, one
paragraph of what happens next, an optional content slot, then cancel on
the left and the thing the user came to do on the right, filled. Three
helpers cover what the app actually asks: a yes/no
(`showNourishlyConfirm`), one typed value (`showNourishlyPrompt`), and one
choice from a list (`showNourishlyOptions`, a bottom sheet because the
choice is the whole interaction). Red is reserved for the single
destructive action, which is also the only one that asks twice.

`showNourishlySnack` is the only way to show a transient message: five
seconds, one at a time, dismissible by hand or by swipe. What it replaced
had no duration set anywhere, queued messages behind each other, and — in
the cases where Flutter suppresses its own dismiss timer — left "Removed
200 ml" on screen until something else came along.

## What happens next

These decisions became the implementation targets, one feature module per screen under the structure in §12.3 of the architecture. The prototype is the reference for layout and hierarchy; `tokens/nourishly-indigo.json` is the reference for every value.

**All 13 screens are built**, through Phase 5 of the [roadmap](../architecture/00-scope.md#09-revised-effort-estimate) — with the four departures above, each recorded with its reasoning, plus the profile screen the revision added. Phase 6 puts the app on real phones, which is where the design gets its first honest test — and the 2026-09-12 revision is what an early look at it produced.
