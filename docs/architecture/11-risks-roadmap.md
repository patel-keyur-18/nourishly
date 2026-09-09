# Part XI — Risks, Assumptions, Open Questions, and Roadmap

*Sections 33–37 · [Back to index](./README.md)*

---

## 33. Risks

> **Re-scored for the personal-use scope (rev 0.3).** Nine risks were removed outright by deleting the backend, accounts, sync, distribution, and compliance surface. Two are new and specific to self-signed sideloading. The remaining set is much smaller and much more tractable — which is the clearest measure of what the scope decision bought.

### Removed by the rev 0.3 scope decision

| Risk | Why it no longer exists |
|---|---|
| R-5 guest→account migration data loss | No accounts |
| R-6 sync correctness | Nothing to sync |
| R-13 store review rejection | No store |
| R-20 eight months before real users | Your household is the user base; dogfooding starts week 5.5 |
| R-21 production operations | No infrastructure |
| R-22 live compliance surface | Personal and domestic use; no third parties receive data |
| R-23 infrastructure cost | None |
| R-24 health-platform review | Not distributing; declaration not required |
| R-25 drift toward server dependence | No server to drift toward |
| R-14 Supabase dependency | Not used |

### Critical

**R-26 · Losing the Android signing keystore destroys the data** *(new — the highest-probability data-loss path in this design)*
*Impact: High · Likelihood: Medium*
A self-signed APK can only be upgraded in place by an APK signed with the same key. Lose the keystore and the only way to install a new build is to uninstall first — **which deletes the app's local data**. On a personal project spanning years, keystores get lost with old laptops.
→ **Mitigation:** back up the keystore and its passwords the day it is generated, in at least two places, one of them off the machine that builds. Independently, the export habit in §0.5 means a lost keystore costs an uninstall/reinstall rather than the data. Android Auto Backup also covers this, since restore is by package name and not by signature.
→ **Early warning:** the keystore exists in exactly one place.

**R-27 · iOS free provisioning makes the app unusable for family members** *(new)*
*Impact: High · Likelihood: High, if any family member uses an iPhone*
Free Apple provisioning profiles expire after 7 days. The app stops launching until it is rebuilt and redeployed from a Mac. The cost lands on the family member, and they will stop using it.
→ **Mitigation:** decide the platform question first (§0.7). Android-only is the clean answer if the household allows it. Otherwise SideStore automation, or accept that iOS users don't get the app. **Do not build an iOS distribution plan on a weekly manual ritual.**
→ **Early warning:** planning iOS support before answering §0.7 question 1.

**R-1 · Food catalog curation is under-estimated**
*Impact: Medium (was High) · Likelihood: Medium*
→ **Substantially reduced by scope.** The catalog now needs the 300–500 foods *your household actually eats*, not a market-wide Indian catalog. You also know exactly what those foods are, which removes the guesswork that made the public-product version hard. Custom food creation carries the remainder.
→ **Early warning:** curating foods nobody in the house eats — a sign of building for an imagined user rather than the real four.

**R-3 · Nutrition data accuracy leads to wrong conclusions**
*Impact: High · Likelihood: Medium*
→ Unchanged in method — coverage gating (§21.5), quality tiers, honest rounding, language boundary. **But the audience changed the stakes in both directions:** you can verify values against the actual food you cooked, which is better than any public product manages; and the users are specific known people rather than an anonymous population, so an error reaches someone you care about (R-28).

**R-28 · Default targets are wrong for a family member with a health condition** *(new, replaces the abstract liability risk)*
*Impact: High · Likelihood: Unknown until §0.7 question 2 is answered*
Derived targets use general-population reference values. For someone with diabetes, hypertension, kidney disease, thyroid conditions, or who is pregnant or breastfeeding, those defaults can be actively wrong — a sodium or protein target that is fine for a healthy adult may not be.
→ **Mitigation:** answer §0.7 question 2. If yes for anyone: give that profile a **manual-targets-only mode** that skips derivation entirely, and strengthen the in-app note about not using the app to manage a condition. Both are small changes made cheaply now and awkwardly later.

### High

**R-8 · Solo-developer capacity**
*Impact: Medium (was High) · Likelihood: Medium*
→ **Substantially reduced:** 10–14 weeks full-time rather than 32–38, and no ongoing operations. The realistic shape is now 5–7 months of evenings and weekends (A-21), where the risk is not burnout but **stall** — a personal project with no external deadline that goes quiet at 70%.
→ **Mitigation:** the phase order in §0.8 is designed so the app is *usable by you* at the end of Phase 2 (~week 5.5), not at the end. A half-finished app you use daily gets finished; a half-finished app nobody has opened does not.

**R-4 · Logging friction causes the family to stop using it**
*Impact: High · Likelihood: Medium*
→ The core product risk, and unchanged. It is also now **directly observable**: you will know within a week of installing it on someone's phone.
→ **Early warning:** a family member logs for three days and stops. Ask them why immediately — that conversation is worth more than any analytics.

**R-7 · Scoring weights are wrong**
*Impact: Medium (was High) · Likelihood: Medium*
→ ADR-010 stays Proposed. The review packet (§0.6) is the deliverable. Weights are versioned data, so revision is a config change plus a recompute.

### Medium

**R-29 · Public repository leaks third-party catalog data** *(new)*
*Impact: Medium · Likelihood: Medium if unaddressed*
The app is private; the repository is not. Committing built catalog data or source extracts to a public MIT-licensed repo is public redistribution of a database, which reopens exactly the licensing questions that private use closed.
→ **Mitigation:** make the repo private, or gitignore all catalog data and commit only the pipeline code (§0.2). Decide before catalog work starts.

**R-10 · App size** — a bundled catalog adds 20–40 MB. → Now trivial: sideloaded install, no store conversion to protect. Effectively retired.

**R-11 · Cold-start personalisation** — → Nearly retired. You will set up the profiles yourself and you know everyone's height, weight, and goals.

**R-12 · Inconsistent logging makes reports meaningless** — → Unchanged; §25.6's honesty rules are the mitigation.

**R-15 · Flutter plugin abandonment** — → Reduced: fewer plugins now (no auth, no barcode initially, no health integration). Ports still isolate the rest.

**R-9 · AI economics** — → Deferred with the feature (Q-24).

### Low

**R-16 · Catalog delta size** → Not applicable; catalog ships with the build.
**R-17 · Timezone and day-boundary bugs** → Unchanged; store `log_date` explicitly, test clock from day one.
**R-18 · Unit-conversion errors** → Unchanged; typed value objects, conversion only at the presentation boundary.
**R-19 · Local database corruption** → Unchanged, and now **more important**, since there is no server copy. Integrity checks, pre-migration snapshots, and the export habit are the whole recovery story.
**R-2 · Food-data licensing** → **Closed** for private use (§0.2). Survives only as R-29.

## 34. Assumptions

> **Revised for the personal-use scope (rev 0.3).** Eight assumptions were resolved or retired by the scope decision.

| # | Assumption | If wrong |
|---|---|---|
| ~~A-1~~ | ~~Retention metrics as guardrails~~ | **Retired.** D7/D30 retention is meaningless for four known users. The real measure is whether the family still logs after a month — observable directly, no analytics required |
| ~~A-2~~ | ~~Personas are representative~~ | **Retired.** You know the users personally. The personas in §5 remain useful as design lenses (Ananya's speed need, Meera's simplicity need, Kabir's water-only need) but are no longer hypotheses to validate |
| ~~A-3~~ | ~~Supabase tier adequate~~ | **Retired** — no backend |
| **A-4** | Household-measure gram weights carry ±20–30% variance and users accept estimation | Still holds. **Better mitigated here than anywhere:** you can weigh your own katori once and set the exact figure for your household |
| **A-5** | ~35 ml/kg is a reasonable default water target | Adjustable per profile; low consequence |
| **A-6** | Pregnancy/lactation lifestages are out of scope | **Now a concrete question, not an assumption** — see §0.7 question 2 and R-28 |
| **A-7** | The §21.4 scoring weights are a defensible starting point | ADR-010 stays Proposed pending the review packet (§0.6) |
| ~~A-8~~ | ~~DPDP + GDPR + store policies baseline~~ | **Retired.** Personal and domestic use; no third parties receive data. §30.3 (device storage) and §30.8 (medical boundary) still apply |
| ~~A-9~~ | ~~18+ only~~ | **Now a real question.** If a family member under 18 will use it, growth-stage RDA values differ materially from adult ones. Tell me and I'll extend the reference tables |
| ~~A-10~~ | ~~Developer Flutter fluency~~ | **Resolved** — Flutter confirmed (rev 0.2) |
| **A-11** | English is sufficient | Now a family preference, not a market decision. Hindi is cheap to add if anyone would prefer it |
| **A-12** | Users are in India | Confirmed. ICMR-NIN 2020 RDAs are the right reference set |
| ~~A-13~~ | ~~~60 MB download acceptable~~ | **Retired** — sideloaded, no install funnel to protect |
| ~~A-14~~ | ~~Barcode not needed~~ | **Confirmed and strengthened.** A household cooking Indian food logs few packaged goods. Revisit only if real use shows otherwise |
| **A-15** | Users want a score, not only raw numbers | Testable in week 6 by asking three people directly |
| ~~A-16~~ | ~~No monetisation~~ | **Retired** — not a product |
| ~~A-17~~ | ~~One device per user~~ | **Now the design, not an assumption.** One profile per phone; export/import covers the tablet case |
| **A-18** | ~5–8k generic + 300–500 household foods gives near-complete coverage | Measured directly by how often anyone has to create a custom food. If it happens weekly after month one, curate more |
| ~~A-19~~ | ~~AI logging not required~~ | **Confirmed** (Q-24) |
| ~~A-20~~ | ~~Public product~~ | **Resolved — private household app.** The assumption that drove most of rev 0.2's cost, and it was wrong |
| **A-21** *(new)* | Available time is ~10–12 hours/week, giving 5–7 months | Tell me if it is very different — full-time changes the phase slicing (§0.8) |
| **A-22** *(new)* | Every household member has an Android device, or accepts §0.2's iOS constraints | **Blocking — §0.7 question 1** |

---

## 35. Open Questions

> **Rev 0.3 closed nine of the eleven remaining questions.** Everything below the first table is settled; three questions remain, and only one blocks work.

### Closed by the personal-use decision

| # | Question | Resolution |
|---|---|---|
| ✅ Q-25 | Personal app or public product? | **Personal.** 2–3 family members, no distribution |
| ✅ Q-1 | IFCT / ICMR-NIN licensing? | **Not required for private use** (§0.2). Nutrient values are facts; the licence concern is distribution |
| ✅ Q-2 | Open Food Facts ODbL obligations? | **Not triggered by private use.** Include attribution anyway — it costs a line. **Superseded by R-29:** the public *repository* is the actual exposure, not the app |
| ✅ Q-3 | Legal entity / data fiduciary? | **Not applicable.** Personal and domestic use is outside DPDP's scope. No entity, no privacy policy, no DPO |
| ✅ Q-21 | Who pays for the backend? | **Nobody — there is no backend** (ADR-006 rev 0.3) |
| ✅ Q-22 | Data region? | **India** — and now moot, since no data leaves the device |
| ✅ Q-23 | Developer accounts? | **Free Apple account; Android self-signed.** Resolved, but it created R-27 — see §0.7 question 1 |
| ✅ Q-24 | AI logging in v1.0? | **No.** Revisit later if wanted; not a priority |
| ✅ Q-6 | Scoring weight review? | **Approach agreed:** I produce a review packet plus a documented self-review (§0.6); you get a dietician to check it. ADR-010 stays Proposed meanwhile |

*Questions Q-4, Q-5, Q-7 through Q-20 were closed in rev 0.2 and are unchanged.*

### ★ Still open

**★ Q-26 · Which devices does the household use, and is a Mac available?** *(blocking)*
The only question that blocks work. Android-only removes the Mac requirement, the 7-day iOS provisioning cycle (R-27), and half the platform testing.
→ **Default if I hear nothing: build Android-only**, keeping the Flutter codebase iOS-capable so nothing is foreclosed. This is the right default even if one person uses an iPhone, because a weekly re-signing ritual is not a workable distribution plan.

**★ Q-27 · Does anyone in the household have a health condition, or is pregnant or breastfeeding?**
Not asking for details — only whether the app needs a **manual-targets-only mode** for one profile and a stronger note about condition management (R-28).
→ **Default: build the manual-targets-only mode anyway.** It is a small addition, it is useful regardless, and it means the answer can arrive late without rework.

**★ Q-28 · Repository private, or public with catalog data excluded?** (§0.2, R-29)
→ **Default: gitignore all catalog data and commit only the pipeline code**, which is good practice either way. Making the repo private is the simpler belt-and-braces option and I'd suggest it.

**Nice to know:** would any family member prefer Hindi? Would anyone under 18 use it (A-9)?

## 36. Recommended Roadmap

> **Superseded by [§0.8](./00-scope.md#08-revised-effort-estimate)**, which carries the authoritative phase plan for the personal-use scope: **≈13.5 weeks full-time, or 5–7 months at 10–12 hours a week.** This section keeps the sequencing rationale, which did not change.

### The phase plan

| Phase | Work | Weeks |
|---|---|---|
| 0 | Decisions (§0.7), catalog/search spike, nutrient registry and RDA tables | 0.5 |
| 1 | Foundation: modules, schema, `nutrition_core`, golden vectors, design system, navigation | 2 |
| 2 | Catalog pipeline, household curation, offline search, food and water logging | 3 |
| 3 | Profiles, target derivation, daily summaries, scoring, insights, dashboard | 3 |
| 4 | Daily / weekly / monthly reports, recipes | 2.5 |
| 5 | Export/import, Auto Backup rules, reminders, accessibility, performance | 1.5 |
| 6 | Keystore, device setup, install on family phones, fixes from real use | 1 |

**🔴 The milestone that matters: end of Phase 2 (~week 5.5) — the app becomes usable and goes on your own phone that day.** In the public-product plan this was a feedback mechanism. Here it is the defence against the real failure mode of a personal project: **stalling at 70% because nothing depends on finishing.** An app you use every morning gets finished. One that lives only in a repository does not.

Put it on a family member's phone as soon as the dashboard works (end of Phase 3, ~week 8.5), not at the end.

### Sequencing rationale

1. **Logging before reporting, reporting before polish.** Each phase leaves something more useful than the last, and every phase after 2 improves an app that is already in daily use.
2. **Catalog curation runs continuously**, not as a block. Curate what the household actually ate this week; the queue writes itself once you are logging.
3. **The backend phase is gone.** In rev 0.2 it was seven weeks and the largest risk concentration in the plan. Deleting it removed more schedule risk than every other simplification combined.
4. **Recipes are in Phase 4, not deferred.** For a household logging home-cooked Indian food, recipes are close to core — arguably more so than in the public design, where custom foods would have carried more of the load.

### After v1.0

No fixed roadmap, deliberately. Use it for a few months, then decide from real experience:

| Candidate | Reconsider when |
|---|---|
| Barcode scanning | Real logging shows meaningful packaged-food intake |
| Health Connect | You want weight or activity flowing in automatically (Android-only path) |
| Hindi | A family member asks |
| Home-screen water widget | One-tap water proves to be the most-used action |
| AI logging (Q-24) | You decide it is worth the cost and the offline compromise |
| Sync / backend | Only if the scope genuinely changes. ADR-006 documents what that would take |

---

## 37. Recommended Next Steps Before Implementation

### Answer three questions (§0.7)

| # | Action | Blocking? |
|---|---|---|
| 1 | **★ Q-26 — which devices, and is a Mac available?** | **Yes** — determines the platform plan |
| 2 | ★ Q-27 — health conditions or pregnancy in the household? | No — the default (build manual-targets mode anyway) is safe |
| 3 | ★ Q-28 — repo private, or catalog data excluded? | Before catalog work |

### Then, before writing code

| # | Action |
|---|---|
| 4 | **Run the catalog/search spike**: ingest ~500 USDA foods, build an FTS5 index, measure search latency on the actual phone the family uses. Validates NFR-P-03 and the offline-catalog premise in a day |
| 5 | Finalise the **nutrient registry** and **ICMR-NIN RDA tables**, with a source cited per row |
| 6 | **List the 100 foods your household actually eats most.** The single most useful pre-implementation artefact in this revision — it is the catalog specification, and only you can write it |
| 7 | Decide the **keystore storage plan** before generating one (R-26) |

### Before the scoring engine (Phase 3)

| # | Action |
|---|---|
| 8 | Produce the **nutrition review packet** (§0.6) and get it reviewed |
| 9 | Write the **golden vectors** before implementing scoring — specification first |
| 10 | Review every **insight string** against §21.7's language boundary |

### Before installing on family phones (Phase 6)

| # | Action |
|---|---|
| 11 | **Verify Android Auto Backup** actually restores on a wiped device, with the catalog excluded and user data included. An untested backup is not a backup |
| 12 | **Verify export → fresh install → import** round-trips completely, with counts reconciled |
| 13 | **Back up the keystore** to two places, one off the build machine (R-26) |
| 14 | Accessibility pass, and a performance check on the oldest phone in the household — not on your own, which is probably the newest |

### Artefacts to produce before implementation

| Artefact | Purpose |
|---|---|
| Nutrient registry (data) | The foundation every nutrient-bearing structure keys off |
| ICMR-NIN RDA tables (data) | Target derivation, with citations |
| Scoring ruleset v1 + golden vectors | Executable specification of §21 |
| Nutrition review packet | §0.6 |
| Insight rule set with reviewed copy | Enforces the language boundary |
| Drift schema v1 (design, not migration files) | UUID keys, timestamps, tombstones; **no sync machinery** |
| **Top-100 household food list** | The catalog specification |
| Screen wireframes for the 13 screens in §27 | Validates the tap budgets before building |

### What should still not happen yet

- No project scaffolding, no dependencies, no migration files.
- No catalog data committed to a public repository (R-29).
- No keystore generated until its backup plan exists.
- No iOS work until Q-26 is answered.
- **No scope additions.** The scope in Part 0 is small, coherent, and achievable. That is its main virtue.

---

## Closing note

Three reviews have moved this project from a public product with a backend, accounts, and a compliance programme to **a private household app that runs entirely on a phone**. The estimate went from 32–38 weeks to 10–14, and nine risks were deleted rather than mitigated.

Almost nothing in the *design* changed to get there. The offline-first foundation (ADR-004), the local SQLite source of truth (ADR-003), the snapshotting of nutrients onto log entries, the effective-dated targets, the coverage-gated scoring, the data model, and the entire UX all survived the scope collapsing by an order of magnitude. **That is the useful result of this exercise**: the parts that were removed were the parts that served distribution, not the parts that served the user. A design leaning on a server would now need rewriting.

What matters most from here is small and concrete:

1. **Answer the device question** (§0.7) — it is the only thing blocking a start.
2. **Write the top-100 food list.** It is the catalog specification, it takes an evening, and only you can write it.
3. **Get it onto your own phone at week 5.5 and keep it there.** For a personal project with no deadline, daily use by the author is the only reliable force that gets software finished.
4. **Back up the keystore, and export monthly.** With no server, these two habits are the entire disaster-recovery plan.

The one thing still genuinely unresolved is the nutrition science (ADR-010, §0.6) — deliberately left open, because it is the one part of this design that needs a qualified human rather than an architect.

---

*[Back to index](./README.md) · [Part 0 — Personal-Use Scope](./00-scope.md)*
