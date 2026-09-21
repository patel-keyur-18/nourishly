# Plan — Supplements and prescribed medicines

*Draft 0.1 · 2026-09-21 · **proposed** · branch `claude/prenatal-medicines-supplements-dy2nas` · [Scope](../architecture/00-scope.md) · [Data model](../architecture/06-data-model.md)*

The app already knows a profile can be pregnant: a due date on `user_profile_versions`, a lifestage that advances itself across trimesters (`lifestageOn`, `advanceLifestageIfDue`), and ICMR-NIN pregnancy RDAs for iron, folate and B12 in `app/assets/reference/rda_icmr_nin_2020.json`. What it does not know is that somebody is *taking a tablet for exactly those nutrients* — and it says so, in two places, in its own words:

> Supplements cannot be logged yet, so iron and folate may read lower here than what you are actually taking in.
> — `profile_screen.dart:742`, `goals_screen.dart:581`

That sentence is the whole justification for this work. A pregnant profile on a 60 mg iron tablet sees an iron bar at 40% of a 27 mg target and a folate bar that is wrong by a factor of ten. Under the honesty principle ([PRODUCT.md](../../PRODUCT.md), principle 1) an unlogged tablet is not a missing convenience, it is a **number the app is currently getting wrong for the one profile that can least afford it**.

---

## 0. The stance, before any schema

Six rules. Everything below follows from them, and §10's open questions are the ones these rules do not settle.

1. **The app records; it never prescribes.** No screen suggests a supplement, a dose, or a change to one. The user types in what is on the strip and what the doctor said. There is no "recommended for you" anywhere in this feature, ever.
2. **A picker is not advice.** We ship a reference pack of common products so nobody hand-types "Ferrous ascorbate 100 mg + folic acid 1.1 mg" twice. Its doses are *typical label strengths for recognition*, pre-filled and fully editable, never a recommendation. The user's entered dose always wins over the pack's default.
3. **Supplements are transcribed, and that is declared.** This is the one place the "derive, don't transcribe" principle (PRODUCT.md, principle 2) does not hold: a tablet's content comes off its label, not out of USDA FoodData Central. So every supplement-sourced nutrient value carries `provenance = 'label'` and is visibly separable from food-derived intake for the life of the row. The principle is not quietly broken; it is explicitly excepted, in one bounded place, with the exception recorded in the data.
4. **Supplements and medicines are different things.** A supplement contributes nutrients we track (iron, folate, calcium, D). A medicine — levothyroxine, doxylamine, metformin, aspirin — contributes none, and pretending otherwise would be inventing nutrition. Both are worth *remembering to take*, so both get logging and reminders; only supplements touch the nutrient totals.
5. **A prescribed dose is never scolded.** 5 mg folic acid is 8,500 µg DFE against a 570 µg RDA and a 1,000 µg upper limit — and it is a completely routine prescription for a woman with a prior NTD-affected pregnancy or on antiepileptics. The app must show that as *what the doctor prescribed*, not as a red over-limit warning. See §2.4; this is the single most important UX rule in this document.
6. **This stays a household tracker.** No drug-interaction engine, no adherence scoring, no "you missed 3 doses this week, your baby..." — none of it. Log, total, remind. Nothing that reads like a clinician looking over a shoulder.

The existing not-a-medical-device disclaimer is reused verbatim, minus its now-false last sentence.

---

## 1. What doctors actually prescribe

Compiled against ICMR-NIN 2020, MoHFW's Anemia Mukt Bharat / ANC guidance, WHO's 2016 antenatal care recommendations, and what routinely appears on an Indian ANC prescription. **Doses are typical label strengths for the picker's defaults — they are not advice, and every one of them is overridden by what the prescription says.** The whole table ships as data (§6) with `reviewStatus: "pending_review"`, the same posture as `rda_icmr_nin_2020.json`.

### 1.1 The routine four — near-universal in Indian antenatal care

| # | What | Typical strength | When | Why it matters to us |
|---|---|---|---|---|
| 1 | **Folic acid** | 400–500 µg daily | Preconception → end of week 12 (often continued) | Directly moves `folate` |
| 2 | **IFA — iron + folic acid** | 60 mg elemental iron + 500 µg folic acid, one daily, 180 days antenatal + 180 days postpartum (MoHFW) | From ~14 weeks, once nausea settles | Moves `iron` and `folate` |
| 3 | **Calcium + vitamin D** | 500 mg elemental calcium twice daily (1 g/day) + ~250 IU D; 360 days across pregnancy and lactation (MoHFW) | From 14 weeks | Moves `calcium`, `vitamin_d` |
| 4 | **Albendazole** | 400 mg, single dose | Once, after the first trimester | Medicine, not a supplement — adherence only |

### 1.2 Conditional and higher-dose supplements

| What | Typical strength | Prescribed when |
|---|---|---|
| **High-dose folic acid** | 4–5 mg daily | Prior neural-tube-defect pregnancy, pre-gestational diabetes, epilepsy on antiepileptics, obesity, haemoglobinopathies, methotrexate exposure |
| **Vitamin D** | 1,000–2,000 IU daily, or 60,000 IU weekly/monthly sachets | Deficiency on testing — near-universal in Indian practice |
| **Vitamin B12** | 500–1,500 µg oral, or injected | Deficiency; common on long-term vegetarian diets |
| **Iron, higher dose or different salt** | Ferrous ascorbate, carbonyl iron, ferrous fumarate | Iron-deficiency anaemia, or intolerance of the standard IFA tablet |
| **Iron, parenteral** | Iron sucrose, ferric carboxymaltose | Moderate/severe anaemia, or oral iron not tolerated — clinic-administered |
| **DHA / omega-3** | 200–300 mg DHA daily | Widely prescribed; not universal |
| **Iodine** | 150 µg daily | Usually inside the prenatal multivitamin |
| **Magnesium** | 300–400 mg | Cramps; varies a lot by practitioner |
| **Zinc** | 15 mg | Usually inside the multivitamin |
| **Vitamin C** | 40–100 mg, or as part of an iron combination | Often formulated with iron |

### 1.3 Inside a typical prenatal multivitamin

The user's question named vitamin B2 specifically — it is rarely prescribed alone; it arrives as part of the B-complex in a prenatal tablet. The full list of what such a tablet declares, and whether we track it:

| Nutrient | Typical per-tablet | Tracked today? |
|---|---|---|
| Vitamin B1 (thiamine) | 1.4–10 mg | ✅ `thiamin` |
| **Vitamin B2 (riboflavin)** | 1.4–10 mg | ✅ `riboflavin` |
| Vitamin B3 (niacin/niacinamide) | 18–45 mg | ✅ `niacin` |
| Vitamin B5 (pantothenic acid) | 5–10 mg | ❌ not in the nutrient registry |
| Vitamin B6 (pyridoxine) | 1.9–10 mg | ✅ `vitamin_b6` |
| Vitamin B7 (biotin) | 30–150 µg | ❌ not in the registry |
| Vitamin B9 (folic acid) | 400 µg – 5 mg | ✅ `folate` (unit trap — §2.2) |
| Vitamin B12 | 2.2–15 µg | ✅ `vitamin_b12` |
| Vitamin C | 40–100 mg | ✅ `vitamin_c` |
| Vitamin D3 | 400–1,000 IU | ✅ `vitamin_d` (unit trap — §2.3) |
| Vitamin E | 10–15 mg / 15–30 IU | ✅ `vitamin_e` (unit trap) |
| Vitamin A | 2,500–5,000 IU, usually as β-carotene | ✅ `vitamin_a` — **and a safety note: high-dose preformed retinol is teratogenic; we display the label figure and never suggest one** |
| Iron (elemental) | 30–100 mg | ✅ `iron` (salt trap — §2.1) |
| Calcium (elemental) | 200–500 mg | ✅ `calcium` (salt trap) |
| Magnesium | 50–400 mg | ✅ `magnesium` |
| Zinc | 7.5–22 mg | ✅ `zinc` |
| Iodine | 150 µg | ❌ not in the registry |
| Selenium | 30–70 µg | ❌ not in the registry |
| Copper / manganese / chromium | trace | ❌ not in the registry |
| DHA | 200–300 mg | ❌ not in the registry |
| Choline | 0–450 mg | ❌ not in the registry |

Six nutrients a prenatal tablet declares have no row in `nutrients` today. §3.4 says what we do about that — the short version is that the registry is content, not code (AP-6), so adding them is a data change, and **iodine, DHA and B5 are worth adding; the trace minerals are not**.

### 1.4 Prescribed medicines — adherence only, zero nutrient contribution

These show up on real antenatal prescriptions constantly. They are exactly why rule 4 exists.

| Condition | Commonly prescribed |
|---|---|
| Nausea and vomiting | **Doxylamine 10 mg + pyridoxine 10 mg** (first line), pyridoxine alone, ondansetron, promethazine |
| Acidity / reflux | Antacid gels, sucralfate, pantoprazole, omeprazole |
| Constipation | Lactulose, isabgol (psyllium), docusate |
| Hypothyroidism | **Levothyroxine** — dose-titrated on TSH; extremely common, as TSH screening is routine |
| Gestational diabetes | Metformin, insulin |
| Pre-eclampsia risk | **Low-dose aspirin 75–150 mg** from 12–16 weeks, plus calcium |
| Threatened miscarriage / preterm risk | Micronised progesterone (oral or vaginal), hydroxyprogesterone injections |
| Urinary tract infection | Nitrofurantoin, cefixime, amoxicillin |
| Preterm labour | Nifedipine, isoxsuprine; betamethasone/dexamethasone for fetal lung maturity |
| Hypertension | Labetalol, methyldopa, nifedipine |

### 1.5 Not tablets — explicitly out of scope

Td/Tdap vaccination, anti-D immunoglobulin at 28 weeks for an Rh-negative mother, IV iron, magnesium sulphate for eclampsia, antenatal corticosteroids. All clinic-administered, none of them a daily household routine. The app does not become a medical record. *(Optional, §10 Q4: a plain dated note.)*

### 1.6 After delivery

The lifestage machinery already carries `lactating_0_6` and `lactating_7_12`, so the regimen model must not assume delivery ends everything:

- IFA continues 180 days postpartum (MoHFW)
- Calcium continues to 360 days total
- Vitamin D and B12 usually continue while breastfeeding
- Folic acid at routine dose usually stops

A regimen is therefore an interval with an optional end date (§3.2), not something attached to "is pregnant".

---

## 2. Five modelling traps that decide the schema

Every one of these is a way to ship a number that is confidently wrong. They are why this feature is not "a food item with a serving size of 1 tablet".

### 2.1 Salt weight is not elemental weight

`Ferrous sulphate 200 mg` delivers about **60 mg** of iron. Get this wrong and the iron bar is off by 3×.

| On the strip | Elemental |
|---|---|
| Ferrous sulphate 200 mg | ~60–65 mg iron |
| Ferrous fumarate 200 mg | ~65 mg iron |
| Ferrous ascorbate 100 mg | ~30 mg iron |
| Carbonyl iron 100 mg | ~100 mg iron |
| Calcium carbonate 1250 mg | 500 mg calcium |
| Calcium citrate 1000 mg | ~210 mg calcium |

→ The schema stores **both**: `label_amount` + `label_unit` + `salt_form` as printed, and `elemental_amount` in the nutrient's canonical unit as the figure that reaches the totals. A conversion table ships in the reference pack; the user can override the elemental figure directly when a label is unusual.

### 2.2 Folic acid is not folate

`folate`'s registry row declares its unit as plain `ug` (`seed_v1.json`), while [§19](../architecture/05-food-and-nutrition.md) says folate is "µg DFE where available; plain µg otherwise, **with the form recorded** — these are not interchangeable and must not be silently mixed". There is no column recording the form. Today that is a latent inconsistency inside food data; the moment a 5 mg folic acid tablet is added it becomes a visible, order-of-magnitude one.

Supplemental folic acid is roughly **2× more available** than food folate (1.7× taken with food). So 500 µg folic acid ≈ 850–1,000 µg DFE, and a 5 mg tablet ≈ 8,500 µg DFE against a 570 µg target and a 1,000 µg UL.

→ Store the label figure *as printed* and a `dfe_factor` for the conversion. Show both: "Folic acid 5 mg (≈ 8,500 µg DFE)". Never silently show the converted number alone — nobody recognises their own tablet in it.

### 2.3 IU is not µg

`vitamin_d` is µg; every label says IU. `vitamin_e` and `vitamin_a` have the same problem with different factors.

| Nutrient | Conversion |
|---|---|
| Vitamin D | 1 µg = 40 IU |
| Vitamin A, retinol | 1 µg RAE = 3.33 IU |
| Vitamin A, β-carotene | 1 µg RAE = 12 µg β-carotene |
| Vitamin E, natural (d-α) | 1 mg = 1.49 IU |
| Vitamin E, synthetic (dl-α) | 1 mg = 1.11 IU |

→ `label_unit` accepts `IU` and converts on the way in, per nutrient and per form. The screen keeps showing IU because the strip does. This lands in `packages/nutrition_core/lib/src/units/`, where the existing unit conversions already live.

### 2.4 The upper limit is not a red line here

`rda_references.upper_limit` already holds 45 mg for iron and 1,000 µg for folate in pregnancy. Once supplements are logged, a perfectly ordinary prescription sails past both. Rule 5 governs:

- A logged dose from an **active prescribed regimen** never triggers a warning. It shows as prescribed. Full stop.
- A one-off dose the user added themselves, with no regimen and no prescriber, and which lands above the UL, gets **one neutral informational line** — "this is above the reference upper limit of X; that can be intentional when prescribed" — in the existing violet over-target treatment, *never* the red reserved for destructive actions (PRODUCT.md, brand commitments).
- No modal. No blocking. No repetition once dismissed.

### 2.5 The score measures food

`day_scorer.dart` withholds the score when micronutrient coverage is thin (§21.5). Let a multivitamin into that calculation and every pregnant day scores near-perfect on micros regardless of what was eaten — the score stops meaning anything.

→ **The daily score is computed on food only, in v1.** Nutrient *totals*, *bars* and *reports* include supplements as a separately-labelled contribution. The dashboard states which it is showing. This is §10 Q1 — it is the one decision here I would most like confirmed before building.

---

## 3. Schema — migration v7 → v8

Four new tables, all additive; no existing column changes. Follows the existing conventions exactly: UUIDv7 keys via `Identifiable`, `Owned` for per-profile separation, `Timestamped`, `SoftDeletable` tombstones for export-merge.

### 3.1 `supplement_products` — the thing in the cupboard

```
id, owner_id (null = shipped reference row, mirroring MealSlots' system rows)
name                 'Iron + folic acid'
brand_name           nullable — 'Autrin', 'Shelcal', what is actually on the strip
kind                 'supplement' | 'medicine'      ← rule 4 lives in this column
form                 'tablet' | 'capsule' | 'syrup' | 'sachet' | 'drops' | 'injection'
salt_form            nullable — 'ferrous_sulphate', 'calcium_carbonate'
strength_label       nullable — free text exactly as printed
source               'reference' | 'user'
notes                nullable
```

A reference row is copy-on-edit: editing a shipped product forks a user-owned copy, the way `forked_from_food_id` already works for recipes. The shipped catalog stays pristine across app updates.

### 3.2 `supplement_nutrients` — what one dose delivers

```
product_id, nutrient_id            (composite PK, mirrors LogEntryNutrients)
label_amount, label_unit           as printed: 5, 'mg' / 1000, 'IU'
elemental_amount                   canonical unit, after §2.1 / §2.2 / §2.3
conversion_note                    nullable — 'ferrous sulphate → 30% elemental'
provenance                         'label' | 'user'   ← rule 3 lives in this column
```

`kind = 'medicine'` products simply have no rows here. That is the mechanism, not a special case.

### 3.3 `supplement_regimens` — the standing instruction

```
id, owner_id, product_id
dose_quantity        1.0        (tablets per administration)
frequency            'daily' | 'twice_daily' | 'thrice_daily' | 'weekly' | 'as_needed' | 'once'
times_of_day         JSON ['08:00','20:00'] — reuses the reminder schedule encoding
starts_on, ends_on   ends_on nullable; §1.6's 180/360-day courses are real end dates
prescribed_by        nullable free text — 'Dr. …' / 'ANC clinic'
is_active            derived from the dates, not stored twice
note                 nullable — 'after breakfast', 'not with milk'
```

A regimen is what makes a dose *prescribed* for §2.4, and what the reminders read.

### 3.4 `supplement_log_entries` — a dose actually taken

```
id, owner_id, log_date, taken_at
product_id, regimen_id (nullable — an ad-hoc dose has no regimen)
dose_quantity
status      'taken' | 'skipped' | 'planned'   ← same vocabulary as log_status.dart
note
```

**Deliberately mirrors `FoodLogEntries`**, including the status vocabulary, so `isActual` in `dao/log_status.dart` extends rather than forks, and back-dating works the same way.

**The snapshot question.** `FoodLogEntries` freezes its nutrients into `LogEntryNutrients` at write time (I-1) so editing a food never rewrites history. A supplement dose should do the same — but a dose is one row referencing one unchanging product, and duplicating a 15-nutrient snapshot per tablet per day is a lot of rows for a table that gets three writes a day. **Proposal: no snapshot; compute through `product_id`, and make product edits copy-on-write** (editing a product's composition forks a new product row and repoints the *active regimen*, leaving past entries on the old row). Same guarantee, far fewer rows. §10 Q2.

**Registry additions** (`app/assets/catalog/seed_v1.json`, reference data, no code): add `iodine` (µg), `dha` (mg), `pantothenic_acid` (mg). Skip selenium, biotin, choline, copper, manganese, chromium — no catalog food reports them, so every food-derived value would be unknown and the bars would be permanently empty, which teaches nothing. They can be added later; the registry is content (AP-6).

---

## 4. Where the numbers go

`daily_summary_dao.dart` gains a second contribution channel. `SummaryNutrient` grows two fields:

```dart
final double amountFromFood;
final double amountFromSupplements;   // 0.0 for every pre-existing day
```

- `amount` = the sum. Bars, reports and the nutrient detail sheet show the total, **split into two visually distinct segments** on the same bar — the existing tick-at-100% / track-to-125% rule (PRODUCT.md) is untouched.
- `coverage` counts food only. A tablet does not make the *diet* better understood, and coverage is what gates the score.
- `NutrientContributor` (the "what contributed" sheet, FR-D-03) gains supplement rows, labelled as supplements — which is exactly the screen where somebody asks "why is my folate 8,600 µg?" and deserves a one-line answer.
- `DailySummaryNutrients` gains a `from_supplements` column so the derived cache does not have to re-join; it is rebuildable, so no backfill is needed.
- **`day_scorer.dart` is not touched at all** (§2.5).

---

## 5. UX

Thirteen approved screens exist and are decided facts (PRODUCT.md, principle 5). This adds one screen and three insertions, and re-litigates nothing.

**New: `/supplements`** — pushed over the shell like `/recipes`, not a fifth tab. Reached from Settings and from the dashboard card.
- *Today* — each due dose as a check row: name, dose, time, a single tap to mark taken. Skipped is one tap too and is kept, not deleted, in the same spirit as `logStatusSkipped`.
- *My regimens* — active courses with their date ranges, plus "ended" ones below.
- *Add* — search the reference pack, or "Add your own" straight to the free-form form. Everything the pack pre-fills is editable.

**Dashboard** — a compact card *below* food and water, visible only when at least one active regimen exists. Never empty-states at a profile with no supplements. Shows "2 of 3 taken" and nothing more.

**Nutrient detail sheet** — the food/supplement split, plus §2.2's dual display for folate.

**Reminders** — a sixth `ReminderType`, `supplement('supplement', 'Take a supplement')`, alongside the five in `reminder_type.dart`. `isTimed` is true, `defaultEnabled` is false. `ReminderRules` gains a nullable `regimen_id` next to the existing `mealSlotKey`, and reuses the entire scheduler, quiet hours, and the stand-down-when-already-done condition machinery. A dose already marked taken cancels its own reminder — that is `ReminderDayState` working as built, with one more input.

**Copy rules.** The disclaimer sheds its last sentence and gains: *"Nourishly records what you are taking. It does not recommend supplements or doses — that is your doctor's."* No screen in this feature contains the word "should".

---

## 6. The reference pack

`app/assets/reference/supplements_in_2026.json`, loaded by a `SupplementImporter` built like `RdaImporter` — versioned, reconciled on launch, user rows never touched.

```json
{
  "packVersion": "0.1.0",
  "region": "IN",
  "reviewStatus": "pending_review",
  "sourceCitation": "ICMR-NIN 2020; MoHFW Anemia Mukt Bharat; WHO ANC 2016",
  "disclaimer": "Typical label strengths for recognition only. Not a recommendation. Always enter what your prescription says.",
  "conversions": { "iron": { "ferrous_sulphate": 0.30, "ferrous_fumarate": 0.33, "ferrous_ascorbate": 0.30, "carbonyl_iron": 1.0 },
                   "calcium": { "calcium_carbonate": 0.40, "calcium_citrate": 0.21 },
                   "folate":  { "folic_acid_dfe_factor": 2.0 },
                   "vitamin_d": { "iu_per_ug": 40 } },
  "products": [ … §1.1–§1.4 … ]
}
```

~25 supplement products and ~20 medicines. Brand names are carried **only as search synonyms** — "Shelcal" must find the calcium row, because that is the word on the strip — with formulations never assumed from a brand name: the user confirms against their own box. Everything stays `pending_review` until it goes through the nutrition review packet (§0.6), the same gate the RDA data sits behind.

---

## 7. Export, privacy, backup

- All four tables go into `exportedTables`. The completeness test (`export_completeness_test.dart`) turns this from a promise into a build failure, which is the point of it.
- `export_schema.dart` version bumps; the importer merges by UUID like everything else.
- `profile_eraser.dart` deletes all four on profile erase.
- Nothing leaves the device — no backend exists and none is being added. **This is the most sensitive data the app will hold** (a levothyroxine regimen plus a due date is a medical record), and the zero-infrastructure rule is what protects it. That is not a coincidence; it is the whole argument for the architecture, and it is worth writing down here.

---

## 8. Requirements

| ID | Requirement | Priority |
|---|---|---|
| FR-SUP-01 | Log a supplement or medicine dose as taken, with date and time; back-dating supported | 1 |
| FR-SUP-02 | Mark a due dose as skipped; skipped doses are retained, not deleted | 1 |
| FR-SUP-03 | Create a regimen: product, dose, frequency, times of day, start and optional end date | 1 |
| FR-SUP-04 | Add a product from the shipped reference pack, with every field editable before saving | 1 |
| FR-SUP-05 | Add a fully custom product with per-nutrient label amounts and units | 1 |
| FR-SUP-06 | Supplement nutrients contribute to daily totals, always shown separately from food | 1 |
| FR-SUP-07 | The daily score is computed on food intake only; the app says so where the score is shown | 1 |
| FR-SUP-08 | Label amounts convert correctly across salt forms, IU, and folate DFE, showing both figures | 1 |
| FR-SUP-09 | Dose reminders per regimen, standing down once the dose is marked taken | 1 |
| FR-SUP-10 | Medicines are logged for adherence and contribute no nutrient values | 1 |
| FR-SUP-11 | A dose from an active prescribed regimen is never flagged as exceeding a limit | 1 |
| FR-SUP-12 | Regimens survive delivery — they end on their own date, not on a lifestage change | 1 |
| FR-SUP-13 | Supplement data is exported, imported and erased with the rest of the profile | 1 |
| FR-SUP-14 | Adherence appears in weekly/monthly reports as days-taken, with no judgement or scoring | S |
| FR-SUP-15 | A dated note for a clinic-administered dose (injection, vaccine) | C |

---

## 9. Phasing

| Phase | Work | Rough size |
|---|---|---|
| **A** | Migration v8, four tables, `SupplementDao`, tests | 1 |
| **B** | Unit conversions (§2.1–§2.3) in `nutrition_core/units`, with a test per trap | 1 |
| **C** | Reference pack + `SupplementImporter` | 1–2 |
| **D** | `/supplements` screen, regimen form, product picker | 2–3 |
| **E** | Summary integration, split bars, contributor sheet, dashboard card | 2 |
| **F** | `supplement` reminder type | 1 |
| **G** | Export/import/erase + completeness test | 1 |
| **H** | Copy pass, a11y (NFR-A-04: status is never colour alone — a taken dose needs its dot *and* its label), disclaimer rewrite | 1 |

B depends on A. C depends on B. D–G depend on C and are independent of each other. Fits after Phase 6 without disturbing it — nothing here blocks the keystore or device setup.

---

## 10. What I need decided before building

1. **Does the daily score stay food-only?** (§2.5) I have assumed yes — a score that a multivitamin can max out is not a score. Confirm, because reversing it later means rewriting stored `daily_scores`.
2. **Snapshot per dose, or copy-on-write products?** (§3.4) I have assumed copy-on-write. Snapshotting is more consistent with `LogEntryNutrients`; copy-on-write is far cheaper and gives the same history guarantee.
3. **Does `folate` get a recorded form?** (§2.2) §19 says the form must be recorded and no column records it. Adding `folate_form` to `nutrients` — or splitting DFE and total into two rows — is a reference-data change with catalog-wide reach, so it is worth deciding before, not after.
4. **Which six nutrients enter the registry?** I have assumed iodine, DHA and B5 in; selenium, biotin, choline and the trace minerals out, on the grounds that no catalog food reports them.
5. **Injections and vaccines — a dated note, or nothing at all?** (§1.5) I lean nothing: it is the first step toward a medical record, and the app is not one.
6. **Whose phone is this for?** If a household member is actually pregnant and will use this, the reference pack should match *their* prescription first and stay small, rather than shipping 45 products nobody in this house takes. If it is pre-emptive, the broad pack is the right call. This changes §6's size more than anything else in the document.

---

## 11. Documents this revises

This is not a new corner of the app; it reverses a deliberate, written-down non-goal, so the documents that recorded that decision have to move with it.

| Document | Change |
|---|---|
| [§19 / 05-food-and-nutrition.md](../architecture/05-food-and-nutrition.md) line 292 | "**no supplement logging** — so iron and folate will read low for anyone taking a prenatal" becomes a built feature. The neighbouring non-goal — **no per-food pregnancy warnings** — stays a non-goal, and nothing here should be read as softening it: telling somebody a tablet's contents is recording their prescription, while telling them a dish is unsafe in pregnancy is a clinical claim over 1,613 dishes with nothing sourced behind it. |
| [§19 / 05-food-and-nutrition.md](../architecture/05-food-and-nutrition.md) line 75 | Folate's recorded form, per §2.2 and Q3 |
| [01-product.md](../architecture/01-product.md) | The FR-SUP table from §8 |
| [06-data-model.md](../architecture/06-data-model.md) | Four tables and the v8 migration |
| [00-scope.md](../architecture/00-scope.md) | In-scope list; open question §0.8 on whether a household member is pregnant now (Q6) |
| [PRODUCT.md](../../PRODUCT.md) | Principle 2's bounded exception (rule 3), and supplements in the capabilities list |
| `profile_screen.dart`, `goals_screen.dart` | The disclaimer's last sentence stops being true |
| [10-adrs.md](../architecture/10-adrs.md) | An ADR for Q1 (score stays food-only) — it is exactly the kind of decision that gets quietly reversed later without one |
