---
name: Nourishly
description: A private household nutrition and hydration tracker, read like a precise instrument rather than a scored game.
colors:
  ledger-indigo: "#3b4d9e"
  ledger-indigo-hover: "#334389"
  ledger-indigo-soft: "#dfe3f4"
  ledger-indigo-soft-ink: "#2c3a7a"
  terracotta-protein: "#c1572d"
  slate-blue-carbs: "#1f6fa5"
  ochre-fat: "#c7961a"
  forest-fibre: "#0f8a5e"
  verdant-ok: "#2e7d4f"
  amber-low: "#a06d0c"
  violet-high: "#7a5ea8"
  slate-unknown: "#7b8098"
  danger-red: "#a52a1f"
  danger-red-soft: "#f7e2df"
  cool-paper: "#f2f3f8"
  surface-white: "#ffffff"
  soft-surface: "#e9ebf4"
  hairline: "#d6d9e8"
  hairline-strong: "#b9bed6"
  ink: "#161829"
  ink-secondary: "#4b4f66"
  ink-tertiary: "#7b8098"
  ink-disabled: "#a3a7bb"
typography:
  display:
    fontFamily: "IBM Plex Sans, system-ui, -apple-system, 'Segoe UI', Roboto, sans-serif"
    fontSize: "30px"
    fontWeight: 700
    lineHeight: 1.12
    letterSpacing: "-0.02em"
  title:
    fontFamily: "IBM Plex Sans, system-ui, -apple-system, 'Segoe UI', Roboto, sans-serif"
    fontSize: "21px"
    fontWeight: 700
    lineHeight: 1.22
    letterSpacing: "-0.015em"
  heading:
    fontFamily: "IBM Plex Sans, system-ui, -apple-system, 'Segoe UI', Roboto, sans-serif"
    fontSize: "17px"
    fontWeight: 600
    lineHeight: 1.3
    letterSpacing: "-0.01em"
  bodyLarge:
    fontFamily: "IBM Plex Sans, system-ui, -apple-system, 'Segoe UI', Roboto, sans-serif"
    fontSize: "15px"
    fontWeight: 400
    lineHeight: 1.5
  body:
    fontFamily: "IBM Plex Sans, system-ui, -apple-system, 'Segoe UI', Roboto, sans-serif"
    fontSize: "14px"
    fontWeight: 400
    lineHeight: 1.5
  label:
    fontFamily: "IBM Plex Sans, system-ui, -apple-system, 'Segoe UI', Roboto, sans-serif"
    fontSize: "13px"
    fontWeight: 600
    lineHeight: 1.35
  caption:
    fontFamily: "IBM Plex Sans, system-ui, -apple-system, 'Segoe UI', Roboto, sans-serif"
    fontSize: "12px"
    fontWeight: 400
    lineHeight: 1.4
    letterSpacing: "0.005em"
  overline:
    fontFamily: "IBM Plex Sans, system-ui, -apple-system, 'Segoe UI', Roboto, sans-serif"
    fontSize: "11px"
    fontWeight: 600
    lineHeight: 1.3
    letterSpacing: "0.09em"
  numeral:
    fontFamily: "IBM Plex Mono, ui-monospace, monospace"
    fontSize: "28px"
    fontWeight: 700
    lineHeight: 1.0
    letterSpacing: "-0.02em"
rounded:
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "22px"
  pill: "999px"
spacing:
  "0": "0px"
  "1": "4px"
  "2": "8px"
  "3": "12px"
  "4": "16px"
  "5": "20px"
  "6": "24px"
  "7": "32px"
  "8": "40px"
  "9": "48px"
components:
  button-primary:
    backgroundColor: "{colors.ledger-indigo}"
    textColor: "{colors.surface-white}"
    rounded: "{rounded.pill}"
    padding: "12px 18px"
    height: "46px"
  button-primary-hover:
    backgroundColor: "{colors.ledger-indigo-hover}"
  button-soft:
    backgroundColor: "{colors.ledger-indigo-soft}"
    textColor: "{colors.ledger-indigo-soft-ink}"
    rounded: "{rounded.pill}"
    padding: "12px 18px"
    height: "46px"
  button-ghost:
    backgroundColor: "transparent"
    textColor: "{colors.ink-secondary}"
    rounded: "{rounded.pill}"
    padding: "12px 18px"
    height: "46px"
  chip:
    backgroundColor: "{colors.soft-surface}"
    textColor: "{colors.ink-secondary}"
    rounded: "{rounded.pill}"
    padding: "4px 10px"
  card:
    backgroundColor: "{colors.surface-white}"
    rounded: "{rounded.lg}"
    padding: "12px 14px"
---

# Design System: Nourishly

## Overview

**Creative North Star: "The Honest Instrument"**

Nourishly reads like a precise measuring device that has been placed in a kitchen, not a fitness app performing motivation. It shows what it knows, states plainly what it doesn't ("Calcium — no data"), and never rounds an absence up to zero. The score withholds itself rather than pretend confidence it hasn't earned. Nothing here scolds: exceeding a target is drawn in violet, not red, because a food tracker's job is to inform a household, not shame it.

The system is precise, restrained, and quietly confident. One accent — Ledger Indigo — carries almost all interactive weight; brand and measurement are kept visibly distinct, because an earlier draft that let the accent double as the carbs series colour made the two unreadable apart. Everything else is neutral surface and hairline structure, so the numbers — tabular, aligned, unmissable — are what the eye lands on.

Nourishly deliberately avoids the gamified fitness-app register: no streaks, badges, flame icons, confetti, or bright celebratory gradients. Progress is shown as a bar read against a target tick, not a meter filled to its own edge, and even that bar runs to 125% of target so going over has somewhere honest to go.

**Key Characteristics:**
- One accent hue (Ledger Indigo) does all interactive and brand work; it never doubles as a data colour.
- Four nutrient-series colours are fixed by role (protein, carbs, fat, fibre) and never reassigned or cycled.
- Status is read as a dot plus a label, never colour alone.
- Surfaces are flat and bordered at rest; shadow appears only on things that float above the page.
- One typeface (IBM Plex Sans) carries the whole hierarchy through weight and size, not a second face.
- Numbers are tabular and right-aligned wherever they appear in a column.

## Colors

The palette is cool and restrained: a single indigo accent against near-white/near-black neutrals, with four validated data-series hues reserved exclusively for nutrients and four status hues reserved exclusively for target state. Every colour ships in a light and a dark variant (see each entry); dark is not a filtered inversion of light, it's a separately tuned value.

### Primary
- **Ledger Indigo** (`#3b4d9e` light / `#8b99ea` dark): the single accent. Drives primary buttons, active nav/tab state, links, the focus ring, and selected states. Deliberately never reused as a data or status colour.

### Nutrient Series (data only — never used decoratively)
- **Terracotta Protein** (`#c1572d` light / `#d16536` dark)
- **Slate Blue Carbs** (`#1f6fa5` light / `#3f92cf` dark)
- **Ochre Fat** (`#c7961a` light / `#bb8a0c` dark)
- **Forest Fibre** (`#0f8a5e` light / `#2a9b6e` dark)

Series order is fixed — protein, carbs, fat, fibre — and hues are assigned by role, never by rank or reassigned per chart. All eight values (light + dark) pass the dataviz validator's six checks: lightness band, chroma floor, colour-blindness separation, normal-vision floor, and contrast against their own surface.

### Status (reserved — never a series colour)
- **Verdant OK** (`#2e7d4f` light / `#4aa873` dark): at or near target.
- **Amber Low** (`#a06d0c` light / `#d0a03a` dark): under target.
- **Violet High** (`#7a5ea8` light / `#a893d8` dark): over target — deliberately not red.
- **Slate Unknown** (`#7b8098` light / `#787e96` dark): no data for this nutrient.
- **Danger Red** (`#a52a1f` light / `#f0a49c` dark): reserved for destructive actions only (delete profile, discard, etc.) — never for "over target."

### Neutral
- **Cool Paper** (`#f2f3f8` light / `#0f1119` dark): app background.
- **Surface White** (`#ffffff` light / `#161927` dark): card and sheet surface.
- **Soft Surface** (`#e9ebf4` light / `#1e2233` dark): secondary surface (chips, key caps, nested rows).
- **Hairline** (`#d6d9e8` light / `#2b3045` dark): default border/divider.
- **Hairline Strong** (`#b9bed6` light / `#3b4160` dark): emphasised border (e.g. dashed "add custom" targets).
- **Ink** (`#161829` light / `#e9ebf6` dark): primary text.
- **Ink Secondary** (`#4b4f66` light / `#a8adc4` dark): secondary text, labels.
- **Ink Tertiary** (`#7b8098` light / `#787e96` dark): captions, timestamps, placeholder text.
- **Ink Disabled** (`#a3a7bb` light / `#5b6079` dark): disabled content.

### Named Rules
**The One Voice Rule.** The accent is never used for a data series, and no data series is ever used for a UI action. Brand and measurement stay visually distinct so a user can never mistake "the app is highlighting this" for "this is a nutrient reading."

**The No-Red-For-Over Rule.** Exceeding a target renders in Violet High, never red or orange. Red is reserved for destructive actions. A tracker that scolds gets abandoned; the palette is built so it structurally can't.

**The Never-Colour-Alone Rule.** Every status carries a small dot *and* a text label. No status is communicated by hue alone anywhere in the system.

## Typography

**Display Font:** IBM Plex Sans (with system-ui, -apple-system, 'Segoe UI', Roboto fallback)
**Label/Mono Font:** IBM Plex Mono (for tabular numerals and code-like values)

**Character:** One family carries the entire hierarchy. Weight and size do the differentiating work instead of a second display face, which keeps a number-dense screen calm instead of visually loud.

### Hierarchy
- **Display** (700, 30px, 1.12 line-height, -0.02em tracking): screen-level hero numbers and headline moments (e.g. onboarding).
- **Title** (700, 21px, 1.22, -0.015em): app-bar and section titles.
- **Heading** (600, 17px, 1.3, -0.01em): card and group headings.
- **Body Large** (400, 15px, 1.5): the base reading size for prose (e.g. lede copy, onboarding body).
- **Body** (400, 14px, 1.5): default UI text — list rows, form labels, most in-app copy.
- **Label** (600, 13px, 1.35): button labels, compact emphasis text.
- **Caption** (400, 12px, 1.4, 0.005em): secondary/meta text under a row.
- **Overline** (600, 11px, 1.3, 0.09em, uppercase): section eyebrows and group headers ("PREFERENCES", "YOUR DATA").
- **Numeral** (700, 28px, 1.0, -0.02em, tabular figures, IBM Plex Mono): the large ring/hero number on the dashboard and report screens.

### Named Rules
**The Tabular Figures Rule.** Any digits that align in a column — nutrient tables, report rows, stepper values — use tabular (monospace-width) numerals so the column stays straight regardless of digit shape.

## Layout

Spacing runs an 8-point-derived scale — `4 · 8 · 12 · 16 · 20 · 24 · 32 · 40 · 48` — used consistently for padding, gaps, and section rhythm; nothing sits off-scale. Screens are single-column and content-width (no multi-column grid inside the app itself — the multi-column comparison view exists only in the design-decisions prototype, not in the product).

Touch targets: primary controls are at least 48dp; compact list-row affordances no less than 44dp. This is an iOS/Android floor as much as a Nourishly one — see Do's and Don'ts.

App structure is a persistent bottom navigation (tab bar) plus a centred floating action button for "add," a sticky app bar carrying the screen title and at most one or two icon actions, and card-grouped content below. Modal tasks (add food, pick a target, edit a row) use bottom sheets that rise from the bottom edge, not full navigational pushes, when the task is self-contained.

## Elevation & Depth

Flat-at-rest, lifted-on-overlay. Cards, list rows, and the app bar carry no shadow at all — structure comes from a 1px hairline border and surface-colour contrast against the page background, not depth. Shadow is reserved for things that genuinely float above the content: the floating action button (el-2), and bottom sheets/dialogs (el-3, paired with a scrim behind them). A small el-1 shadow marks a draggable handle (e.g. a slider knob) that needs to read as "sitting on top of" its track.

### Shadow Vocabulary
- **el-1** (`0 1px 2px rgba(22,24,41,.06)` light / `0 1px 2px rgba(0,0,0,.5)` dark): minimal lift for a small interactive control resting on a track (e.g. a slider handle).
- **el-2** (`0 2px 4px rgba(22,24,41,.06), 0 8px 20px -12px rgba(22,24,41,.18)` light / `0 2px 4px rgba(0,0,0,.45), 0 8px 20px -12px rgba(0,0,0,.7)` dark): the floating action button.
- **el-3** (`0 8px 34px -14px rgba(22,24,41,.34)` light / `0 8px 34px -14px rgba(0,0,0,.8)` dark): bottom sheets and modal dialogs — anything presented over a scrim.

### Named Rules
**The Flat-By-Default Rule.** Surfaces are flat and bordered at rest. Shadow is earned only by floating above the page — a sheet, a dialog, a FAB — never applied to a resting card "for depth."

## Shapes

Corners run a fixed radius scale — `8 / 12 / 16 / 22 / pill (999)` — applied by role, not by component size: small controls and inputs use `sm`–`md` (8–12px), cards use `lg` (16px), bottom sheets use `xl` (22px, top corners only, flat bottom edge), and every button, chip, and status dot is a full pill. Borders are 1px hairlines throughout; there is no double-border or outset-bevel treatment anywhere in the system.

## Components

### Buttons
- **Shape:** full pill (`border-radius: 999px`), minimum height 46px, 12px/18px padding.
- **Primary:** Ledger Indigo background, white text — the single highest-emphasis action per screen.
- **Hover/Focus:** primary darkens to the accent-hover value; focus uses the same accent as a visible ring, never a colour-only change.
- **Soft:** accent-soft background (pale indigo tint) with accent-soft-ink text and a hairline border — the secondary-emphasis action next to a primary one.
- **Ghost:** transparent background, ink-secondary text — the lowest-emphasis / dismissive action (e.g. "Cancel" next to a primary "Save").
- **Small variant:** 32px min-height, 6px/14px padding, for inline or dense contexts (e.g. inside a card row).

### Chips
- **Style:** soft-surface background, ink-secondary text, hairline border, full pill.
- **Score/emphasis variant:** accent-soft background with accent-soft-ink text and no border, used for a chip carrying a computed value (e.g. a coverage or score chip) rather than a plain filter/tag.
- **State:** a `.stamp-on`-style filled-accent treatment marks the chosen/active option in a comparison or selector context.

### Cards / Containers
- **Corner style:** `lg` (16px).
- **Background:** surface-white (light) / surface (dark); no shadow.
- **Border:** 1px hairline.
- **Internal padding:** 12px/14px, with 10px gap between stacked cards.
- **Shadow strategy:** none at rest — see Elevation & Depth.

### Inputs / Fields
- **Style:** surface background, 1px hairline border, `md` radius (12px), 44–46px min-height.
- **Focus:** border shifts to the accent colour (no glow/halo).
- **Search fields** use the slightly denser soft-surface background instead of surface-white, to read as a tool embedded in the page rather than a card.

### Navigation
- **Bottom tab bar:** icon + 10px/600 label, ink-tertiary at rest, accent when active; a centred FAB (pill, accent background, el-2 shadow) sits mid-bar for the primary "add" action rather than occupying a tab slot.
- **App bar:** sticky, 16px/700 title with an optional 11.5px ink-tertiary subtitle beneath it; icon actions are borderless 30×30px tap targets.
- **List rows:** hairline divider between rows within a card, none after the last row; label + secondary meta on the left, a value and/or chevron on the right, the whole row (not just the chevron) is the tap target.

### Progress Bars (signature component)
The bar that drives the whole reporting surface. A track (fixed neutral fill) runs to **125% of target** rather than the bar's own 100% — the tick marking "target" sits at 80% of the track's width, so overshoot always has visible room to register instead of clipping or overflowing the container. The fill colour is the relevant nutrient's series colour (or a status colour, where the bar is reporting target-state rather than a raw nutrient). Never filled edge-to-edge at 100%; a bar that looks "full" at target is the one visual lie this system refuses to tell.

## Do's and Don'ts

### Do:
- **Do** use the accent (Ledger Indigo) for interactive and brand elements only — never for a nutrient series or a status.
- **Do** pair every status with a dot *and* a text label; never colour alone.
- **Do** run progress tracks to 125% of target with the tick at 80%, never fill a bar to its own 100% edge.
- **Do** render a nutrient with no data as an explicit "no data" state (em dash + explanation), never as zero.
- **Do** use tabular numerals for any digits that align in a column.
- **Do** keep touch targets at least 48dp for primary controls, 44dp minimum for compact list affordances.
- **Do** reserve shadow for things that float above the page (sheets, dialogs, the FAB); keep resting cards flat with a hairline border.

### Don't:
- **Don't** use red or orange for "over target." Over-target is Violet High; red is reserved for destructive actions only.
- **Don't** introduce gamification chrome — streaks, badges, flame icons, confetti, celebratory gradients. The system reads as an instrument, not a game.
- **Don't** reassign or cycle the four nutrient-series colours by rank; protein/carbs/fat/fibre keep their hue permanently.
- **Don't** add a second display typeface. Hierarchy comes from IBM Plex Sans's weight and size scale, not a companion face.
- **Don't** add a drop shadow to a resting card "for depth" — depth is reserved for overlays.
- **Don't** show energy as "consumed so far." The large number is what's remaining, not what's eaten.
