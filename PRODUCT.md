# Product

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

## Users

The author and 2–3 other family members in one household, each on their own phone (Android and iPhone both present in the household). No public users, no distribution beyond this household.

## Product Purpose

Nourishly is a private nutrition and hydration tracker: log daily food and water intake, track macro/micronutrients, and surface daily, weekly, and monthly health insights. Built for the author's own household to log real home cooking, not as a public product.

## Positioning

What a generic calorie tracker could not truthfully copy:

- **Regional-first food catalog.** ~1,613 curated dishes covering Gujarati, Tamil Nadu, Karnataka, and pan-Indian/everyday-North cooking, defined as recipes over ingredients rather than copied composition tables.
- **Nutrients are derived, never transcribed.** Every dish's nutrient values are computed from USDA FoodData Central ingredient data through the catalog pipeline — no hand-entered or recalled numbers ever enter the system.
- **Honesty over completeness.** Unknown nutrient data is shown as unknown, never assumed zero (AP-4); the score withholds itself when coverage is too thin rather than presenting a falsely complete number (§21.5).
- **Zero infrastructure, by design.** No backend, no accounts, no sync — ever. Local profiles (one `owner_id` per family member) replace accounts at a fraction of the complexity; each person's data lives and stays on their own device.

## Operating Context

- Sideloaded Flutter app (not distributed through any app store), installed directly on family members' own Android and iOS phones.
- Android: self-signed APK via a keystore the author generates and must back up (losing it blocks in-place upgrades and forces a data-losing reinstall).
- iOS: free Apple provisioning, refreshed via AltStore + AltServer running on the household Mac when phones are on the same Wi-Fi; an iPhone away from that network for 7+ days stops opening until it returns.
- No internet dependency for core use — catalog is bundled on-device; barcode scanning (and any network food lookup) is deferred.
- Backup is platform-native (Android Auto Backup, iOS device/iCloud backup) for user data, plus manual JSON/CSV export-import with UUID-based merge, with the ~20–40 MB catalog explicitly excluded from both.
- Real usage scene: logging home-cooked regional meals through the day, checking the dashboard, reviewing weekly/monthly reports.

## Capabilities and Constraints

In scope (v1.0): food search/recents/favourites/custom foods, meal templates, four meal slots + custom categories, serving + quantity, back-dating, copy meal/day; multi-ingredient household recipes with cooking yield; water logging (quick-add, custom amounts, derived target, history); 5 macros + saturated fat + sugar + 17 micronutrients where data exists; per-person derived targets with manual overrides; daily dashboard, daily/weekly/monthly reports; 2–4 local profiles per install with fully separated data and a shared catalog/recipes; local reminders (water, meal, end-of-day); dark mode, dynamic type, screen reader support.

Permanently out of scope: any backend, API, or hosting; accounts/sign-in/sync; DPDP-style compliance programme or privacy policy (personal/domestic use only, no third party ever receives data); store listings or analytics/crash-reporting SDKs.

Deferred (not deleted, may return): barcode scanning (and with it, any Open Food Facts dependency); Health Connect / HealthKit; Hindi localisation.

Explicitly undecided as of docs/architecture/00-scope.md rev 0.3 (2026-09-09), §0.8 — confirm before building the affected surface:
- Hindi (or another) localisation — a household preference, not yet asked.
- Whether anyone under 18 will use the app — changes which RDA reference values apply.
- Manual-targets-only mode — should-have, intended to be built alongside the targets screen.

The nutrition review packet (§0.6) and ADR-010 sign-off on the scoring model are still outstanding; scoring weights are versioned data so this does not block building.

## Brand Commitments

Name: **Nourishly**. Design system: **Indigo** (`docs/design/tokens/nourishly-indigo.json`), chosen over four other candidates (Haldi, Neem, Kora, Nilgiri) for staying legible under dense numeric data while keeping a point of view. App logo at `assets/nourishly_app_logo.png`, used to generate all platform launcher icons via `flutter_launcher_icons`.

Binding design rules already decided (source of truth, not to be re-litigated in visual work):
- Bars read against a target (tick at 100%, track runs to 125%), never filled to an edge.
- Over-target is never alarming — a violet, not red; red is reserved for destructive actions.
- Status is never colour alone — always a dot plus a label (NFR-A-04).
- Unknown nutrient data is shown as unknown, never zero.
- The score explicitly withholds itself when coverage is too thin, stating the coverage percentage.
- Energy shows remaining, not consumed, as the large number.
- Tabular figures throughout so numbers align.

## Evidence on Hand

- `docs/design/README.md`, `docs/design/decisions.md`, `docs/design/tokens/nourishly-indigo.json`, `docs/design/prototype.html` — the Indigo design system and 13 approved screen decisions (prototype awaiting final approval; treat as the incumbent visual authority, not yet formalised as DESIGN.md).
- `docs/catalog/README.md` and `docs/catalog/*.md` — the ~1,613-item regional food catalog specification.
- `docs/architecture/` (Parts I–XI) — full pre-implementation architecture and design document; Part 0 (`00-scope.md`) supersedes its scope/roadmap/risk sections and is authoritative.
- No testimonials, case studies, press, pricing, or external customer evidence exist or will — this is a private, undistributed household app; do not fabricate any.

## Product Principles

1. **Honesty over completeness.** Never show a nutrient as zero when it's actually unknown; never present a score built on too little data as complete.
2. **Derive, don't transcribe.** Every nutrient value traces back to sourced ingredient data run through the pipeline — no hand-entered or recalled numbers.
3. **Zero infrastructure, permanently.** No backend, accounts, or sync; the device is self-sufficient, and simplicity for four known users beats generic public-product patterns.
4. **Built for this household, not a market.** Regional food coverage, recipe curation, and every trade-off are scoped to who actually uses this app, not a general audience.
5. **The Indigo system and its 13 approved screens are decided facts, not a proposal.** Visual work builds on them; changing them is a deliberate redesign decision, not a byproduct of a feature.

## Accessibility & Inclusion

Dark mode, dynamic type/font scaling, and screen reader support are in scope for v1.0 (NFR-A-04 family). Status must never be conveyed by colour alone — always paired with a dot and a text label. No formal accessibility standard (e.g. WCAG level) has been specified beyond these product-level rules.
