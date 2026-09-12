# UX revision — eight fixes

*Planned 2026-09-12 · branch `feature/app-ux-improvements` · [Design index](./README.md) · [Decisions](./decisions.md) · [§27–28](../architecture/08-ux.md)*

Eight reported problems. Six are defects, two are design work. They are
sequenced so that the shared pieces land first and every later fix simply
uses them, rather than each screen inventing its own dialog, its own
message bar and its own row.

## The eight, and what is actually wrong

| # | Report | Root cause | Fix |
|---|---|---|---|
| 1 | Add food will not close; app becomes unnavigable | `MealsCard` opens the logging flow with `context.go('/log')` (`dashboard_cards.dart`). `go` **replaces** the stack, so `/log` sits alone over an empty history: `context.pop()` has nothing to pop, the shell and its nav bar are gone, and the only way out is to kill the app | `push`, everywhere a detail screen is opened; a `canPop()` fallback on every close affordance so no screen can ever become a trap |
| 2 | No swipe back | Android's default `ZoomPageTransitionsBuilder` carries no back-gesture detector | `pageTransitionsTheme` → `CupertinoPageTransitionsBuilder` on both platforms, which brings `_CupertinoBackGestureDetector` with it |
| 3 | New recipe → add ingredients overflows | `_IngredientPicker` is a fixed `0.7 × screenHeight` box **plus** the keyboard inset; with the field autofocused, 0.7 H + ~340 px keyboard exceeds the screen | Size the sheet from the space actually available, scroll the rest |
| 4 | Settings is not the approved design | The screen grew feature-first: five ad-hoc groups, an inline title instead of the prototype's app bar, body-weight history sitting in the middle of it | Redraw as prototype 13A — grouped list, three groups, value-plus-chevron rows, centred fine print |
| 5 | Profile and Settings are one screen | Everything landed on the Profile tab's root | Split: a real Profile screen (details, body, activity, diet, goal) pushed from Settings. Recipes stay in Settings |
| 6 | Editing one field throws me into onboarding | "Body and activity" routes to `/profile/setup` — the six-step wizard, which also starts from hardcoded defaults (1992 / 174 cm / 71 kg) rather than the saved profile, so it can silently overwrite real values | Per-field editors that write one field and return. The wizard stays for first run only, and prefills from the saved profile when there is one |
| 7 | Dialogs need redesign and one pattern | Nine `AlertDialog`s and three bottom sheets, each built by hand | One `NourishlyDialog` family in `nourishly_ui`; every call site moves onto it |
| 8 | Message bars never go away | No call site sets a duration, nothing clears the previous message, and a snackbar carrying an action is held open indefinitely by Flutter when accessible navigation is on | One `showNourishlySnack` helper: 5 s, one at a time, always manually dismissible, with a watchdog that removes it even when Flutter's own timer is suppressed |

## Order of work

**A. Foundation — `packages/nourishly_ui`.** Nothing user-visible on its own; items 3–8 all consume it.

1. `NourishlyDialog` + `showNourishlyConfirm`, `showNourishlyPrompt`, `showNourishlyOptions` — one structure (optional icon, title, supporting text, content slot, actions), a `danger` variant for the one destructive action, scrollable content so it survives 200 % text, `useSafeArea`, and a real barrier label.
2. `showNourishlySnack` — explicit 5 s, `clearSnackBars()` first so they never queue, close icon, swipe-to-dismiss, and a watchdog that calls `removeCurrentSnackBar()` if the message is somehow still up.
3. `NourishlyListRow` and `NourishlyAvatar` — the prototype's `.lr` / `.av`: title, optional sub, right-hand value, chevron, plus `accent`, `danger` and switch variants. This is what makes 4 and 5 a layout exercise rather than 400 lines of bespoke rows.
4. Theme: page transitions (item 2), dialog and snackbar theming for the above.

**B. Navigation correctness (1, 2).** `go` → `push` for every pushed detail screen; `canPop()` fallbacks; `/log` keeps its modal presentation and gains a `meal` parameter, so "Add breakfast" from the dashboard arrives with breakfast already selected instead of asking again.

**C. Profile screen (5) and focused edits (6).** New `/profile/me`. A `ProfileEditor` that reads the current profile and goal, changes one field, and re-saves through `saveProfileAndDeriveTargets` — so effective dating (I-3) and the carry-over of user overrides (FR-U-05) keep working exactly as they do today. The wizard is reduced to what it is for: first run.

**D. Settings redraw (4).** Prototype 13A's three groups. Weight history moves to Profile. Recipes stay. The two existing documented departures (no profile switcher, an Appearance row) are kept and re-stated in `decisions.md`, joined by a third for the profile split.

**E. Recipe ingredient picker (3).** Available-height sizing, drag handle, safe area, scrollable results, ellipsised long names, and the grams step on the new dialog.

**F. Sweep (7, 8).** All twelve dialog and snackbar call sites moved onto the helpers.

**G. Accessibility pass.** Semantic labels on icon-only controls, 48 dp targets on every new row, `Semantics` values on rows that read as "label, value", announced messages, and a 200 %-text check on everything new.

**H. Tests and docs.** Widget tests for: the meal row pushing and popping back; a message bar that is gone after five seconds; editing weight without leaving Profile; Settings' structure. `decisions.md` updated.

## Known constraint

This session has no Flutter or Dart toolchain, so `flutter analyze` and
`flutter test` cannot be run here. The work is kept to the idioms already
in the codebase and the tests are written alongside it, but the suite must
be run on a machine that has the SDK before this is merged.
