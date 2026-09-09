# Part 0 — Personal-Use Scope

*Authoritative scope statement · Revision 0.3 · 2026-09-09 · [Back to index](./README.md)*

> **Read this first.** It supersedes the scope, roadmap, and risk sections of revisions 0.1 and 0.2 wherever they disagree. Parts I–XI remain the design reference for what *is* being built; the parts covering backend, authentication, synchronisation, API design, compliance, and scalability are marked **Deferred** and retained for reference only.

---

## 0.1 What Nourishly actually is

**A private nutrition and hydration tracker for one household — the author and 2–3 family members. Not distributed publicly. Not sold. No servers. No accounts.**

This is the third scope revision, and it is by far the largest simplification:

| | Rev 0.1 | Rev 0.2 | **Rev 0.3 (this)** |
|---|---|---|---|
| Users | Public product | Public product | **2–3 family members** |
| Distribution | App Store / Play Store | App Store / Play Store | **Sideloaded, self-built** |
| Backend | Phase 2 | At launch | **None, ever** |
| Accounts / auth | Phase 2 | At launch | **None — local profiles** |
| Sync engine | Phase 2 | At launch | **None — file export/import** |
| Compliance programme | Pre-launch | Pre-backend | **Not applicable** |
| Estimated effort | 14–18 weeks | 32–38 weeks | **10–14 weeks full-time** |

The good news is that almost everything genuinely valuable in this design survives untouched. The offline-first architecture, the food catalog strategy, the calculation pipeline, the scoring model, the data model, and the whole UX design were all built around the device being self-sufficient. Removing the server removes work, not capability — **which is the clearest possible evidence that ADR-004 was the right foundation.**

---

## 0.2 Answers to your questions

### "Why do we need licensing for personal use? Can't we maintain the catalog in a local database?"

**You're right, and Q-1 and Q-2 are now closed.** Copyright and database rights govern *distribution*, not private use. Specifically:

| Source | Status for your use |
|---|---|
| **USDA FoodData Central** | Public domain. No restriction of any kind, private or public. Use freely |
| **Open Food Facts (ODbL)** | Share-alike obligations attach to *publicly distributing* the database or a derived one. Building a local catalog for your own household does not trigger them. Include the attribution line anyway — it costs one line |
| **IFCT / ICMR-NIN** | Nutrient values are facts, and facts are not copyrightable. A published table's *compilation and presentation* may be protected, but transcribing values into your own database for personal use is not the concern the licence exists to address |

So: **build the catalog locally, ship it in the app, no licensing work needed.**

### ⚠️ But there is one real catch, and it is specific to your setup

**Your GitHub repository `patel-keyur-18/nourishly` is public.** I checked.

The *app* being private does not make the *repository* private. If you commit catalog data files — a built SQLite catalog, CSV extracts, scraped nutrient tables — to a public repo, that is public redistribution of a database, and the licensing questions reopen immediately for exactly the data you were told not to worry about.

**Two ways to close this, either is fine:**

1. **Make the repository private.** Simplest, and appropriate for a family project anyway.
2. **Keep the repo public but keep catalog data out of it.** `.gitignore` the built catalog and any source extracts; commit only the *pipeline code* that builds it. Anyone cloning the repo builds their own catalog from the original sources.

I'd suggest **(1)**, with **(2)** as a good habit regardless. This design document is fine to keep public either way — it contains no third-party data.

**One nuance worth knowing:** the repository is currently MIT-licensed, which invites others to reuse whatever is in it. That is a fine choice for the *code*; it is not a promise you can make about third-party nutrition data you did not author. Keeping the data out of the repo resolves this cleanly too.

### "It's an offline-only app — why do we need infrastructure?"

**You're right. No infrastructure.** ADR-006 is reversed again, this time to *no backend, permanently*. What that costs you and how it is covered:

| What a backend would have provided | How this design covers it without one |
|---|---|
| Backup / device change | **Android Auto Backup** (automatic, free, to each person's own Google Drive) plus **manual export to a file** (§0.5) |
| Multi-device for one person | Export/import. Realistically rare for a family tracker |
| Sharing data between family members | **Not needed** — each person tracks their own food on their own phone. There is no shared data in this product |
| Catalog updates without a release | **You rebuild and reinstall.** You control the build; this is simpler than a delta channel, not worse |
| Account recovery | Not applicable — there are no accounts |

### "I have a free Apple Developer account. Keep it unsigned for both platforms. I will never pay any platform."

Two corrections here, one minor and one that may change your plan.

**Minor — Android APKs cannot be unsigned.** Android refuses to install an unsigned APK. What you want is a **self-signed** APK using a keystore you generate yourself: free, permanent, no Google involvement, no fees, ever. That works perfectly and is the right approach.

> **⚠️ Keep a backup of that keystore.** If you lose it, you cannot upgrade an installed app in place — the signature won't match. Android will require uninstalling first, **which deletes the app's data**. Store the keystore somewhere you will still have it in three years. This is a real data-loss path for this setup and it is easy to overlook.

**The one that may change your plan — the free Apple account is much more limited than the Android side.**

| | Android, self-signed | iOS, free Apple account |
|---|---|---|
| Cost | ₹0 forever | ₹0 |
| App validity | **Permanent** | **Expires after 7 days** |
| To renew | Nothing | Reconnect to a Mac, rebuild, redeploy — **every week, per device** |
| Build machine | Linux, Windows, or Mac | **macOS with Xcode only** |
| Apps per device | Unlimited | 3 via free provisioning |
| Entitlement-gated capabilities (HealthKit, push, App Groups) | N/A | Generally **unavailable** on a free personal team |

The seven-day expiry is the problem. A daily-use family app that stops opening every Monday unless you plug someone's iPhone into a Mac is not a workable product — the friction lands on the family member, not on you, and they will stop using it.

**Options, in the order I'd consider them:**

1. **Android only.** If everyone in the household is on Android, this is clearly right. It removes the Mac requirement, the weekly ritual, and iOS testing entirely. Flutter still builds for iOS if that ever changes.
2. **Android for everyone; you personally tolerate the iOS cycle** if you're on iPhone and have a Mac.
3. **SideStore / AltStore** — third-party tools that automate the 7-day refresh over Wi-Fi. They work, but they are fiddly to set up, break on iOS updates, and are not something to ask a family member to maintain.
4. **Pay the $99/year.** You've ruled this out; noted and respected. Flagged only so the trade-off is explicit — it is the one thing that makes iOS painless.

**I need to know which devices your family actually uses before finalising the platform plan.** This is the last genuinely blocking question (§0.7).

### "Get the nutrition review done, or review it yourself?"

**I'll do both halves of what I can, and be clear about the limit.**

I will produce a **self-contained review packet** (§0.6) — the target derivation, the RDA tables with sources, every scoring curve and weight, and every insight string — written so a dietician can review it in under an hour without reading this document. I'll also do a documented self-review against published guidance and flag anything I'm unsure about.

What I cannot do is *be* the qualified reviewer. For a public product that gap was a liability concern. For your family it is a concrete one: **if anyone in the household has a diagnosed condition — diabetes, hypertension, kidney disease, thyroid, or is pregnant — the app's default targets will be wrong for them**, because they are derived from general-population reference values. That is worth a specific answer from you (§0.7), and it is a much more useful question than the abstract one it replaces.

---

## 0.3 Revised scope

### In scope — v1.0

Everything below is unchanged from the Part I design unless noted.

| Area | Included |
|---|---|
| **Logging** | Food search, recents, favourites, custom foods, meal templates, four meal slots plus custom categories, serving + quantity, back-dating, copy meal/day, edit/delete |
| **Recipes** | Multi-ingredient household recipes with cooking yield — **more important here than in the public design**, since family cooking is the main thing being logged |
| **Water** | Quick-add chips, custom amounts, unit preference, derived target, undo, history, beverage hydration contribution |
| **Nutrition** | 5 macros + saturated fat + sugar + 17 micronutrients where data exists; unknown ≠ zero; coverage tracking; per-meal subtotals |
| **Targets** | Derived per person from profile and goal; manual overrides; effective-dated |
| **Reports** | Daily dashboard, daily report with score and insights, weekly report, monthly report |
| **Local profiles** | 2–4 profiles on one install, switchable, fully separate data (§0.4) |
| **Backup** | Manual export/import (JSON + CSV) and Android Auto Backup configuration (§0.5) |
| **Catalog** | Bundled, ~5–8k USDA generic items + **300–500 hand-curated household foods**; rebuilt and reinstalled when you want to update it |
| **Reminders** | Local notifications — water, meal, end-of-day summary |
| **Platform** | Android primary; iOS subject to §0.2. Dark mode, dynamic type, screen reader |

### Out of scope — permanently

| Removed | Reason |
|---|---|
| Backend, API, hosting | No infrastructure (your decision) |
| Accounts, sign-in, guest→account migration | No servers; local profiles replace this entirely |
| Sync engine, outbox, conflict resolution | Nothing to sync between. **The single largest work reduction in this revision** |
| DPDP compliance programme, privacy policy, consent flows | Personal and domestic use. No third parties receive any data |
| Store listings, review, privacy labels, account-deletion requirement | Not distributed through any store |
| Analytics and crash reporting SDKs | No third-party data collection at all. Local crash logs only |
| Scalability work (§31) | Four users |
| Barcode scanning | **Deferred, not deleted.** Reconsider once real logging shows how much packaged food the household actually eats — likely little, for home cooking |
| Health Connect / Apple Health | Health Connect on Android is still feasible; HealthKit likely isn't on a free Apple account. Deferred until the platform question is settled |
| Hindi localisation | Now a family preference rather than a market requirement — tell me if anyone would prefer it |
| AI logging | Confirmed out (Q-24) |

### Deferred document sections

These remain in the repository as reference for a possible future change of mind. **None of it gets built.**

| Section | Status |
|---|---|
| §15 Backend Architecture | Deferred |
| §17 Synchronisation Strategy | Deferred |
| §18 Authentication Strategy | Deferred — replaced by §0.4 |
| §24 API Domain Design | Deferred |
| §30.1–30.2 regulatory posture | Not applicable; §30.3 (storage) and §30.8 (medical boundary) still apply |
| §31 Scalability | Not applicable |

---

## 0.4 What replaces accounts: local profiles

Each family member gets a profile on their own device. The design already supports this at zero cost, because every user-owned row carries an `owner_id` (§18.4) — that column was designed for guest→account migration and now does something simpler and more useful.

| Property | Behaviour |
|---|---|
| Profile creation | Name, avatar colour, body metrics, goal. No email, no password, no server |
| Switching | Long-press the avatar on the dashboard. Instant — a different `owner_id` filter, nothing more |
| Data separation | Complete. Every query is scoped by `owner_id` |
| Shared data | The food catalog, custom foods, and recipes are shared across profiles on a device — which is exactly right for a household that cooks the same dishes |
| Typical use | One profile per phone. Multi-profile matters mainly for a shared tablet |
| Deletion | Delete a profile and its data, with export offered first |

**Schema consequence:** keep UUIDv7 primary keys, `created_at` / `updated_at`, and `deleted_at` tombstones — they cost nothing and make export/import merge correct. **Drop** the outbox, `sync_state`, `server_revision`, sync cursors, and the device registry. Keeping dead sync machinery "just in case" in a four-user app is precisely the over-engineering this document has argued against throughout.

---

## 0.5 What replaces sync: backup that costs nothing

Two independent mechanisms, because the failure modes differ.

**1. Android Auto Backup — automatic, free, no work for the user**

Android backs up app data to each person's own Google Drive with no infrastructure on your side. One design detail makes it work well here:

> **Configure the backup rules to include the user-data tables and exclude the food catalog replica.** The catalog is 20–40 MB, is identical for everyone, and is rebuildable from the bundled asset — backing it up would blow the per-app quota for no reason. User data is a few MB a year and fits comfortably.

This covers the common case — new phone, restore, everything is there — with zero user effort.

**2. Manual export / import — explicit, portable, verifiable**

- Full JSON export (re-importable) and CSV export (readable in a spreadsheet).
- Written to a location the user chooses; they can put it in Drive, email it to themselves, or keep it on a laptop.
- **Import merges by UUID**, so importing an export into a fresh install restores everything, and importing an older export alongside newer data does not duplicate.
- This is also the answer to the keystore risk in §0.2: if you ever have to uninstall and reinstall, an export is what saves the data.

**Recommend prompting for an export periodically** — monthly, dismissible, never nagging. For a four-user app with no server, an occasional gentle reminder is the entire disaster-recovery strategy.

---

## 0.6 The nutrition review packet

Deliverable, produced before the scoring engine is built (§37 step 12). Self-contained, roughly 6–8 pages, written for a dietician who has not read this document:

1. **Target derivation** — Mifflin-St Jeor, activity factors, goal adjustments, calorie floors, protein g/kg by goal, fibre per 1,000 kcal, water per kg. Every formula with its source.
2. **RDA reference tables** — the ICMR-NIN 2020 values to be used, keyed by age and sex, with citations, laid out for line-by-line checking.
3. **Scoring curves** — the four curve types with worked examples, and why each nutrient is assigned the type it is.
4. **Component weights** — the §21.4 table and the reasoning, flagged clearly as judgement rather than evidence.
5. **Every insight string** — all templates, with the §21.7 language rules they were written against.
6. **Specific questions** — the dozen or so points where I am genuinely uncertain, so a reviewer's hour goes to what matters.

**My own review is documented alongside it**, including what I could verify against published guidance and what I could not. ADR-010 stays *Proposed* until a qualified person signs off — that does not block building, since the weights are versioned data and revision is a config change plus a recompute (§25.7).

---

## 0.7 What I still need from you

Everything else is settled. Three questions remain, and only the first blocks work.

**1. ⚠️ Which devices does the household actually use?** *(blocking the platform plan)*
- All Android → Android-only build. Simplest by a wide margin, and I'd recommend it.
- Mixed → we need to decide per §0.2 whether iPhone users get the 7-day cycle, SideStore, or nothing.
- Do you have a Mac available? Required for any iOS build at all.

**2. Does anyone in the household have a health condition or is pregnant?**
Diabetes, hypertension, kidney disease, thyroid, pregnancy or breastfeeding all change nutritional targets in ways general-population reference values get wrong. I am not asking for details — just whether the app needs to (a) support a manual-target-only mode for that person and skip derived targets entirely, and (b) carry a stronger note about not using it for condition management. Both are small changes if I know now.

**3. Repository visibility — private, or public with catalog data excluded?** (§0.2)
Either is fine. Just pick one before catalog work starts.

**Nice to know, not blocking:** would any family member prefer Hindi?

---

## 0.8 Revised effort estimate

| Phase | Work | Weeks |
|---|---|---|
| 0 | Decisions, catalog/search spike, nutrient registry and RDA tables | 0.5 |
| 1 | Foundation: modules, schema, `nutrition_core`, design system, navigation | 2 |
| 2 | Catalog pipeline, household curation, search, food and water logging | 3 |
| 3 | Profiles, targets, daily summaries, scoring, insights, dashboard | 3 |
| 4 | Daily/weekly/monthly reports, recipes | 2.5 |
| 5 | Export/import, Auto Backup rules, reminders, accessibility, performance | 1.5 |
| 6 | Device setup, keystore, install on family phones, real-use fixes | 1 |
| | **Total** | **≈ 13.5 weeks full-time** |

**Range: 10–14 weeks full-time**, or roughly **5–7 months at 10–12 hours a week**, which is the more likely shape for a personal project. [ASSUMPTION A-21 — tell me if the available time is very different, since it changes how the phases should be sliced.]

**Dogfooding still starts at the end of Phase 2 (~week 5.5)** and matters more here than it did in the public plan, not less: your household *is* the entire user base, so there is no such thing as premature feedback. Get it onto your own phone the day logging works, and onto a family member's phone as soon as the dashboard does.

---

*Continue to [Part I — Product](./01-product.md), or return to the [index](./README.md).*
