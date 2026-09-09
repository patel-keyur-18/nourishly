# Part XI — Risks, Assumptions, Open Questions, and Roadmap

*Sections 33–37 · [Back to index](./README.md)*

---

## 33. Risks

Scored as **Impact × Likelihood**, each with an owner-actionable mitigation and an early-warning signal.

### Critical

**R-1 · Food catalog curation is under-estimated**
*Impact: High · Likelihood: High*
The curated Indian tier (§19.4) is the product's differentiator and is estimated at 3–4 weeks of manual work. Manual data work reliably overruns, and it sits on the critical path.
→ **Mitigation:** time-box it explicitly. Start with the **200 most-common foods**, validated against real logging, and ship. Treat the catalog as a continuously improving asset, not a launch gate. Build the search-failure telemetry loop (§31.6) *before* launch so curation priorities come from data rather than intuition. Recruit a nutrition student or dietician for curation if the budget allows — this is the highest-value place to spend money on this project.
→ **Early warning:** week 2 of curation completes fewer than 400 items.

**R-2 · Indian food-composition data licensing cannot be cleared**
*Impact: High · Likelihood: Medium*
IFCT 2017 / ICMR-NIN tables are the authoritative Indian source; their redistribution licence is unverified ([OPEN Q-1]).
→ **Mitigation:** resolve this **before** curation starts, not after. Fallback: build the Indian tier from USDA ingredient data plus published dish compositions, computing dish values from ingredients, with quality tier `derived` and an honest accuracy caveat. Accuracy suffers modestly; the product still ships.
→ **Early warning:** no clear answer within two weeks of enquiry — trigger the fallback rather than waiting.

**R-3 · Nutrition data accuracy leads users to wrong conclusions**
*Impact: High · Likelihood: Medium*
Database error compounds with portion-estimation error (§19.6). A user could believe they are deficient, or meeting a target, when they are not.
→ **Mitigation:** the coverage gating (§21.5), quality tiers (§19.11), honest rounding (§20.7), and language boundary (§21.7) are all mitigations for this single risk. Never imply precision the data lacks. Never diagnose.
→ **Early warning:** support reports of implausible nutrient values; any insight text that reads as a diagnosis.

### High

**R-4 · Logging friction causes churn despite the design effort**
*Impact: High · Likelihood: Medium*
The whole product thesis rests on J-2 being genuinely fast.
→ **Mitigation:** instrument the log path end-to-end and measure taps and seconds against the NFR-A-07 budget. Usability-test J-1 and J-2 with real users before launch. If the numbers miss, fix them before adding any feature.
→ **Early warning:** median repeat-log time above 10 s in testing; D7 retention below 30%.

**R-5 · Guest→account migration loses data**
*Impact: Very High · Likelihood: Low–Medium*
The highest-consequence flow in the product (§18.5). Data loss here is unrecoverable and reputationally fatal.
→ **Mitigation:** idempotent chunked upload; resumable; count verification before claiming success; an automatic local export before any destructive branch; interrupt-at-every-step testing including process kill, network loss, and token expiry mid-flight.
→ **Early warning:** any count mismatch in testing, ever.

**R-6 · Sync bugs corrupt or duplicate data (Phase 2)**
*Impact: High · Likelihood: Medium*
Sync is the hardest subsystem in the plan.
→ **Mitigation:** the modelling choices in ADR-005 remove most conflicts structurally. Beyond that: property-based tests over concurrent operation sequences; a simulated multi-device harness; staged rollout starting with the developer's own devices; a client-side kill switch that disables sync without disabling the app.
→ **Early warning:** any duplicate or missing record in the multi-device harness.

**R-7 · Scoring weights are wrong or read as medical guidance**
*Impact: High · Likelihood: Medium*
The weights are judgement, not evidence ([ASSUMPTION A-7]).
→ **Mitigation:** review with a qualified nutrition professional before launch (§37). Keep weights as versioned data so revision is cheap. Enforce the language boundary by reviewing every template string. Make the score dismissible.
→ **Early warning:** any insight or notification string that names a condition, implies causation, or recommends a supplement.

**R-8 · Solo-developer capacity and burnout**
*Impact: High · Likelihood: Medium*
14–18 weeks of full-time work before launch, then indefinite maintenance and support.
→ **Mitigation:** the phase structure exists for this. Resist scope creep — §9.4 is a defence, not a formality. Automate CI early. Choose boring technology. Accept a smaller catalog over a delayed launch.
→ **Early warning:** MVP scope growing after this document is finalised.

### Medium

**R-9 · Phase 3 AI feature economics don't work**
*Impact: Medium · Likelihood: Medium* — per-request costs could exceed any plausible revenue per user.
→ **Mitigation:** do the unit-economics analysis before committing. Evaluate on-device inference. Cache aggressively. Consider making it a paid tier. The MVP's seam-only approach means this can be abandoned at no cost.

**R-10 · App size deters installs on low-end devices**
*Impact: Medium · Likelihood: Low–Medium* — a bundled catalog adds 25–45 MB.
→ **Mitigation:** compress aggressively; use Play Asset Delivery / App Thinning; monitor install conversion. Fallback: ship a smaller core catalog and fetch the rest on first connection, accepting a weaker cold-install-offline story.

**R-11 · Cold-start problem for personalisation** — the app needs a profile to give good targets, but users skip setup.
→ **Mitigation:** generic defaults that are reasonable; a persistent but non-nagging prompt; show concretely what personalising would change.

**R-12 · Users log inconsistently, making reports meaningless**
→ **Mitigation:** §25.6's honesty rules are exactly this mitigation — always show the denominator, refuse averages below three logged days, and exclude incompletely-logged days. Better to show less than to show something misleading.

**R-13 · Store review rejection** (health-claim wording, missing account deletion, privacy-label mismatch).
→ **Mitigation:** review guidelines before submission; in-app account deletion from the first release that has accounts; audit privacy labels against actual network behaviour; keep store copy free of health claims.

**R-14 · Supabase dependency risk** (pricing change, service change, outage).
→ **Mitigation:** the OSS core is self-hostable; avoid proprietary features in the hot path; and because the app is offline-first, an outage degrades to MVP behaviour rather than an incident.

**R-15 · Flutter plugin abandonment** for scanner, notifications, or health integration.
→ **Mitigation:** every native capability sits behind a port (§14.6); replacing a plugin touches one adapter file.

### Low

**R-16 · Catalog delta updates grow too large** → chunked deltas, snapshot rebase beyond N versions.
**R-17 · Timezone and day-boundary bugs** — travel, DST, custom rollover. → store `log_date` explicitly (§22.5); a dedicated test suite; a test clock port from the MVP.
**R-18 · Unit-conversion errors** (fl oz variants, IU vs µg) → typed value objects (§20.6); conversions only at the presentation boundary; pipeline range checks (§19.7).
**R-19 · Local database corruption** → integrity checks, pre-migration snapshots, restore path (§16.7).

---

## 34. Assumptions

Every assumption made in this document, collected for a single review pass. Each states what changes if it proves false.

| # | Assumption | If wrong |
|---|---|---|
| **A-1** | The success metrics in §3.1 are reasonable guardrails for a pre-launch product | Re-baseline after ~500 users; no design change |
| **A-2** | The personas in §5 are representative | Re-derive after user interviews; could change MVP feature priority materially |
| **A-3** | Supabase's low tier is adequate through early adoption | Cost model changes; architecture does not |
| **A-4** | Household-measure gram weights carry ±20–30% variance and users accept estimation | If unacceptable, a portion-photo guide or a weighing-first flow is needed — significant UX work |
| **A-5** | ~30–35 ml/kg is a reasonable default water target | Adjust the default; the mechanism is unchanged |
| **A-6** | Pregnancy/lactation lifestages are out of scope for MVP | Adding them requires clinical review and stronger disclaimers |
| **A-7** | The scoring weights in §21.4 are a defensible starting point | Expert review changes weights — a data change plus a lazy recompute, not a redesign |
| **A-8** | DPDP 2023 + GDPR-equivalent rights + store health policies is the right compliance baseline | Legal review may add obligations; the export/deletion mechanisms already exist |
| **A-9** | MVP is 18+ only | Supporting minors adds verifiable parental consent obligations |
| **A-10** | The developer is comfortable with, or willing to learn, Dart/Flutter | If not, reverse ADR-001 toward React Native (§11.5) — developer fluency outweighs the framework comparison |
| **A-11** | English-only is acceptable for MVP in the Indian market | If not, Hindi moves into the MVP; strings are already externalised, so the cost is translation and QA, not rework |
| **A-12** | Initial users are primarily in India | Changes catalog priorities and RDA region defaults, not the architecture |
| **A-13** | Users will accept a ~60 MB app download | Triggers R-10's fallback |
| **A-14** | Barcode scanning is not needed for MVP viability | If packaged foods dominate real logging, promote it into the MVP — the `FoodExternalRef` seam already exists |
| **A-15** | Users want a single score, not only raw numbers | If testing shows the score is distrusted or disliked, it is already dismissible; the sub-scores stand alone |
| **A-16** | No monetisation in MVP | A paid tier would need feature-gating design, kept out of scope deliberately |
| **A-17** | One user, one device at a time; concurrent multi-device editing is rare | If wrong, the conflict policies in §17.6 need strengthening — but the additive water model already handles the most likely case |
| **A-18** | ~30k catalog items on device is enough for ≥85% catalog resolution | Measured directly by the search-failure telemetry; drives curation priorities |

---

## 35. Open Questions

**Every question carries a recommended default so that design and implementation can proceed without waiting for an answer.**

### Legal / data

**Q-1 · What is the licensing status of IFCT 2017 / ICMR-NIN data for redistribution in a commercial app?**
→ **Default:** proceed with USDA + Open Food Facts as the base and build the Indian tier from ingredient-level composition plus published dish recipes, tiered as `derived`. Pursue licence clarification in parallel; upgrade the tier if cleared. *(Blocks nothing; resolve before curation starts — R-2.)*

**Q-2 · Do Open Food Facts' ODbL share-alike terms create obligations for a bundled catalog?**
→ **Default:** treat OFF-derived records as a separately-attributed subset with the required attribution, keep provenance per record (already in the model), and be prepared to publish the OFF-derived portion of the database. Confirm with counsel before launch.

**Q-3 · Which privacy regime governs, and is a DPO or local representative required?**
→ **Default:** implement DPDP + GDPR-equivalent rights universally; no DPO assumed at MVP scale. Legal review before launch.

### Nutrition science

**Q-4 · Should water targets be higher for Indian climate conditions?**
→ **Default:** use ~30–35 ml/kg with an activity adjustment, and make it prominently overridable. Revisit with nutrition expert review.

**Q-5 · Which RDA reference set should be authoritative — ICMR-NIN 2020 or WHO/IOM?**
→ **Default:** ICMR-NIN 2020 for users with region `IN`, WHO/IOM otherwise. `RdaReference` is already keyed by region, so this is a data decision, not a code one.

**Q-6 · Are the §21.4 scoring weights defensible?**
→ **Default:** ship the proposed weights, clearly framed as personalised-target adherence rather than a health verdict, and obtain professional review before launch (R-7). Weights are versioned data, so revision is cheap.

**Q-7 · Should alcohol be tracked as a macronutrient?**
→ **Default:** track alcoholic beverages as foods with their energy, but do **not** add a dedicated alcohol target or score component in MVP. Adding one invites moralising, which §21.8 rules out.

**Q-8 · Should the app support intermittent-fasting or meal-timing patterns?**
→ **Default:** out of scope for MVP. `logged_at` is stored, so timing analysis is possible later without a model change.

### Product

**Q-9 · Does Water deserve its own tab?**
→ **Default:** yes for MVP (§28.3), with quick-add also on the dashboard. Revisit after usability testing; the flat navigation makes reversal cheap.

**Q-10 · Should the MVP include monthly reports?**
→ **Default:** Should-have, not Must-have (§9.2). Given materialised dailies, it is nearly free — but a new user has no month of data, so it delivers no value at launch.

**Q-11 · Hindi at launch?**
→ **Default:** English at launch, Hindi as the first Phase 2 addition. Externalise all strings from the first commit (already required).

**Q-12 · Should barcode scanning be pulled into the MVP?**
→ **Default:** no (§9.4). Reconsider immediately if early testing shows packaged foods dominate real logging (A-14).

**Q-13 · Should the app ask about dietary preference (vegetarian, vegan, Jain, halal) at onboarding?**
→ **Default:** not in MVP — it adds onboarding friction and drives no MVP feature. Add in Phase 2 to improve search ranking and insight suggestions. Note this is sensitive data (religious inference, §30.1) and needs explicit purpose framing when added.

**Q-14 · Monetisation model?**
→ **Default:** free, no ads, no data monetisation for MVP (A-16). Most plausible later model: a paid tier for AI logging and advanced analytics. Explicitly excluded: anything involving user data.

### Technical

**Q-15 · Flutter or React Native, given the actual developer?**
→ **Default:** Flutter per ADR-001. **Reverse if the developer is materially more productive in TypeScript** — fluency beats framework comparison (A-10, §11.5). This is the single most important question to answer before writing code.

**Q-16 · Should SQLCipher be on by default?**
→ **Default:** off, offered as a setting (§30.3). Revisit if the user base skews toward higher-risk contexts.

**Q-17 · How large should the bundled catalog be?**
→ **Default:** target ~15k items / ~30–40 MB. Measure install conversion and search-failure rate, then tune (A-13, A-18).

**Q-18 · Should derived summaries ever be synced?**
→ **Default:** no (§15.3). Recompute on the receiving device. Revisit only if recomputation on a new device proves too slow in practice.

**Q-19 · Weekly report on Monday or the user's chosen start day?**
→ **Default:** user-configurable, defaulting to Monday (FR-U-08).

**Q-20 · How should day rollover be handled for late-night eating?**
→ **Default:** a configurable rollover time defaulting to 04:00 local, so a 1 a.m. snack counts toward the previous day. `log_date` is stored explicitly to support this (R-17).

---

## 36. Recommended MVP Roadmap

**[ASSUMPTION] One full-time developer. Estimates include testing and are deliberately not compressed.**

### Phase 0 — Decide and de-risk *(1 week, before any code)*

| # | Task | Output |
|---|---|---|
| 0.1 | Resolve **Q-15** (Flutter vs React Native) | The framework decision, final |
| 0.2 | Begin **Q-1/Q-2** licensing enquiries | Enquiries sent — long lead time, start immediately |
| 0.3 | Build a **throwaway** catalog spike: ingest 500 USDA foods, build FTS, measure search latency on a real mid-range device | Validates NFR-P-03 before committing |
| 0.4 | Review and finalise this document | Signed-off scope |
| 0.5 | Draft the nutrient registry and RDA reference tables | The data foundation everything else keys off |

*Rationale for spiking search first: it is the one performance requirement that could invalidate the whole offline-first catalog approach. Find out in week 0, not week 10.*

### Phase 1 — Foundation *(weeks 2–4)*

- Project setup, module structure, CI (analyse, format, test, import lint).
- Drift schema v1 — **complete with sync columns**, UUID keys, tombstones, outbox (ADR-006's load-bearing prerequisite).
- `nutrition_core` v1: units, nutrient registry, aggregation, unknown propagation.
- Golden-vector harness.
- Design system: tokens, typography, theming, the ring and bar primitives.
- Navigation shell with four tabs.

**Milestone:** the app builds on both platforms and shows an empty dashboard.

### Phase 2 — Catalog and logging *(weeks 5–8)*

- Catalog ETL pipeline; ingest USDA + OFF subsets; QA gates.
- **Curated Indian tier: begin with the top 200 foods** (time-boxed — R-1).
- Bundled seed import + FTS index build in a background isolate.
- Food search, food detail, portion selection.
- Log food: create, edit, delete, back-date.
- Water logging with quick-add and undo.
- Recents, favourites, custom foods.
- Meal templates.

**Milestone:** a full day of Indian and international food and water can be logged offline. **This is the first point at which the product can be dogfooded — start using it daily here.**

### Phase 3 — Targets, summaries, and the dashboard *(weeks 9–11)*

- Profile setup and onboarding.
- Target derivation engine; effective-dated TargetSets; manual overrides.
- Daily summary materialisation and invalidation.
- Scoring engine with capped sub-scores and coverage gating.
- Insight rule engine + the reviewed initial rule set.
- Dashboard: rings, macro bars, water, meals, focus nutrients.

**Milestone:** the app answers "how did I do today?"

### Phase 4 — Reports and polish *(weeks 12–14)*

- Daily report screen with full score explanation.
- Weekly report with the honesty rules enforced in UI.
- Monthly report *(Should-have — drop first if time is short)*.
- Data export (JSON + CSV).
- Accessibility pass: screen reader, dynamic type, contrast, reduced motion.
- Empty, error, and loading states throughout.
- Performance pass against NFR-P-*.

**Milestone:** feature-complete MVP.

### Phase 5 — Hardening and launch *(weeks 15–18)*

- Expand the curated Indian tier toward 1,500+ items (continuous throughout, concentrated here).
- Usability testing on J-1 and J-2 with 8–12 real users; fix what the taps and seconds reveal.
- **Nutrition professional review** of targets, scoring, and every insight string (R-7).
- Legal review: privacy policy, disclaimers, store declarations (R-13).
- Migration testing, crash-safety testing, device-matrix testing.
- Beta via TestFlight and Play internal testing.
- Store submission.

**Milestone: MVP launch — approximately week 18.**

### Post-MVP phases

| Phase | Duration | Contents |
|---|---|---|
| **Phase 6 — Accounts & sync** | 5–7 weeks | Supabase setup, RLS, auth (Apple/Google/email OTP), sync engine, guest→account migration with exhaustive interruption testing, multi-device verification |
| **Phase 7 — Catalog delivery & barcode** | 3–4 weeks | Catalog delta updates, barcode scanning against OFF, food error reporting, curation queue driven by search-failure telemetry |
| **Phase 8 — Reminders & localisation** | 2–3 weeks | Local notifications, reminder rules, quiet hours, Hindi localisation |
| **Phase 9 — Recipes & health integration** | 5–6 weeks | Recipe composition with yield factors, Apple Health / Health Connect |
| **Phase 10+ — AI logging** | TBD | Natural-language and photo logging, gated on the economics analysis (R-9) |

### Sequencing rationale

The order is chosen so that **each phase produces something usable and each de-risks the next**:
- Catalog and logging come before targets and scoring, because a scoring engine with nothing to score cannot be evaluated — and because dogfooding starts at the end of Phase 2, giving nine weeks of real usage feedback before launch.
- Reports come after summaries, since they are a presentation over them.
- Sync comes after launch, because it is the largest subsystem and the least necessary for validating the core hypothesis (ADR-006).
- Catalog curation runs continuously rather than as a block, so it can be cut without cutting a feature.

---

## 37. Recommended Next Steps Before Implementation

### Before any code is written

| # | Action | Why it is blocking |
|---|---|---|
| 1 | **Review and finalise this document.** Confirm or overturn every **[ASSUMPTION]** in §34 | Assumptions compound; overturning A-2 or A-10 changes the plan materially |
| 2 | **Answer Q-15 (Flutter vs React Native)** honestly, based on the actual developer's fluency | Everything downstream depends on it |
| 3 | **Start the food-data licensing enquiries (Q-1, Q-2)** | Longest lead time of any open item; blocks R-2's resolution |
| 4 | **Validate the personas** with 8–12 interviews with people who currently track, or have tried and stopped | Tests A-2 and the P-1…P-9 problem list. The stop-reasons are the most valuable data available |
| 5 | **Run the catalog/search spike (0.3)** | Validates NFR-P-03 and the entire offline-catalog premise before commitment |

### Before Phase 2 (catalog work)

| # | Action |
|---|---|
| 6 | Finalise the **nutrient registry** and the **RDA reference tables**, with sources cited per row |
| 7 | Define the **catalog QA gate thresholds** concretely (§19.7), including the zero-vs-null audit |
| 8 | Decide the **curated Indian food list** — the top 200 by expected logging frequency, not by comprehensiveness |
| 9 | Set up the curation workflow and the reviewer, if one is being engaged |

### Before Phase 3 (targets and scoring)

| # | Action |
|---|---|
| 10 | **Engage a qualified nutrition professional** to review target derivation, scoring weights and curves, coverage thresholds, and every insight template (R-7, Q-6). This is the single most valuable external review in the plan |
| 11 | Write the **golden vectors** for the calculation pipeline before implementing the scoring engine — specification first |
| 12 | Draft and review the **insight rule set** against §21.7's language boundary, line by line |

### Before launch

| # | Action |
|---|---|
| 13 | **Legal review**: privacy policy, terms, disclaimers, DPDP/GDPR posture, store privacy declarations |
| 14 | **Network egress audit**: proxy the app and verify that no health data crosses the third-party boundary (§30.5) |
| 15 | **Accessibility audit** against NFR-A-* on real devices with screen readers |
| 16 | **Usability testing** of J-1 and J-2 with measured tap counts and times against the budgets in §26.3 |
| 17 | **Migration and crash-safety testing**: kill the app mid-write, mid-migration, mid-import |
| 18 | Rehearse the **backup restore** procedure (Phase 6, before sync ships) |
| 19 | Confirm **in-app account deletion** and store-policy compliance |

### Artefacts to produce before implementation

| Artefact | Purpose |
|---|---|
| Nutrient registry (data) | The foundation every nutrient-bearing structure keys off |
| RDA reference tables (data) | Target derivation, with citations |
| Scoring ruleset v1 (data) with golden vectors | Executable specification of §21 |
| Insight rule set v1 with reviewed copy | Enforces the language boundary |
| Drift schema v1 (design, not migration files) | Must include sync columns from day one |
| Curated Indian food list, top 200 | Bounds R-1 |
| Screen wireframes for the 13 screens in §27 | Validates the tap budgets before building |
| Privacy policy draft | Long review lead time |

### What explicitly should *not* happen yet

- No project scaffolding, no dependency installation, no schema migration files.
- No backend provisioning — the MVP has no backend (ADR-006).
- No UI implementation before the wireframes are reviewed.
- No catalog ingestion at scale before the licensing questions are resolved.
- **No scope additions to §9.1 without a corresponding removal.** The MVP scope is the primary defence against R-8.

---

## Closing note

The architecture described here is deliberately conservative in its technology choices and deliberately opinionated in its data design. That combination is intentional: boring, well-understood technology minimises the risk a solo developer carries, while strong opinions about immutable history, unknown-versus-zero, effective-dated targets, and coverage-gated scoring address the failure modes that make most nutrition apps quietly wrong.

The three decisions most worth defending in review are:

1. **Shipping without a backend** (ADR-006), while paying the one-day cost of a sync-ready schema. It removes the largest engineering and operational cost from the critical path without foreclosing anything.
2. **Owning the food catalog** (ADR-008), which is expensive in manual effort and is the product's actual differentiator — and which the offline-first requirement makes unavoidable regardless.
3. **Refusing to score what cannot be measured** (ADR-010). It makes the product less immediately satisfying and considerably more honest, and it is the difference between a nutrition app that informs and one that misleads.

The three most likely reasons this plan fails are R-1 (catalog curation overruns), R-4 (logging is not actually fast enough), and R-8 (solo-developer capacity). All three are scope problems rather than architecture problems, which is why §9.4 and the phase structure matter more than any diagram in this document.

---

*[Back to index](./README.md)*
