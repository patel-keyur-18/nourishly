# Part I — Product

*Sections 1–10 · [Back to index](./README.md)*

---

## 1. Executive Summary

Nourishly is a cross-platform (iOS + Android) personal nutrition and hydration tracker. Users log what they eat and drink; the app converts that into macronutrient and micronutrient totals, compares them against personalised targets, and returns a daily performance summary plus weekly and monthly trend reports.

The product problem is not "can we sum calories." Calorie summing is trivial. The three problems that actually decide whether this product succeeds are:

**(a) Logging friction.** Nutrition apps die on retention, not acquisition. A user who needs eight taps and a search that does not know what a *katori* of dal is will stop logging within a week. Every architectural decision that follows is weighted toward making the common case — "log a food I have eaten before" — reachable in three taps and under five seconds, online or offline.

**(b) Data honesty.** Micronutrient coverage in every available food database is sparse and uneven. An app that silently treats "no vitamin D value recorded for this food" as "zero vitamin D consumed" will tell users they are deficient in nutrients they are not, which is both wrong and, given the subject matter, harmful. Nourishly models *unknown* as a distinct state from *zero* throughout the pipeline, and refuses to score a nutrient whose evidence base for that day is too thin.

**(c) Trust in history.** If correcting a food's calorie count silently rewrites last month's reports, or if changing a weight-loss goal retroactively re-scores past days, the longitudinal reports — the actual differentiator over a paper notebook — become worthless. Nourishly snapshots nutrient values onto log entries and effective-dates targets so that history is immutable by construction.

### Recommended technical direction

*Confirmed across two reviews: Flutter (ADR-001), and — after the personal-use decision — **no backend at all** (ADR-006, revised twice). See [Part 0](./00-scope.md).*

| Concern | Recommendation | ADR |
|---|---|---|
| Client framework | **Flutter (Dart)** — decided | ADR-001 |
| Client architecture | Feature-first modular Clean Architecture; pure-Dart `nutrition_core` domain package; Riverpod for DI/state | ADR-002 |
| Local storage | SQLite via Drift, on-device source of truth | ADR-003 |
| Offline model | Offline-first; local write-through; UI never blocks on network | ADR-004 |
| Sync | **None.** UUID keys and tombstones retained only so export/import merges correctly | ADR-005 ⛔ |
| Backend | **None.** Local SQLite only; backup by platform auto-backup + file export | ADR-006 |
| Accounts | **None.** Local switchable profiles, one per family member (§0.4) | ADR-007 ⛔ |
| Food data | Owned, curated catalog from public-domain sources + **300–500 hand-curated household foods**; bundled with the build, rebuilt on demand | ADR-008 |
| Reporting | Materialised daily summaries; weekly/monthly aggregated on demand over those summaries | ADR-009 |
| Scoring | Transparent composite of capped, individually-visible sub-scores with explicit data-coverage gating | ADR-010 |

### In one line

An offline, self-built food and water tracker for one household — 2–3 local profiles, a catalog of the foods this family actually eats, recipes, personalised targets, and honest daily, weekly and monthly reports. No servers, no accounts, no distribution.

Estimated effort: **10–14 weeks full-time, or 5–7 months at 10–12 hours a week** ([§0.8](./00-scope.md#08-revised-effort-estimate)).

## 2. Product Vision

> **Nourishly helps a person understand whether they are eating well — not just how much they are eating — and does it with less effort than the notebook they would otherwise not keep.**

Three commitments follow from that sentence and constrain the design:

**Effort is the product.** The competitive axis is not feature count. It is the time between "I finished eating" and "it is logged." Features that add capability at the cost of the common-path tap count are rejected or moved behind a secondary surface.

**Insight over data.** A screen of 24 nutrient numbers is a spreadsheet, not a product. The app's job is to answer "was today good, and what would make tomorrow better" in one sentence, with the numbers available underneath for those who want them.

**Honesty over engagement.** The app will decline to give a score when it lacks the data to give a truthful one. It will not diagnose, will not label foods as good or bad, and will not use streak pressure or shame as engagement mechanics. Nutrition tracking sits adjacent to disordered-eating risk; the design treats that as a safety requirement, not a nicety (§27.14).

### Positioning

Nourishly is a **wellness and self-knowledge tool**, explicitly not a medical device, not a diagnostic system, and not a source of clinical advice. This positioning is a hard architectural boundary, not marketing copy: it determines what language the insight engine may generate (§21.7), what regulatory regime applies (§30), and what liability the product carries.

### What Nourishly is not

- Not a fitness/exercise tracker (integration, yes; ownership, no).
- Not a meal-delivery or recipe-commerce product.
- Not a coaching or dietician marketplace in v1.0 (Future, §10).
- Not a social network. No feeds, no comparison to other users.

---

## 3. Goals and Objectives

### 3.1 Product goals

| # | Goal | How you will know |
|---|---|---|
| PG-1 | Logging is effortless | A repeat food takes 3 taps and under 10 seconds. Measure it yourself with a stopwatch — you do not need analytics for four users |
| PG-2 | The habit sticks | Everyone who installed it is still logging a month later. If someone stops, **ask them why** — one conversation beats any dashboard |
| PG-3 | The numbers mean something | Family members can say what they should eat more of, without being shown a chart |
| PG-4 | The catalog knows this household's food | Nobody has to create a custom food more than about once a week after the first month |
| PG-5 | It works anywhere | Every function works in airplane mode. Testable, and non-negotiable |
| PG-6 | Data is never lost | Export → wipe → restore round-trips completely, verified before it goes on anyone's phone |

*Revised in rev 0.3. Retention percentages and funnel metrics are meaningless for four known people; direct observation is both cheaper and better. [ASSUMPTION A-1 retired.]*

### 3.2 Technical objectives

| # | Objective | Rationale |
|---|---|---|
| TO-1 | Every user-facing read and write is served from local storage | Offline-first is a correctness property, not a feature (§16) |
| TO-2 | Nutrition calculation lives in one pure-Dart package with golden test vectors | Consistency across platforms and across any future server-side recompute (§20.3) |
| TO-3 | Nutrients are rows, not columns, end to end | Adding vitamin B12 or selenium later must be a data change, never a schema migration (§22.4) |
| TO-4 | History is immutable by construction | Snapshotted nutrients + effective-dated targets (§20.4, §20.5) |
| TO-5 | The domain layer has zero dependency on Flutter, on the database, or on the network | Enables fast unit testing and a possible future non-Flutter client (§14) |
| TO-6 | Sync is additive, idempotent, and resumable | Partial sync must never corrupt state (§17) |
| TO-7 | Solo-developer operable | No component requires ops attention more often than weekly. With the backend live from launch (ADR-006 revised), this constraint tightens: managed services only, no bespoke infrastructure, and an incident posture that tolerates backend downtime because the client keeps working (§31.6) |

### 3.3 Explicit non-goals for v1.0

- Multi-user / family / household accounts.
- Server-side heavy analytics or machine learning.
- Server-side computation of nutrition totals, targets, scores, or reports — these stay on the device (AP-5).
- AI-assisted logging (photo or natural language) — deferred to v1.1 with its seams built in (§9.4).
- Web client.
- Real-time collaboration of any kind.
- Anything requiring regulatory clearance as a medical device.

---

## 4. User Problems Being Solved

| # | Problem | Evidence / reasoning | How Nourishly addresses it |
|---|---|---|---|
| P-1 | "Logging takes too long, so I stop." | The dominant churn reason in food-tracking apps. Every extra screen compounds across 4–6 logging events per day. | Recents-first search, meal templates, one-tap repeat, quick-add water chips (§27.5, §27.8) |
| P-2 | "The app doesn't know my food." | Global databases are built around Western supermarket items. "2 rotis and a katori of dal" has no clean entry in most of them. | Curated Indian food set with household measures as first-class servings (§19.4) |
| P-3 | "I don't know what the numbers mean." | Users see 1,800 kcal / 62 g protein and cannot judge it. | Personalised targets + plain-language daily verdict + capped sub-scores (§21) |
| P-4 | "I only find out I did badly after the day is over." | Retrospective-only feedback cannot change behaviour. | Live dashboard with remaining-budget framing; conditional reminders (§29) |
| P-5 | "I can't see whether I'm actually improving." | Single-day view gives no signal against day-to-day noise. | Weekly/monthly trends with moving averages and period-over-period comparison (§25) |
| P-6 | "I lose everything when I change phones." | Local-only apps punish device migration. | Optional account with cross-device sync and cloud backup at launch; full data export regardless (§30.6) |
| P-7 | "No signal at the restaurant / on the train." | Logging happens exactly where connectivity is worst. | Offline-first with bundled food catalog (§16) |
| P-8 | "I don't trust that the app isn't selling my health data." | Nutrition data is sensitive; users are increasingly aware. | Guest mode by default, no third-party analytics on health data, in-app export and deletion (§30) |
| P-9 | "It tells me I'm deficient in things I'm probably not." | Sparse micronutrient data misread as zeros. | Coverage-gated micronutrient reporting (§21.5) |

---

## 5. User Personas

*Revised framing for rev 0.3: these are no longer hypotheses to validate — **you know the actual users personally.** They remain useful as design lenses, because the four needs they represent are real and will each show up in your household: speed for the daily logger, precision for the goal-driven one, simplicity for someone who wants two numbers and no jargon, and water-only for someone with no interest in calories. Read them as a checklist of needs to serve, not as people to research. [ASSUMPTION A-2 retired.]*

### Persona 1 — Ananya, 29, Bengaluru — "The Consistency Seeker" *(primary)*
Software engineer, mostly vegetarian, eats a mix of home-cooked Indian food and office cafeteria meals. Goal: general health and "eating enough protein." Tracks in bursts, abandons when logging gets tedious.
- **Needs:** fast repeat logging; Indian foods with household measures; protein visibility; no judgement.
- **Frustrations:** searching "dal" returns twelve US lentil-soup entries; portion sizes in grams she cannot estimate.
- **Design implications:** recents/favourites ranked above global search; katori/roti/glass servings; protein prominent on the dashboard.
- **Devices:** mid-range Android (6 GB RAM), patchy office WiFi.

### Persona 2 — Rohit, 34, Pune — "The Goal-Driven Optimiser" *(primary)*
Lifts four days a week. Goal: muscle gain at a modest surplus. Wants macro precision and will tolerate more setup for more accuracy.
- **Needs:** custom foods and recipes for his repeated meals; accurate macro targets; weekly adherence trend.
- **Frustrations:** apps that hide macros behind a paywall; being unable to save "post-workout meal" as one entry.
- **Design implications:** meal templates and recipes as launch features, not niceties; per-gram entry; target overrides.
- **Devices:** iPhone, good connectivity.

### Persona 3 — Meera, 46, Ahmedabad — "The Health-Nudged Adult" *(secondary)*
Told by her doctor to watch sodium and increase fibre. Not a quantified-self person. Low tolerance for complexity.
- **Needs:** simple red/amber/green feedback on two or three things she cares about; water reminders; large type.
- **Frustrations:** dashboards full of numbers; jargon.
- **Design implications:** a "focus nutrients" preference that promotes 2–3 nutrients to the dashboard; strong accessibility defaults; plain-language insights.
- **Risk this persona surfaces:** she is one step from expecting medical guidance. The insight engine's language boundary (§21.7) exists largely for her.

### Persona 4 — Kabir, 22, Delhi — "The Hydration-Only User" *(secondary)*
Wants to drink more water. Has no interest in calories.
- **Needs:** water logging in one tap from a widget or the dashboard; a hydration-only mode.
- **Design implications:** water tracking must be independently useful and not gated behind food logging or profile setup. Onboarding must permit "I only want water" (§27.1).

### Anti-persona — the clinical user
Someone managing a diagnosed condition (CKD, T1 diabetes, pregnancy complications) who expects Nourishly to be a clinical tool. **Explicitly out of scope.** The app must not present itself as adequate for this, and its disclaimers and insight language are calibrated accordingly (§30.8).

---

## 6. Core User Journeys

### J-1 — First run to first log *(the single most important journey)*

```mermaid
flowchart TD
    A[App launch, cold] --> B[Value screens, 2 cards, skippable]
    B --> C{Set up profile now?}
    C -->|Skip| D[Anonymous local profile, generic default targets]
    C -->|Yes| E[Age, sex, height, weight, activity, goal]
    E --> F[Derived targets shown with a plain explanation]
    F --> G[Dashboard, empty state]
    D --> G
    G --> H[Tap Log, meal auto-selected by time of day]
    H --> I[Search or pick from curated starter list]
    I --> J[Serving and quantity, sensible defaults pre-filled]
    J --> K[Save]
    K --> L[Dashboard updates, rings animate]
    L --> M[First-log affirmation, no account required]
```

**Design constraints on J-1**
- No account, no email, no permission prompt before the first log. Guest mode is the default path (ADR-007).
- Profile setup is skippable; skipping yields generic targets with a visible "personalise for accurate targets" affordance, not a blocked app.
- Target: **under 90 seconds from install to first logged item.**
- Notification permission is requested only at the moment a reminder is first configured, never at launch.

### J-2 — Daily repeat logging *(the highest-frequency journey)*

```mermaid
flowchart LR
    A[Dashboard] --> B[Tap plus]
    B --> C[Meal slot inferred from clock]
    C --> D[Recents and favourites, no typing]
    D --> E{Found it?}
    E -->|Yes| F[Tap item, last-used serving pre-filled]
    E -->|No| G[Type to search catalog]
    G --> F
    F --> H[Save]
    H --> A
```

**Target: 3 taps, under 5 seconds, fully offline.** This is the number the architecture is optimised for. The consequences: the food catalog must be on-device (§19.5), recents must be a local indexed query, and the last-used serving per food must be persisted per user.

### J-3 — Water logging
Dashboard exposes 2–3 quick-add chips sized from the user's preference (e.g. 250 ml glass, 500 ml bottle, 1 L). One tap logs and animates. Long-press opens a custom amount. A mis-tap is undoable via an inline undo for 5 seconds — critical, because one-tap actions produce one-tap mistakes.

### J-4 — End-of-day review
Triggered by an optional evening notification or by opening the app. Presents, in order: a one-sentence verdict, the score with its components, what went well, what fell short, and the meal breakdown. The verdict comes first because most users will read only that.

### J-5 — Weekly reflection
A weekly report becomes available on the user's chosen week-start day. Shows averages, day-by-day adherence, best day, most-frequently-missed nutrient, and consistency. Explicitly compares to the prior week only when the prior week has enough logged days to make the comparison meaningful (§25.6).

### J-6 — Guest to account migration
The user has 40 days of local data and taps "Back up my data." They sign in with Apple/Google/email; local records are uploaded; a success state confirms the count. If the chosen identity already has server data, the merge path in §18.5 applies. **This journey must be lossless and interruptible** — it is the highest-consequence flow in the product.

### J-7 — Correcting a mistake
Tap an entry in the daily breakdown → edit quantity/serving/meal, or delete. Deletions are soft (tombstoned) and undoable for the session. Editing recomputes the daily summary and score immediately.

### J-8 — Creating a custom food
Search fails → "Create custom food" is offered inline at the bottom of results with the typed query pre-filled as the name. Minimum viable entry is name + serving + calories; macros and micros are optional and clearly marked as affecting report completeness. The friction here must be low, because the alternative is the user abandoning the log entirely.

---

## 7. Functional Requirements

Priority key: **1** = v1.0 must-have · **S** = v1.0 should-have · **1.1** = first post-launch release · **F** = future.

*Revised after the review decision to ship the complete application (§9). Requirements previously deferred to Post-MVP — accounts, sync, barcode, reminders, recipes, health integration, monthly reports, Hindi — are now v1.0.*

### 7.1 User & Profile Management

| ID | Requirement | Pri |
|---|---|---|
| FR-U-01 | Use the app fully in guest mode with no account | 1 |
| FR-U-02 | Create/edit profile: date of birth (or age), biological sex, height, weight, activity level | 1 |
| FR-U-03 | Select a primary goal: general health, weight maintenance, weight loss, weight gain, muscle gain, improved hydration, nutrition consistency | 1 |
| FR-U-04 | System derives daily targets (energy, macros, water, micros) from profile + goal, with the derivation explained in plain language | 1 |
| FR-U-05 | Manually override any derived target; overrides are marked as user-set and survive profile changes until reset | 1 |
| FR-U-06 | Profile changes take effect from the change date forward and do not alter historical targets or scores | 1 |
| FR-U-07 | Set unit preferences: metric/imperial, ml/L/fl oz, kg/lb, cm/ft-in | 1 |
| FR-U-08 | Set week start day (Sun/Mon) and daily rollover time | 1 |
| FR-U-09 | Choose up to 3 "focus nutrients" promoted onto the dashboard | 1 |
| FR-U-10 | Create an account (Apple / Google / email OTP) and migrate guest data | 1 |
| FR-U-11 | Sign out; local data behaviour on sign-out is explicit and confirmed by the user | 1 |
| FR-U-12 | Delete account and all server data from within the app | 1 |
| FR-U-13 | Export all personal data (JSON + CSV) | 1 |
| FR-U-14 | Record body weight over time as a series | 1 |
| FR-U-15 | Set a "reason for tracking" that tunes which insights are surfaced | F |
| FR-U-16 | Record an optional dietary preference (vegetarian, vegan, eggetarian, Jain, halal, none) that improves search ranking and insight suggestions; skippable, and framed as sensitive data (§30.1) | 1 |

### 7.2 Food Catalog & Food Management

| ID | Requirement | Pri |
|---|---|---|
| FR-F-01 | Search the catalog by name with fuzzy/prefix matching, fully offline | 1 |
| FR-F-02 | Search results rank recents and favourites above general catalog matches | 1 |
| FR-F-03 | View a food's detail: nutrients per serving and per 100 g, available servings, data provenance and quality tier | 1 |
| FR-F-04 | Filter/scope search (e.g. Indian foods, my foods) | 1 |
| FR-F-05 | Create a custom food with name, servings, and nutrients; only name + one serving + energy are mandatory | 1 |
| FR-F-06 | Edit and delete custom foods; deleting a food already logged does not alter past entries | 1 |
| FR-F-07 | Mark/unmark any food as a favourite | 1 |
| FR-F-08 | Recently logged foods list, ordered by recency and frequency | 1 |
| FR-F-09 | Each food carries one or more named servings with a gram/ml weight (including household measures: katori, roti, glass, cup, tbsp, piece) | 1 |
| FR-F-10 | Log by direct weight/volume as an alternative to a named serving | 1 |
| FR-F-11 | Catalog updates delivered incrementally without an app-store release | 1 |
| FR-F-12 | Report a data error on a catalog food | S |
| FR-F-13 | Barcode scan to resolve a packaged food | 1 |
| FR-F-14 | Create a recipe from ingredients; nutrients computed per portion, with cooking yield factor | 1 |
| FR-F-15 | Duplicate detection when creating a custom food that closely matches a catalog food | S |

### 7.3 Meal Logging

| ID | Requirement | Pri |
|---|---|---|
| FR-M-01 | Log a food to a meal slot: breakfast, lunch, dinner, snack | 1 |
| FR-M-02 | Meal slot pre-selected based on time of day and the user's own historical pattern | S |
| FR-M-03 | Set quantity as a multiplier of a chosen serving (supports fractional values) | 1 |
| FR-M-04 | Log to any date, not just today (back-fill) | 1 |
| FR-M-05 | Edit or delete a log entry | 1 |
| FR-M-06 | Move an entry between meal slots | 1 |
| FR-M-07 | Copy a meal, a day, or a set of entries to another date | 1 |
| FR-M-08 | Save a set of entries as a named meal template ("My breakfast") | 1 |
| FR-M-09 | Log a meal template in one action | 1 |
| FR-M-10 | Edit and delete meal templates | 1 |
| FR-M-11 | Define custom meal categories beyond the default four | 1 |
| FR-M-12 | Attach an optional note or photo to an entry | S |
| FR-M-13 | Log a meal by natural-language description | 1.1 |
| FR-M-14 | Log a meal from a photo | 1.1 |

### 7.4 Water & Hydration

| ID | Requirement | Pri |
|---|---|---|
| FR-W-01 | Log water with one tap from configurable quick-add amounts | 1 |
| FR-W-02 | Log a custom amount | 1 |
| FR-W-03 | Configure quick-add amounts and the display unit (ml / L / fl oz) | 1 |
| FR-W-04 | Daily water target derived from profile, manually overridable | 1 |
| FR-W-05 | Live daily hydration progress on the dashboard | 1 |
| FR-W-06 | Undo a water log immediately after logging | 1 |
| FR-W-07 | Edit/delete any past water entry | 1 |
| FR-W-08 | Historical water view (day / week / month) | 1 |
| FR-W-09 | Beverages other than water (tea, coffee, juice, milk) contribute both their nutrients and a configurable hydration fraction | 1 |
| FR-W-10 | Water reminders on a schedule or after inactivity | 1 |
| FR-W-11 | Home-screen widget / watch complication for one-tap water | 1.1 |

### 7.5 Nutrition Tracking

| ID | Requirement | Pri |
|---|---|---|
| FR-N-01 | Compute daily totals for every tracked nutrient from all entries | 1 |
| FR-N-02 | Track macros: energy, protein, carbohydrate, fat, fibre | 1 |
| FR-N-03 | Track macro sub-components: saturated fat, added/total sugar | 1 |
| FR-N-04 | Track micros: vitamins A, B1, B2, B3, B6, B9, B12, C, D, E, K; calcium, iron, magnesium, potassium, sodium, zinc | M (data-permitting, §21.5) |
| FR-N-05 | Support adding new nutrients without a schema change or app release | 1 |
| FR-N-06 | Distinguish *unknown* from *zero* for every nutrient value, everywhere | 1 |
| FR-N-07 | Show, per nutrient, the % of the day's energy covered by foods that actually report it | 1 |
| FR-N-08 | Compare every tracked nutrient against that day's effective target | 1 |
| FR-N-09 | Classify each nutrient as below / within / above target, using target-type-appropriate bands | 1 |
| FR-N-10 | Per-meal nutrient subtotals | 1 |
| FR-N-11 | Nutrient contributions attributed to individual foods ("what gave me most of my sodium") | 1 |

### 7.6 Daily Report & Performance

| ID | Requirement | Pri |
|---|---|---|
| FR-D-01 | Daily summary: energy, macros, micros, water, all against targets | 1 |
| FR-D-02 | Daily Nourishment Score (0–100) with all sub-scores individually visible | 1 |
| FR-D-03 | Every score is explainable: tapping it shows exactly what contributed | 1 |
| FR-D-04 | Score is withheld, with a stated reason, when data coverage or day completeness is insufficient | 1 |
| FR-D-05 | List nutrients below target ("gaps") | 1 |
| FR-D-06 | List nutrients above the upper limit ("excesses") | 1 |
| FR-D-07 | 2–4 plain-language insights per day, drawn from a reviewed rule set | 1 |
| FR-D-08 | Meal-by-meal breakdown with each meal's energy and macro share | 1 |
| FR-D-09 | Goal completion percentages per target | 1 |
| FR-D-10 | Share/export a daily summary | S |
| FR-D-11 | Insights suggest concrete, food-level next actions | 1 |

### 7.7 Weekly Report

| ID | Requirement | Pri |
|---|---|---|
| FR-WK-01 | Daily averages for energy, macros, water, score over the week | 1 |
| FR-WK-02 | Count of days each target was met | 1 |
| FR-WK-03 | Score trend across the seven days | 1 |
| FR-WK-04 | Best day and weakest day, with the reason | 1 |
| FR-WK-05 | Most frequently missed and most frequently exceeded nutrients | 1 |
| FR-WK-06 | Logging consistency (days logged, meals logged per day) shown alongside every average, so averages are never read without their denominator | 1 |
| FR-WK-07 | Comparison to previous week, shown only when both weeks are sufficiently logged | 1 |
| FR-WK-08 | Weekday vs weekend pattern analysis | S |
| FR-WK-09 | Weekly report export/share | S |

### 7.8 Monthly Report

| ID | Requirement | Pri |
|---|---|---|
| FR-MO-01 | Monthly averages for all headline metrics | 1 |
| FR-MO-02 | Month-long trend charts with a moving average | 1 |
| FR-MO-03 | Goal consistency: % of days targets were met | 1 |
| FR-MO-04 | Chronically deficient and chronically exceeded nutrients | 1 |
| FR-MO-05 | Comparison against the previous month | 1 |
| FR-MO-06 | Calendar heat-map of daily scores | S |
| FR-MO-07 | Correlation between logging consistency and score | F |

### 7.9 Platform, Sync & System

| ID | Requirement | Pri |
|---|---|---|
| FR-S-01 | All logging, viewing, and reporting functions work with no network | 1 |
| FR-S-02 | Data survives app restart, OS update, and app update | 1 |
| FR-S-03 | Local data export produces a complete, re-importable archive | 1 |
| FR-S-04 | Background sync when signed in and connected | 1 |
| FR-S-05 | Sync status is visible and its failures are actionable, never silent | 1 |
| FR-S-06 | Multi-device consistency for a signed-in user | 1 |
| FR-S-07 | Local notifications for reminders and the end-of-day summary | 1 |
| FR-S-08 | Apple Health / Health Connect read-write | 1 |
| FR-S-09 | Full dark mode and dynamic type support | 1 |
| FR-S-10 | Screen-reader accessible across all primary flows | 1 |
| FR-S-11 | Full English and Hindi localisation; language follows the OS setting and is overridable | 1 |
| FR-S-12 | Sync conflicts are resolved without user intervention; the losing version is retained locally for diagnostics | 1 |
| FR-S-13 | Catalog delta updates applied in the background on unmetered connections, without an app-store release | 1 |

---

## 8. Non-Functional Requirements

### 8.1 Performance

| ID | Requirement | Target |
|---|---|---|
| NFR-P-01 | Cold start to interactive dashboard | p95 < 2.0 s on a 2022 mid-range Android |
| NFR-P-02 | Warm start to dashboard | p95 < 600 ms |
| NFR-P-03 | Food search keystroke-to-results | p95 < 120 ms for a 30k-item local catalog |
| NFR-P-04 | Save a log entry, dashboard reflects it | p95 < 200 ms |
| NFR-P-05 | Daily summary recompute after an edit | p95 < 100 ms |
| NFR-P-06 | Weekly report render (from materialised dailies) | p95 < 400 ms |
| NFR-P-07 | Monthly report render | p95 < 800 ms |
| NFR-P-08 | Scroll performance on all list and chart screens | ≥ 58 fps median, no frame > 32 ms at p99 |
| NFR-P-09 | Installed app size | < 60 MB Android download, < 80 MB iOS |

*Rationale for NFR-P-03: search is typed character by character; anything above ~150 ms feels laggy and users stop trusting the results. This is the requirement that forces a local FTS index rather than remote search (§19.5).*

### 8.2 Reliability & Data Integrity

| ID | Requirement |
|---|---|
| NFR-R-01 | Crash-free session rate ≥ 99.5%; crash-free user rate ≥ 99.0% |
| NFR-R-02 | Zero data loss from app crash, force-quit, or OS kill mid-write — every write is a committed transaction before the UI acknowledges it |
| NFR-R-03 | Every schema migration is forward-tested on a populated database; a failed migration must fall back to a preserved copy, never wipe |
| NFR-R-04 | Sync is idempotent: replaying any request produces no duplicates and no divergence |
| NFR-R-05 | Sync is resumable: interruption at any point leaves both sides in a consistent, retryable state |
| NFR-R-06 | Aggregates are always derivable from source records; a corrupted summary can be rebuilt by recomputation |
| NFR-R-07 | Nutrient arithmetic is deterministic and reproducible from the entry snapshot alone |
| NFR-R-08 | Automatic local backup snapshot retained across app updates |

### 8.3 Offline

| ID | Requirement |
|---|---|
| NFR-O-01 | 100% of core functionality — logging, viewing, reporting, target management — available offline, indefinitely, with no degradation notice. Only sign-in, sync, barcode lookup of unknown products, catalog delta download, and health-platform exchange may require connectivity, and each degrades to an always-available manual path |
| NFR-O-02 | The app never shows a network error for a logging action |
| NFR-O-03 | Offline-created records are indistinguishable from online ones once synced |
| NFR-O-04 | Outbox survives process death and device restart |
| NFR-O-05 | A device offline for 90+ days syncs successfully on reconnect without manual intervention |

### 8.4 Security & Privacy

| ID | Requirement |
|---|---|
| NFR-S-01 | All network traffic over TLS 1.2+; certificate validation never disabled |
| NFR-S-02 | Tokens stored in iOS Keychain / Android Keystore-backed EncryptedSharedPreferences, never in plain preferences or the app database |
| NFR-S-03 | Local database protected by OS full-disk encryption; database-level encryption (SQLCipher) available as a user-enabled option (§30.3) |
| NFR-S-04 | Server-side row-level isolation enforced at the database, not only in application code |
| NFR-S-05 | No health or nutrition data transmitted to any third-party analytics or advertising SDK |
| NFR-S-06 | Account deletion removes all server-side personal data within 30 days, with logs retained no longer than necessary |
| NFR-S-07 | Data export is user-initiated, complete, and machine-readable |
| NFR-S-08 | No PII in crash reports or logs; log redaction verified by test |
| NFR-S-09 | All third-party SDKs reviewed for data collection before inclusion; each one's justification recorded |

### 8.5 Usability & Accessibility

| ID | Requirement |
|---|---|
| NFR-A-01 | WCAG 2.2 AA contrast for all text and meaningful UI |
| NFR-A-02 | Full VoiceOver/TalkBack support on every primary flow; charts expose a text alternative conveying the same conclusion |
| NFR-A-03 | Dynamic type / font scaling to 200% without layout breakage or truncation of essential content |
| NFR-A-04 | No information conveyed by colour alone — every status carries a label, icon, or shape |
| NFR-A-05 | Primary touch targets ≥ 48 dp |
| NFR-A-06 | Reduced-motion setting respected |
| NFR-A-07 | Common path (repeat food log) ≤ 3 taps |
| NFR-A-08 | All destructive actions confirmable or undoable |

### 8.6 Maintainability

| ID | Requirement |
|---|---|
| NFR-M-01 | Domain and calculation logic ≥ 90% line coverage; the scoring engine has an explicit golden-vector suite |
| NFR-M-02 | Domain layer imports nothing from Flutter, the database, or the network layer — enforced by an import lint rule in CI |
| NFR-M-03 | Feature modules depend on shared modules, never on each other |
| NFR-M-04 | Every architecturally significant decision has an ADR |
| NFR-M-05 | Nutrient set, target rules, scoring weights, and insight rules are data/configuration, not hard-coded branches |
| NFR-M-06 | CI runs analyse, format check, unit tests, and golden tests on every push |

### 8.7 Efficiency & Resource Use

| ID | Requirement |
|---|---|
| NFR-E-01 | Foreground battery use comparable to a text-and-list app; no continuous sensors, no location, no background polling |
| NFR-E-02 | Sync runs opportunistically on OS-scheduled background windows and on foreground resume; never on a timer |
| NFR-E-03 | Catalog delta updates on unmetered connections by default, user-overridable |
| NFR-E-04 | Local storage after two years of daily logging < 150 MB excluding photos |
| NFR-E-05 | No wake locks; no foreground services on Android for core functionality |

### 8.8 Scalability

Only one of these survives the personal-use scope, and it is the one that matters:

| ID | Requirement |
|---|---|
| NFR-SC-01 | **Client performance must not degrade with history size** — every report query is bounded by period length, not by total history. A user with five years of data has the same experience as one with five days |
| ~~NFR-SC-02~~ | ~~Backend supports 100k users~~ — retired, no backend |
| ~~NFR-SC-03~~ | ~~500k server-side catalog~~ — retired; the on-device catalog is the whole catalog |
| ~~NFR-SC-04~~ | ~~Cost per MAU~~ — retired, no infrastructure |

NFR-SC-01 is not a growth concern here but a longevity one: this app is meant to be used for years by the same few people, so the query shapes in §25.4 are what keep it fast in year five.

---

## 9. Scope

> **Superseded by [Part 0 — Personal-Use Scope](./00-scope.md).** Revision 0.3 narrowed the product to a private household app for 2–3 family members with no distribution, no backend, and no accounts. §0.3 carries the authoritative scope table.

### 9.1 Summary of what is built

| Area | Included |
|---|---|
| Logging | Food search, recents, favourites, custom foods, meal templates, four meal slots plus custom categories, serving + quantity, back-dating, copy meal/day, edit/delete |
| Recipes | Multi-ingredient household recipes with cooking yield |
| Water | Quick-add chips, custom amounts, unit preference, derived target, undo, history, beverage hydration |
| Nutrition | 5 macros + saturated fat + sugar + 17 micronutrients where data exists; unknown ≠ zero; coverage; per-meal subtotals |
| Targets | Derived per profile; manual overrides; effective-dated; **manual-targets-only mode** for anyone whose defaults would be wrong (§0.7) |
| Reports | Daily dashboard, daily report with score and insights, weekly report, monthly report |
| Profiles | 2–4 local switchable profiles, fully separate data (§0.4) |
| Backup | Manual JSON/CSV export and import; Android Auto Backup configuration (§0.5) |
| Catalog | Bundled: ~5–8k USDA generic items + ~365 curated regional foods ([specification](../catalog/README.md)) |
| Reminders | Local notifications — water, meal, end-of-day summary |
| Platform | **Android and iOS both supported.** Android self-signed and permanent; iOS via AltStore on the home Mac (§0.2) |

### 9.2 Not built

Backend, API, accounts, sign-in, synchronisation, compliance programme, store distribution, analytics and crash-reporting SDKs, scalability work. Barcode scanning, health-platform integration, Hindi, and AI logging are **deferred pending real use**, not rejected. Full reasoning in §0.3.

### 9.3 The scope bet

The bet is unchanged in kind but much easier to win at this size: **a fast, offline logger that knows the food this household actually eats, with honest daily and weekly feedback, is worth more than a feature-complete tracker with a mediocre food database.**

What changed is that the catalog — previously the largest risk in the plan — is now bounded by something knowable: **the foods your family eats.** You can write that list in an evening (§37 step 6), and it is a far better specification than any amount of market research would have produced.

## 10. Future Scope

> Scope classification now lives in [§0.3](./00-scope.md#03-revised-scope). This section records what the architecture stays *ready* for, so that nothing built now forecloses a later change of mind.

### 10.1 Deferred, pending real use

Each is genuinely optional. Decide after a few months of actual logging — the household's own usage is better evidence than any prediction here.

| Feature | Seam that already exists | Reconsider when |
|---|---|---|
| **Barcode scanning** | `FoodExternalRef` keyed by (source, external_id) — a GTIN is just another external reference, requiring no new entity | Logging shows meaningful packaged-food intake |
| **Health Connect** (Android) | `HealthDataPort` with per-direction consent | You want weight or activity flowing in automatically |
| **Hindi** | All strings externalised from the first commit; no concatenated sentences | A family member asks |
| **Water widget / watch** | Water quick-add is an independent, idempotent, offline write | One-tap water proves the most-used action |
| **AI-assisted logging** | `MealParser` port feeding the existing *propose → confirm → write* flow, so nothing is ever written unreviewed | You decide it is worth the cost and the offline compromise (Q-24) |
| **Multi-device sync** | UUIDv7 keys, `updated_at`, tombstones — retained precisely for import-merge (§0.4) | Only if the scope genuinely widens. ADR-006 documents what it would take |

### 10.2 The one seam worth keeping despite having no feature

`MealParser` is defined even though nothing implements it. Its value is not the future feature — it is that defining it forces the v1.0 logging flow into a *propose → confirm → write* shape. That shape can safely accept generated candidates later; a direct-write flow cannot, and retrofitting it is where AI logging features usually go wrong. The port costs one file.

### 10.3 Deliberately rejected, permanently

| Idea | Why |
|---|---|
| Social features, sharing, comparison between family members | Conflicts with the safety posture in §21.8, and comparing family members' eating is a bad idea in a way that has nothing to do with software |
| Gamified streaks with loss framing | Drives dishonest logging, which corrupts the data the reports depend on |
| Automatic "healthy / unhealthy" food labels | Not defensible per-food; contradicts §2 |
| Ads, data monetisation, third-party analytics | Not a product, and no data should leave the device at all |
| A server-authoritative logging model | Would break offline-first, which turned out to be the decision that let the scope collapse this far without a redesign |

*Continue to [Part II — Technology Selection](./02-technology.md).*
