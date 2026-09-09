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

**Resolved: both platforms are supported. You have a Mac, which makes iOS viable.** One correction and one distribution plan.

**Correction — Android APKs cannot be unsigned.** Android refuses to install an unsigned APK. What you want is a **self-signed** APK using a keystore you generate yourself: free, permanent, no Google involvement, no fees, ever.

> **⚠️ Back up that keystore the day you create it, in two places, one off the build machine.** A self-signed APK can only be upgraded in place by an APK signed with the same key. Lose it and the only way to install a new build is to uninstall first — **which deletes the app's local data**. Over a multi-year personal project, keystores get lost with old laptops. This is the highest-probability data-loss path in the whole design (R-26).

### iOS distribution plan

Free Apple provisioning profiles expire after **7 days**. That is a hard constraint and it cannot be paid around without the $99/year membership you've ruled out. Having a Mac at home makes it manageable:

| Approach | How it works | Verdict |
|---|---|---|
| **AltStore + AltServer on the home Mac** | AltServer runs on the Mac; AltStore is installed on each iPhone. When an iPhone is on the same Wi-Fi as the Mac, the app **refreshes automatically in the background** before it expires | **Recommended.** Reduces the weekly ritual to "the Mac is on and everyone is home", which for a family is normal |
| **Xcode direct install** | Rebuild and redeploy from Xcode every 7 days, per device (wireless pairing avoids cables) | Fallback, and what you'll use for your own device while developing |
| Pay $99/year | Profiles last a year | Ruled out |

**The caveat to plan around:** if an iPhone is away from the home Mac's network for more than 7 days — a trip, a long stay elsewhere — the app stops opening until it returns. Not a bug you can fix; just something the household should know. Android has no equivalent limitation.

### What the free Apple account costs us in features

Free provisioning cannot use entitlement-gated capabilities. Checked against the actual v1.0 scope:

| Capability | Free account | Impact on this project |
|---|---|---|
| **Local notifications** | ✅ Available — no push entitlement needed | **Reminders work fully.** This was the one that mattered |
| Camera | ✅ | Barcode possible if ever wanted |
| Background app refresh | ✅ | Fine |
| Device backup of app data | ✅ | See below |
| HealthKit | ❌ Requires paid membership | None — health integration already deferred (§0.3) |
| App Groups | ❌ | None — home-screen widgets already deferred |
| Push notifications | ❌ | None — never used; notifications are local |
| iCloud (as an entitlement) | ❌ | None — see backup below |

**Nothing in the v1.0 scope is lost.** The deferred features were already deferred for other reasons, which is a fortunate alignment rather than a plan.

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
| **Backup** | Platform backup on both OSes (Android Auto Backup, iOS device backup) with the catalog excluded, plus manual JSON/CSV export and import (§0.5) |
| **Catalog** | Bundled: ~5–8k USDA generic items + **~330 curated Gujarati, Tamil, Kannadiga and pan-Indian foods** — see the [catalog specification](../catalog/README.md). Rebuilt and reinstalled when you want to update it |
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
| Barcode scanning | **Deferred, not deleted.** Reconsider once real logging shows how much packaged food the household eats — likely little, for home cooking. Deferring it also removes the Open Food Facts dependency entirely, which is what makes the public repo safe (§0.7) |
| Health Connect / Apple Health | Health Connect is feasible on Android; **HealthKit is not available on a free Apple account** (§0.2). Deferred — and if it is ever wanted, it would be Android-only unless the membership is bought |
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

Three mechanisms, chosen so that each platform's own backup does the routine work and a portable file covers everything else.

**1. Platform backup — automatic, free, no user effort, both platforms**

| Platform | Mechanism | Entitlement needed |
|---|---|---|
| **Android** | Auto Backup to the user's own Google Drive | None |
| **iOS** | App data in `Documents/` and `Library/Application Support/` is included in the device's iCloud or Finder backup | **None** — this is ordinary device backup, not the iCloud entitlement the free account lacks |

One design detail makes both work properly:

> **Store user data where it is backed up, and mark the food catalog replica as excluded from backup.** On Android, backup rules include the user-data tables and exclude the catalog file. On iOS, set the catalog file's "exclude from backup" resource flag. The catalog is 20–40 MB, identical on every device, and rebuildable from the bundled asset — backing it up would blow Android's per-app quota and bloat every iCloud backup for nothing. User data is a few MB a year and fits comfortably.

This covers the common case — new phone, restore, everything is there — on both platforms with zero user effort.

**2. Manual export / import — explicit, portable, verifiable**

- Full JSON export (re-importable) and CSV export (readable in a spreadsheet).
- Written to a location the user chooses: Drive, Files, email to self, or a laptop.
- **Import merges by UUID**, so importing into a fresh install restores everything, and importing an older export alongside newer data does not duplicate.
- **Reconcile per-entity counts before reporting success.** An import that silently drops rows is a data-loss bug wearing a success message. This rule is inherited from the account-migration design (§17.10), which is the one useful thing that survived it.
- This is also the answer to the keystore risk in §0.2, and to an iPhone that has been away from the Mac too long and needs a fresh install.

**3. A periodic export prompt** — monthly, dismissible, never nagging. With no server, an occasional gentle reminder is the entire disaster-recovery strategy, and it costs one screen.

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

## 0.7 Decisions from the second round — all questions closed

| # | Question | Answer | Consequence |
|---|---|---|---|
| Q-26 | Devices and Mac? | **Mac, iPhone and Android all at home. Support both platforms.** | iOS is in scope. AltStore-on-the-Mac distribution plan (§0.2). Nothing in the v1.0 scope is lost to free provisioning |
| Q-27 | Health conditions? | **None currently; manual targets wanted as an enhancement** | Manual-targets-only mode moves to should-have (§0.3). Per-nutrient overrides (FR-U-05) remain must-have and cover most of the need |
| Q-28 | Repo visibility? | **Public, catalog data included** | Resolved cleanly — see below. R-29 closes |

### Why the public repo is no longer a licensing problem

The earlier caution (R-29) assumed the catalog would draw on Open Food Facts, whose ODbL share-alike terms attach to redistributing a database. **Two things changed that:**

1. **Barcode scanning is deferred (§0.3), so Open Food Facts is not needed at all.** It exists in the design to resolve packaged products; a household cooking Gujarati, Tamil and Kannadiga food logs very few. Dropping it removes the only share-alike dependency in the plan.
2. **Regional dishes are specified as recipes over ingredients, not as copied composition tables** (§0.2 of the catalog specification). Nutrients are computed from **USDA FoodData Central**, which is US Government **public domain** — no licence, no attribution requirement, no restriction on redistribution, commercial or otherwise.

So the catalog becomes: public-domain ingredient data + our own recipe compilations + our own serving-weight measurements. **All of it is safe to commit to a public MIT-licensed repository.**

**The one rule to keep:** derive, don't transcribe. Building a dish from ingredient composition is our own work. Bulk-copying a published composition table verbatim would not be, regardless of where it goes. The catalog pipeline is designed around derivation anyway (§19.7), so this costs nothing — and it is the reason the design is in a better legal position now than when it planned to use more sources.

## 0.8 Remaining open items

None block work.

| Item | Status |
|---|---|
| **Nutrition review** (ADR-010) | Packet to be produced before Phase 3 (§0.6). The only thing still needing outside expertise |
| Hindi, or another language | Ask the household; strings are externalised so it stays cheap |
| Anyone under 18 using it | If yes, growth-stage RDA values differ from adult ones — tell me and I'll extend the reference tables |
| Manual-targets-only mode | Should-have; build it when the targets screen is built, since that is when it is nearly free |

## 0.9 Revised effort estimate

| Phase | Work | Weeks |
|---|---|---|
| 0 | Decisions, catalog/search spike, nutrient registry and RDA tables | 0.5 |
| 1 | Foundation: modules, schema, `nutrition_core`, design system, navigation | 2 |
| 2 | Catalog pipeline, household curation, search, food and water logging | 3 |
| 3 | Profiles, targets, daily summaries, scoring, insights, dashboard | 3 |
| 4 | Daily/weekly/monthly reports, recipes | 2.5 |
| 5 | Export/import, Auto Backup rules, reminders, accessibility, performance | 1.5 |
| 6 | Keystore, AltStore/AltServer setup, install on family phones, real-use fixes | 1.5 |
| | **Total** | **≈ 14 weeks full-time** |

**Range: 11–15 weeks full-time**, or roughly **5–7 months at 10–12 hours a week**, which is the more likely shape for a personal project. [ASSUMPTION A-21 — tell me if the available time is very different, since it changes how the phases should be sliced.]

**Dogfooding still starts at the end of Phase 2 (~week 5.5)** and matters more here than it did in the public plan, not less: your household *is* the entire user base, so there is no such thing as premature feedback. Get it onto your own phone the day logging works, and onto a family member's phone as soon as the dashboard does.

---

*Continue to [Part I — Product](./01-product.md), or return to the [index](./README.md).*
