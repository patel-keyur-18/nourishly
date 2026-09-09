# Part XI — Risks, Assumptions, Open Questions, and Roadmap

*Sections 33–37 · [Back to index](./README.md)*

---

## 33. Risks

**Re-scored after the review decision to ship the complete application (§9).** Three risks were elevated and five are new; one was reduced. Scored as **Impact × Likelihood**, each with an owner-actionable mitigation and an early-warning signal.

### What the full-application decision changed

| Risk | Movement | Why |
|---|---|---|
| R-5 guest→account migration | ↑ **elevated to Critical** | Live at launch with no prior local-only period in which to find its bugs |
| R-6 sync correctness | ↑ **elevated to Critical** | Same |
| R-8 solo-developer capacity | ↑ **elevated to Critical** | 32–38 weeks, then production operations indefinitely |
| R-1 catalog curation | ↓ **reduced** | Over-the-air deltas mean the launch catalog no longer has to be complete |
| R-20…R-24 | **new** | Feedback latency, live compliance, day-one operations, day-one cost, health-platform review |

### Critical

**R-1 · Food catalog curation is under-estimated**
*Impact: High · Likelihood: Medium (was High)*
The curated Indian tier (§19.4) is the product's differentiator and manual data work reliably overruns.
→ **Mitigation:** unchanged in method, but the decision to ship catalog deltas at launch (ADR-006 revised) substantially reduces the consequence: the launch catalog no longer has to be complete, only good enough to log a typical Indian day. Start with the **200 most-common foods**, ship, and let search-failure telemetry drive the queue (§31.6). Recruit a nutrition student or dietician for curation if budget allows — still the highest-value place to spend money on this project.
→ **Early warning:** week 2 of curation completes fewer than 400 items.

**R-5 · Guest→account migration loses data**
*Impact: Very High · Likelihood: Medium (was Low–Medium)*
The highest-consequence flow in the product (§18.5), now live at launch, and — because guest mode is the default entry path — the route by which *essentially every account is created*. It ships without the local-only shakedown period the staged plan would have provided.
→ **Mitigation:** idempotent chunked upload; resumable; **per-entity count reconciliation before success is claimed**; an automatic local export before any destructive branch; interrupt-at-every-step testing including process kill, network loss, token expiry mid-flight, and storage exhaustion. Instrument it in production from day one — migration success rate is a launch-critical metric, not a nice-to-have dashboard.
→ **Early warning:** any count mismatch in testing, ever. Treat one as a release blocker.

**R-6 · Sync bugs corrupt or duplicate data**
*Impact: High · Likelihood: Medium–High (was Medium)*
The hardest subsystem in the plan, now on the pre-launch critical path.
→ **Mitigation:** the modelling choices in ADR-005 remove most conflicts structurally — immutable additive water rows above all. Beyond that: property-based tests over concurrent operation sequences; a simulated multi-device harness; a **client-side sync kill switch** delivered through the config channel, so sync can be disabled in production without disabling the app; staged rollout beginning with the developer's own devices, then the closed beta.
→ **Early warning:** any duplicate or missing record in the multi-device harness.

**R-8 · Solo-developer capacity and burnout**
*Impact: High · Likelihood: Medium–High (was Medium)*
32–38 weeks of full-time work before launch, then indefinite maintenance, support, catalog curation, **and production operations**.
→ **Mitigation:** the §9.4 exclusions are a defence, not a formality — resist scope creep absolutely. Automate CI early. Choose boring technology (done). Accept a smaller catalog over a delayed launch. **Take the closed beta seriously as a morale mechanism as much as a feedback one**: eight months of building with no user contact is the single most demoralising shape this project can take.
→ **Early warning:** v1.0 scope growing after this document is finalised; the week-9 dogfooding milestone slipping.

**R-2 · Indian food-composition data licensing cannot be cleared**
*Impact: High · Likelihood: Medium*
IFCT 2017 / ICMR-NIN tables are the authoritative Indian source; their redistribution licence is unverified ([OPEN Q-1]).
→ **Mitigation:** resolve **before** curation starts. Fallback: build the Indian tier from USDA ingredient data plus published dish compositions, tiered as `derived`, with an honest accuracy caveat. Accuracy suffers modestly; the product still ships.
→ **Early warning:** no clear answer within two weeks of enquiry — trigger the fallback rather than waiting.

**R-3 · Nutrition data accuracy leads users to wrong conclusions**
*Impact: High · Likelihood: Medium*
Database error compounds with portion-estimation error (§19.6).
→ **Mitigation:** coverage gating (§21.5), quality tiers (§19.11), honest rounding (§20.7), and the language boundary (§21.7) are all mitigations for this one risk. Never imply precision the data lacks. Never diagnose.
→ **Early warning:** support reports of implausible nutrient values; any insight text that reads as a diagnosis.

### High

**R-20 · Eight to nine months elapse before real users touch the product** *(new)*
*Impact: High · Likelihood: High if unmitigated*
The direct cost of the full-application decision. The two largest uncertainties in this design — catalog coverage (A-18) and logging speed (R-4) — are unresolvable without real users, and building for eight months against unvalidated assumptions is how products arrive fully-formed and wrong.
→ **Mitigation, and it is a schedule requirement rather than advice:** **daily dogfooding from week 9**, when logging first works end to end, and a **closed beta of 15–30 users from week 20**, well before feature completion. Both are in §36 and neither may be cut. If only one survives, keep the beta.
→ **Early warning:** week 9 arrives and the app is not usable for the developer's own daily logging.

**R-4 · Logging friction causes churn despite the design effort**
*Impact: High · Likelihood: Medium*
The whole product thesis rests on J-2 being genuinely fast.
→ **Mitigation:** instrument the log path end to end and measure taps and seconds against the NFR-A-07 budget from the first working build. Usability-test J-1 and J-2 in the closed beta. If the numbers miss, fix them before adding any feature.
→ **Early warning:** median repeat-log time above 10 s in dogfooding.

**R-21 · Production operations exceed solo capacity** *(new)*
*Impact: High · Likelihood: Medium*
Live infrastructure holding other people's health data brings backup verification, monitoring, patching, incident response, and statutory breach notification — from launch day.
→ **Mitigation:** managed services only, no bespoke infrastructure; a backend that owns no business logic and therefore rarely changes (§15.5); backend outages are P2 by design (AP-1). **Rehearse backup restore on a populated database before launch, and write the breach-response procedure before launch, not after an incident.**
→ **Early warning:** any unrehearsed restore path at the point of go-live.

**R-22 · Live compliance surface from day one** *(new)*
*Impact: High · Likelihood: Medium*
Under the staged plan there was no server-side personal data in the first release. Now Nourishly is a data fiduciary from launch, with DPDP obligations attaching immediately (§30.1).
→ **Mitigation:** legal review becomes a prerequisite for *building* the backend rather than for launching it (§37). Privacy policy, consent flows, data-residency choice (Q-22), export, deletion, and breach procedure all in place before the first external user.
→ **Early warning:** backend build starting before Q-3 and Q-22 are answered.

**R-7 · Scoring weights are wrong or read as medical guidance**
*Impact: High · Likelihood: Medium*
The weights are judgement, not evidence ([ASSUMPTION A-7]); ADR-010 is the one ADR still marked Proposed.
→ **Mitigation:** review with a qualified nutrition professional before launch (Q-6). Keep weights as versioned data so revision is cheap. Review every insight and notification template against §21.7 line by line. Keep the score dismissible.
→ **Early warning:** any generated string that names a condition, implies causation, or recommends a supplement.

**R-24 · Health-platform integration fails review or slips** *(new)*
*Impact: Medium–High · Likelihood: Medium*
Apple Health and Health Connect are now launch scope. Health Connect requires a declaration to Google before distribution, and both platforms impose usage rules stricter than general privacy law (§30.9). Approval timelines are outside the developer's control.
→ **Mitigation:** submit the Health Connect declaration early — it is a lead-time item, not a build item. Keep the integration genuinely optional so a delayed approval does not block the release: if it is not ready, ship without it and add it in a point release.
→ **Early warning:** declaration not submitted by the start of Phase 5.

### Medium

**R-23 · Infrastructure cost with no revenue** *(new)*
*Impact: Medium · Likelihood: Medium* — the backend runs from day one; the product is planned as free with no ads and no data monetisation (A-16).
→ **Mitigation:** negligible at low scale, real by ~10k MAU (§31.5). Someone must be willing to pay it, or a sustainability model must exist before growth. Raised as Q-21 — a business decision, not an architectural one.

**R-9 · v1.1 AI feature economics don't work**
*Impact: Medium · Likelihood: Medium* — per-request costs could exceed any plausible revenue per user.
→ **Mitigation:** unit-economics analysis before commitment; evaluate on-device inference; cache aggressively; consider a paid tier. Because v1.0 ships only the seam (§9.4), abandoning it costs nothing.

**R-10 · App size deters installs on low-end devices**
*Impact: Medium · Likelihood: Low–Medium* — a bundled catalog adds 25–45 MB.
→ **Mitigation:** compress aggressively; Play Asset Delivery / App Thinning; monitor install conversion. Note that the tiered-replica design (§31.3) already provides the fallback: shrink the bundled set and lean harder on on-demand resolution.

**R-11 · Cold-start problem for personalisation** — the app needs a profile for good targets, but users skip setup.
→ **Mitigation:** reasonable generic defaults; a persistent but non-nagging prompt; show concretely what personalising would change.

**R-12 · Users log inconsistently, making reports meaningless**
→ **Mitigation:** §25.6's honesty rules are exactly this mitigation — always show the denominator, refuse averages below three logged days, exclude incompletely-logged days.

**R-13 · Store review rejection**
*Likelihood: Medium (raised)* — the launch surface now includes accounts, account deletion, health-platform integration, camera permission, and privacy labels covering server-side data. Every one is a rejection vector.
→ **Mitigation:** review guidelines before submission; in-app account deletion from the first release; audit privacy labels against actual observed network behaviour (§30.5); keep store copy free of health claims. Budget for at least one rejection round in the schedule.

**R-14 · Supabase dependency risk** (pricing change, service change, outage) — *now live from launch*.
→ **Mitigation:** the OSS core is self-hostable; avoid proprietary features in the hot path; offline-first means an outage degrades to fully-working-not-syncing.

**R-15 · Flutter plugin abandonment** for scanner, notifications, or health integration — *all three now ship in v1.0, so this is live rather than future*.
→ **Mitigation:** every native capability sits behind a port (§14.6); replacing a plugin touches one adapter file.

**R-25 · Architectural drift toward server dependence** *(new)*
*Impact: High · Likelihood: Low–Medium* — with a working API available, it is always easier to call the server than to write the offline path. Enough such choices and the product quietly stops being offline-first, which is its most differentiating property.
→ **Mitigation:** AP-1 and NFR-O-02 are testable, not aspirational — assert that logging use cases have no network dependency in their constructor graph. **Treat any pull request adding a network call to a read or write path as an architecture change** requiring explicit justification.

### Low

**R-16 · Catalog delta updates grow too large** → chunked deltas; snapshot rebase beyond N versions.
**R-17 · Timezone and day-boundary bugs** — travel, DST, custom rollover → store `log_date` explicitly (§22.5); a dedicated test suite; a test clock port from day one.
**R-18 · Unit-conversion errors** (fl oz variants, IU vs µg) → typed value objects (§20.6); conversions only at the presentation boundary; pipeline range checks (§19.7).
**R-19 · Local database corruption** → integrity checks, pre-migration snapshots, restore path (§16.7).

## 34. Assumptions

Every assumption made in this document, collected for a single review pass. Each states what changes if it proves false. **A-10 and A-16 were resolved in the review of 2026-09-09; A-3, A-11, A-13, A-14 changed as a consequence of the full-application decision.**

| # | Assumption | If wrong |
|---|---|---|
| **A-1** | The success metrics in §3.1 are reasonable guardrails for a pre-launch product | Re-baseline after ~500 users; no design change |
| **A-2** | The personas in §5 are representative | Re-derive after user interviews; could change v1.0 feature priority materially |
| **A-3** | Supabase's low tier is adequate through early adoption, **and someone is willing to pay it from launch day with no revenue** | Cost model changes, not architecture — but see Q-21, which is now a live question rather than a deferred one |
| **A-4** | Household-measure gram weights carry ±20–30% variance and users accept estimation | If unacceptable, a portion-photo guide or weighing-first flow is needed — significant UX work |
| **A-5** | ~35 ml/kg is a reasonable default water target for the Indian context | Adjust the default; the mechanism is unchanged |
| **A-6** | Pregnancy/lactation lifestages are out of scope for v1.0 | Adding them requires clinical review and stronger disclaimers |
| **A-7** | The scoring weights in §21.4 are a defensible starting point | Expert review changes weights — a data change plus a lazy recompute, not a redesign. **ADR-010 stays Proposed until this is tested (Q-6)** |
| **A-8** | DPDP 2023 + GDPR-equivalent rights + store health policies is the right compliance baseline | Legal review may add obligations. Now urgent rather than deferred, since server-side personal data exists from launch (R-22) |
| **A-9** | v1.0 is 18+ only | Supporting minors adds verifiable parental-consent obligations under DPDP |
| ~~**A-10**~~ | ~~The developer is comfortable with Dart/Flutter~~ | **RESOLVED — Flutter confirmed in review. ADR-001 is final.** |
| **A-11** | English **and Hindi** are sufficient at launch for the Indian market | If a third language is needed, strings are already externalised — the cost is translation and QA, not rework |
| **A-12** | Initial users are primarily in India | Changes catalog priorities and RDA region defaults, not architecture |
| **A-13** | Users will accept a ~60 MB app download | Triggers R-10's fallback — shrink the bundled catalog and lean on on-demand resolution, which already exists |
| ~~**A-14**~~ | ~~Barcode scanning is not needed for v1.0 viability~~ | **RESOLVED — barcode ships in v1.0 (§9.1).** |
| **A-15** | Users want a single score, not only raw numbers | If testing shows the score is distrusted, it is already dismissible; the sub-scores stand alone |
| **A-16** | **No monetisation in v1.0** — free, no ads, no data monetisation | Confirmed as the launch position. With backend cost from day one, sustainability becomes a real question by ~10k MAU (Q-21) |
| **A-17** | One user, one device at a time; concurrent multi-device editing is rare | If wrong, §17.6's conflict policies need strengthening — though the additive water model already handles the most likely case |
| **A-18** | ~15k catalog items on device is enough for ≥85% catalog resolution | Measured directly by search-failure telemetry from the first beta; drives the curation queue |
| **A-19** *(new)* | AI-assisted logging is not required for a competitive first release | If early users treat manual logging as unacceptably slow despite the 3-tap design, this is the exclusion in §9.4 most likely to be wrong. It is also cheap to reverse — the port and confirmation UI already exist |
| **A-20** *(new)* | This is a product intended for public distribution, not a personal-use app for one person | **This assumption changes a great deal if wrong** — see Q-25. A genuinely personal app needs no DPDP compliance programme, no store review, no support model, and a far smaller backend |

---

## 35. Open Questions

**Every question carries a recommended default so that design and implementation are never blocked waiting for an answer.** Questions marked ✅ were closed in the review of 2026-09-09. Questions marked **★** need the reviewer specifically — they cannot be decided from within the architecture.

### Closed in review

| # | Question | Resolution |
|---|---|---|
| ✅ Q-15 | Flutter or React Native? | **Flutter.** ADR-001 final |
| ✅ Q-10 | Monthly reports in the first release? | **Yes** — v1.0 (§9.1) |
| ✅ Q-11 | Hindi at launch? | **Yes** — English and Hindi at launch (FR-S-11) |
| ✅ Q-12 | Barcode scanning in the first release? | **Yes** — v1.0 (§9.1) |
| ✅ Q-9 | Does water deserve its own tab? | **Yes**, with quick-add also on the dashboard (§28.3). Revisit after beta usability testing; flat navigation makes reversal cheap |
| ✅ Q-4 | Water target for Indian climate? | **35 ml/kg** base with an activity adjustment, prominently overridable. Revisit with nutrition review |
| ✅ Q-5 | Which RDA reference set? | **ICMR-NIN 2020** for region `IN`, **WHO/IOM** otherwise. A data decision, keyed on `RdaReference.region` |
| ✅ Q-7 | Track alcohol as a macronutrient? | Track alcoholic beverages as foods with their energy; **no dedicated alcohol target or score component**. A limit target here would moralise, which §21.8 rules out |
| ✅ Q-8 | Support intermittent fasting / meal timing? | **Not in v1.0.** `logged_at` is stored, so timing analysis is addable later with no model change |
| ✅ Q-13 | Ask dietary preference at onboarding? | **Yes, optional and skippable** (FR-U-16). It improves search ranking and insight relevance enough to justify one onboarding step. Framed as sensitive data (§30.1) |
| ✅ Q-14 | Monetisation model? | **Free, no ads, no data monetisation at launch** (A-16). Sustainability past ~10k MAU is now Q-21 |
| ✅ Q-16 | SQLCipher on by default? | **Off, offered as a setting** (§30.3) |
| ✅ Q-17 | Bundled catalog size? | **~12–15k items / ~30–40 MB**, with on-demand long-tail resolution. Tune against install conversion and search-failure rate |
| ✅ Q-18 | Sync derived summaries? | **No** (§15.3). Recompute on the receiving device |
| ✅ Q-19 | Week start day? | **User-configurable, default Monday** (FR-U-08) |
| ✅ Q-20 | Day rollover for late-night eating? | **Configurable, default 04:00 local**, so a 1 a.m. snack counts to the previous day |

### ★ Still needs the reviewer

**★ Q-25 · Is Nourishly a personal app or a product for public distribution?** *(new — the most consequential open question)*
The brief describes "a personal mobile application" while also specifying scaling to 100k users. These imply very different products. If it is genuinely for personal or small-circle use, then DPDP compliance obligations, the legal entity question, store review, a support model, and most of §31 largely fall away, and the backend becomes trivially small. If it is a public product, all of §30 applies from launch day.
→ **Default assumed throughout this document: a public product** (A-20), because that is the more demanding reading and the scaling requirements imply it. **Confirm or correct this before the backend is built** — it is the cheapest correction available now and an expensive one later.

**★ Q-1 · What is the licensing status of IFCT 2017 / ICMR-NIN data for redistribution in a commercial app?**
→ **Default:** proceed with USDA + Open Food Facts as the base and build the Indian tier from ingredient-level composition plus published dish recipes, tiered as `derived`. Pursue clarification in parallel; upgrade the tier if cleared. **Blocks nothing, but start the enquiry now — it has the longest lead time of any open item (R-2).**

**★ Q-2 · Do Open Food Facts' ODbL share-alike terms create obligations for a bundled and server-hosted catalog?**
→ **Default:** treat OFF-derived records as a separately-attributed subset, keep provenance per record (already in the model), and be prepared to publish the OFF-derived portion. **More acute now than under the staged plan**, because a hosted catalog served over an API is a clearer act of database redistribution than a bundled asset. Confirm with counsel.

**★ Q-3 · Who is the data fiduciary, and what is the legal basis for processing?**
→ **Default:** implement DPDP + GDPR-equivalent rights universally; no DPO assumed at this scale. But the **entity** matters: an individual developer holding thousands of people's health data has personal exposure that a registered company does not. **This is now a prerequisite for building the backend, not for launching it (R-22).**

**★ Q-6 · Are the §21.4 scoring weights defensible?**
→ **Default:** ship the proposed weights, framed as personalised-target adherence rather than a health verdict, and obtain professional review before launch. **ADR-010 stays Proposed until this happens** — it is the only ADR not accepted, deliberately. Weights are versioned data, so revision is cheap.

**★ Q-21 · Who pays for the backend, and what is the cost ceiling?** *(new)*
Infrastructure now runs from launch day with no revenue against it (A-16, R-23).
→ **Default:** proceed on the assumption that low-tier managed hosting is acceptable through early adoption, and treat ~10k MAU as the point at which a sustainability decision becomes unavoidable. Confirm the ceiling now so the architecture is not later asked to solve a budget problem.

**★ Q-22 · Which region should host user data?** *(new)*
DPDP and user expectation both favour an India region for an India-first product; latency does too.
→ **Default: host in an India region** if the provider offers one at an acceptable tier, otherwise the nearest Asia region, and state the location plainly in the privacy policy. **Decide before provisioning — migrating a populated database between regions later is disruptive.**

**★ Q-23 · Apple Developer and Google Play accounts: individual or organisation?** *(new)*
Needed early. Sign in with Apple, Health Connect declaration, and store privacy declarations all depend on an enrolled account, and organisation enrolment has its own lead time.
→ **Default:** enrol now, in whichever form Q-3 settles on. **This is a lead-time item that can delay launch by weeks if left late.**

**★ Q-24 · Should AI-assisted logging be pulled into v1.0?** *(new)*
Excluded in §9.4 on my judgement — unproven accuracy, unmodelled cost, and it cannot work offline.
→ **Default: keep it out of v1.0.** This is the exclusion most likely to be contested, and it is cheap to reverse because the `MealParser` port and the propose-confirm-write flow both exist in v1.0. Say so if you disagree — it is a scope decision, not an architectural one.

## 36. Recommended v1.0 Roadmap

**[ASSUMPTION] One full-time developer. Estimates include testing and are deliberately not compressed.** Revised for the full-application scope: **32–38 weeks to first public release.**

**Two milestones in this plan are not negotiable, because they are the mitigation for R-20:** dogfooding from week 9, and a closed beta from week 20. If the schedule slips, cut scope from §9.2, never these.

### Phase 0 — Decide and de-risk *(week 1, before any code)*

| # | Task | Output |
|---|---|---|
| 0.1 | Answer **★ Q-25** (personal app or public product) | Determines whether §30's compliance programme applies at all |
| 0.2 | Start **★ Q-1 / Q-2** licensing enquiries | Longest lead time of any item — start on day one |
| 0.3 | Start **★ Q-3** (legal entity / data fiduciary) and **★ Q-23** (developer accounts) | Both are lead-time items that block the backend and the release respectively |
| 0.4 | Decide **★ Q-21** (cost ceiling) and **★ Q-22** (data region) | Q-22 must precede provisioning |
| 0.5 | Build a **throwaway** catalog spike: ingest 500 USDA foods, build FTS5, measure search latency on a real mid-range Android device | Validates NFR-P-03 — and the entire offline-catalog premise — before commitment |
| 0.6 | Finalise this document | Signed-off scope |
| 0.7 | Draft the nutrient registry and RDA reference tables | The data foundation everything keys off |

### Phase 1 — Foundation *(weeks 2–4)*

- Project setup, module structure, CI (analyse, format, test, **import lint** enforcing NFR-M-02).
- **Drift schema v1 — complete, including every sync column, UUIDv7 keys, tombstones, and the outbox.** Non-negotiable; these cannot be retrofitted later.
- `nutrition_core` v1: typed units, nutrient registry, aggregation, unknown propagation.
- Golden-vector harness.
- Design system: tokens, typography, theming, ring and bar primitives.
- Navigation shell, four tabs, routing.

**Milestone:** builds on both platforms; empty dashboard renders.

### Phase 2 — Catalog and logging *(weeks 5–9)*

- Catalog ETL pipeline; ingest USDA + OFF subsets; QA gates including the zero-vs-null audit.
- **Curated Indian tier: top 200 foods** (time-boxed — R-1).
- Bundled seed import + FTS index build in a background isolate.
- Food search, food detail, portion selection.
- Log food: create, edit, delete, back-date. Water logging with quick-add and undo.
- Recents, favourites, custom foods, meal templates.

**Milestone (week 9): 🔴 DOGFOODING BEGINS.** A full day of Indian and international food and water can be logged offline. **Start using it daily and do not stop.** This is the earliest possible real feedback and the primary mitigation for R-20.

### Phase 3 — Targets, summaries, and the dashboard *(weeks 10–13)*

- Onboarding and profile setup, including optional dietary preference.
- Target derivation engine; effective-dated TargetSets; manual overrides.
- Daily summary materialisation and invalidation.
- Scoring engine with capped sub-scores and coverage gating.
- Insight rule engine + the reviewed initial rule set.
- Dashboard: rings, macro bars, water, focus nutrients, meals.

**Milestone:** the app answers "how did I do today?"

### Phase 4 — Reports, recipes, barcode *(weeks 14–18)*

- Daily report with full score explanation; weekly report with §25.6's honesty rules enforced in UI; monthly report.
- Recipes with cooking yield; recipe logging through the ordinary food path.
- Barcode scanning against the local catalog and Open Food Facts.
- Data export (JSON + CSV).
- Local notifications and reminder rules.

**Milestone:** the complete offline product. Everything works except accounts and sync.

### Phase 5 — Backend, accounts, sync *(weeks 19–25)*

*The highest-risk block in the plan (R-5, R-6). Sequenced deliberately after the offline product works, so that sync is added to something known-good rather than developed alongside it.*

- Supabase provisioning in the region chosen at 0.4; schema, RLS policies, migrations in CI.
- Auth: Sign in with Apple, Google Sign-In, email OTP; token handling and secure storage.
- Sync engine: outbox push, cursor pull, conflict policies, backoff, dead-letter.
- **Guest→account migration** with count reconciliation and interrupt-at-every-step testing.
- Multi-device test harness; property-based concurrent-operation tests.
- Catalog delta publication and background application.
- Sync kill switch through the config channel.
- Backup configuration and **restore rehearsal on a populated database**.

**Milestone (week 20, overlapping): 🔴 CLOSED BETA OPENS** — 15–30 users, initially without accounts, then as the sync cohort. Do not wait for this phase to finish.

### Phase 6 — Integration, compliance, hardening *(weeks 26–31)*

- Apple Health / Health Connect adapters with per-direction, per-type consent. **Health Connect declaration submitted early** (R-24).
- Hindi localisation and QA.
- Accessibility audit against NFR-A-* on real devices with screen readers.
- Performance pass against NFR-P-*.
- **Network egress audit** (§30.5): proxy the app, verify no health data crosses the third-party boundary.
- Privacy policy, disclaimers, store privacy declarations, in-app account deletion verified.
- **Nutrition professional review** of targets, scoring, and every insight string (Q-6, R-7).
- Legal review sign-off (Q-3).
- Migration, crash-safety, and device-matrix testing.
- Breach-response procedure written.

### Phase 7 — Launch *(weeks 32–38)*

- Expand the curated Indian tier toward 1,500+ items using beta search-failure telemetry.
- Act on beta feedback; re-measure J-1 and J-2 against the §26.3 tap budgets.
- Store submission. **Budget for at least one rejection round** (R-13).
- Staged rollout: small percentage first, monitored for crash rate, sync errors, and migration success.

**Milestone: v1.0 public release — approximately week 32–38.**

### Post-launch

| Release | Contents |
|---|---|
| **v1.0.x** | Catalog growth driven by search-failure telemetry; fixes; performance |
| **v1.1** *(8–12 weeks post-launch)* | AI-assisted logging (natural language, then photo) gated on the economics analysis; home-screen water widget and watch complication; additional languages; adaptive targets; re-engagement reminders once there is usage data to tune them |
| **v2** | Meal planning, exercise integration, household/family scope, professional sharing — each a separate product decision (§10.2) |

### Sequencing rationale

Three deliberate choices in this ordering:

1. **The offline product is complete before the backend starts (Phase 4 before Phase 5).** Sync is then added to a known-good system, so a bug is unambiguously a sync bug. Building them concurrently makes every defect a two-suspect investigation, and sync defects are the ones that lose data (R-5, R-6).
2. **Dogfooding starts at week 9, not at feature completion.** It is the only feedback available for the first twenty weeks and it costs nothing.
3. **Catalog curation runs continuously rather than as a block**, so it can be cut back without cutting a feature — and because delta delivery means the launch catalog no longer has to be complete (ADR-006 revised).

---

## 37. Recommended Next Steps Before Implementation

### Before any code is written

| # | Action | Why it is blocking |
|---|---|---|
| 1 | **Review and finalise this document.** Confirm or overturn every **[ASSUMPTION]** in §34 | Assumptions compound; A-20 and A-2 change the plan materially if wrong |
| 2 | **Answer ★ Q-25** — personal app or public product | Determines whether the entire §30 compliance programme applies |
| 3 | **Start ★ Q-1 and ★ Q-2** (food-data licensing) | Longest lead time of any open item (R-2) |
| 4 | **Start ★ Q-3 and ★ Q-23** (legal entity, developer accounts) | Both block later phases and both have external lead times |
| 5 | **Decide ★ Q-21 and ★ Q-22** (cost ceiling, data region) | Q-22 must precede provisioning; region migration later is disruptive |
| 6 | **Validate the personas** with 8–12 interviews with people who currently track, or tried and stopped | Tests A-2 and the P-1…P-9 problem list. The *stop* reasons are the most valuable data available, and with a 32-week runway there is ample time to gather them |
| 7 | **Run the catalog/search spike (0.5)** | Validates NFR-P-03 and the offline-catalog premise before commitment |

### Before Phase 2 (catalog work)

| # | Action |
|---|---|
| 8 | Finalise the **nutrient registry** and **RDA reference tables**, with a source cited per row |
| 9 | Define the **catalog QA gate thresholds** concretely (§19.7), including the zero-vs-null audit |
| 10 | Decide the **top 200 Indian foods** by expected logging frequency, not by comprehensiveness |
| 11 | Set up the curation workflow and engage a reviewer if budget allows (R-1) |

### Before Phase 3 (targets and scoring)

| # | Action |
|---|---|
| 12 | **Engage a qualified nutrition professional** (★ Q-6) to review target derivation, scoring weights and curves, coverage thresholds, and every insight template. The single most valuable external review in the plan, and the reason ADR-010 is still Proposed |
| 13 | Write the **golden vectors** before implementing the scoring engine — specification first |
| 14 | Draft and review the **insight rule set** against §21.7's language boundary, line by line |

### Before Phase 5 (backend)

| # | Action |
|---|---|
| 15 | **Legal review complete** (★ Q-3) — this now gates *building* the backend, not launching it (R-22) |
| 16 | Privacy policy drafted; consent flows designed; data region provisioned (★ Q-22) |
| 17 | **Breach-response procedure written** before any real user data is stored |
| 18 | Multi-device sync test harness built **before** the sync engine, so it can be developed against |

### Before launch

| # | Action |
|---|---|
| 19 | **Backup restore rehearsed** on a populated database (R-21). An untested backup is not a backup |
| 20 | **Network egress audit** — proxy the app and verify no health data crosses the third-party boundary (§30.5) |
| 21 | **Accessibility audit** against NFR-A-* on real devices with screen readers |
| 22 | **Usability testing** of J-1 and J-2 with measured tap counts and times against §26.3 |
| 23 | Migration and crash-safety testing: kill the app mid-write, mid-migration, mid-import, mid-account-migration |
| 24 | Confirm in-app account deletion, store privacy declarations, and Health Connect declaration approval |

### Artefacts to produce before implementation

| Artefact | Purpose |
|---|---|
| Nutrient registry (data) | The foundation every nutrient-bearing structure keys off |
| RDA reference tables (data) | Target derivation, with citations |
| Scoring ruleset v1 (data) + golden vectors | Executable specification of §21 |
| Insight rule set v1 with reviewed copy | Enforces the language boundary |
| Drift schema v1 (design, not migration files) | Must include every sync column from day one |
| Curated Indian food list, top 200 | Bounds R-1 |
| Screen wireframes for the 13 screens in §27 | Validates the tap budgets before building |
| Privacy policy draft | Long review lead time; now gates Phase 5 |

### What explicitly should *not* happen yet

- No project scaffolding, no dependency installation, no schema migration files.
- **No backend provisioning** until Q-22 (region) and Q-3 (legal entity) are settled.
- No UI implementation before the wireframes are reviewed.
- No catalog ingestion at scale before Q-1 and Q-2 are resolved.
- **No scope additions to §9.1 without a corresponding removal.** With a 32–38 week runway and R-8 elevated to Critical, scope discipline is now the single most important management practice on this project.

---

## Closing note

The architecture is deliberately conservative in its technology choices and deliberately opinionated in its data design. That combination is intentional: boring, well-understood technology minimises the risk a solo developer carries, while strong opinions about immutable history, unknown-versus-zero, effective-dated targets, and coverage-gated scoring address the failure modes that make most nutrition apps quietly wrong.

**After the review of 2026-09-09**, three decisions define the project:

1. **Flutter, finally and without reservation** (ADR-001). Q-15 is closed.
2. **The complete application at first release** (ADR-006 revised). This buys a defensible product, no device-migration churn, and — the genuine architectural win — over-the-air catalog delivery that lowers the largest scope risk in the plan. It costs roughly four extra months before real users, production operations from day one, and a live compliance surface from day one.
3. **Refusing to score what cannot be measured** (ADR-010). Less immediately satisfying, considerably more honest, and the difference between a nutrition app that informs and one that misleads. It is the one decision still awaiting outside expertise.

The three most likely reasons this plan fails are now **R-8** (32–38 weeks is a long time to sustain solo), **R-20** (eight months of building without users, if the dogfooding and beta milestones are cut), and **R-1** (catalog curation overruns). All three are scope and schedule problems rather than architecture problems — which is why §9.4, the §36 milestones, and the discipline to protect them matter more than any diagram in this document.

---

*[Back to index](./README.md)*
