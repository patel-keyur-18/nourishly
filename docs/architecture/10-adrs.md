# Part X — Architecture Decision Records

*Section 32 · [Back to index](./README.md)*

---

## 32. Architecture Decision Records

**Status after the personal-use review (rev 0.3).** ADR-001 through ADR-004 and ADR-008 through ADR-009 are **Accepted** and unchanged. **ADR-005 and ADR-007 are superseded** by the no-backend decision — retained for reference. **ADR-006 is revised to "no backend, permanently."** **ADR-010 remains Proposed** pending nutrition review (§0.6).

*Superseded status note from the first review:* ADR-001 and ADR-006 are **Accepted** (ADR-006 revised — the backend now ships at launch). ADR-002 through ADR-005 and ADR-007 through ADR-009 are **Accepted** on the reviewer's instruction to proceed with the recommendations. **ADR-010 remains Proposed pending nutrition-professional review** (Q-6) — it is the one decision that should not be locked without outside expertise.

Each ADR records context, the options weighed, the decision, its rationale, the trade-offs accepted, and what it implies for the future.

| ADR | Decision | Confidence |
|---|---|---|
| [ADR-001](#adr-001--cross-platform-technology-flutter) | Flutter for the client | **Decided** — Q-15 closed |
| [ADR-002](#adr-002--mobile-architecture-feature-first-modular-clean-architecture) | Feature-first modular Clean Architecture | High |
| [ADR-003](#adr-003--local-database-sqlite-via-drift) | SQLite via Drift | High |
| [ADR-004](#adr-004--offline-first-strategy-local-source-of-truth) | Local source of truth, offline-first | Very high |
| [ADR-005](#adr-005--synchronisation-strategy-outbox--delta-pull-with-domain-aware-merge) | Outbox + delta pull, domain-aware merge | ⛔ **Deferred** — nothing to sync (§0.4) |
| [ADR-006](#adr-006--backend-strategy-no-backend-revised-twice) | **Revised twice:** no backend, permanently | **Decided** (rev 0.3) |
| [ADR-007](#adr-007--authentication-strategy-guest-first-no-signup-wall) | Guest-first, no signup wall | ⛔ **Superseded** — local profiles, no accounts (§0.4) |
| [ADR-008](#adr-008--food-nutrition-data-owned-curated-catalog-from-open-sources) | Owned curated catalog from open sources | High, one legal dependency |
| [ADR-009](#adr-009--reporting-materialised-daily-summaries-on-demand-periods) | Materialised dailies, on-demand periods | High |
| [ADR-010](#adr-010--nutrition-scoring-capped-weighted-sub-scores-with-coverage-gating) | Capped weighted sub-scores with coverage gating | Medium — **still needs expert review (Q-6)** |

---

### ADR-001 — Cross-platform technology: Flutter

**Context.** The product must ship on iOS and Android, be built and maintained by a solo developer, work fully offline, present substantial custom data visualisation, and share one numeric domain implementation across platforms. Full evaluation in §11.

**Options considered.** Flutter · React Native + Expo · Kotlin Multiplatform (with Compose MP or two native UIs) · fully native (SwiftUI + Compose) · PWA/Capacitor.

**Decision.** **Flutter**, on the stable channel, with Dart 3. *(Confirmed by the reviewer, 2026-09-09. Q-15 is closed and this decision is final for v1.0.)*

**Rationale.**
1. Flutter owns its rendering pipeline, so the bespoke, animated, accessible charts that constitute this product's signature UI are implemented once and behave identically on both platforms. For a chart-heavy app this is a compounding advantage over the product's whole life.
2. One language and one toolchain gives the best solo-developer throughput of the options that also satisfy the shared-domain requirement.
3. A pure-Dart `nutrition_core` package guarantees a single implementation of the calculation and scoring rules — the requirement that eliminates fully-native outright.
4. Drift/SQLite gives a first-class offline story with typed SQL, migrations, reactive queries, and FTS5.
5. Excellent performance on mid-range Android, which is the target device profile for the initial market.

**Trade-offs accepted.**
- No OTA updates: every fix waits for store review. Mitigated by strong pre-release testing, staged rollouts, and a remotely-toggleable config for risky features.
- iOS platform-native feel requires deliberate effort rather than coming free.
- Smaller library ecosystem and talent pool than JS/TS.
- Some native-capability plugins are community-maintained; mitigated by the port/adapter boundaries (§14.6).

**Future implications.** Committing to Flutter forecloses cheap code reuse with a React web app. If a web client becomes a priority, the options are Flutter Web (adequate for an app-like surface, poor for a marketing/SEO site) or a separate web implementation with the calculation rules re-implemented against the golden vectors (§20.3) — which is precisely why those vectors exist.

**Reversal condition — now closed.** The decision was taken with the four reversal conditions (developer TypeScript fluency, a near-term web app, business-critical OTA hot-fixing, a native-integration-dominated roadmap) explicitly on the table. None applies. Flutter is final for v1.0.

The one forfeited capability that needs an active substitute is OTA hot-fixing: it is replaced by staged rollouts plus a remotely-toggleable configuration delivered through the catalog delta channel, which — now that the catalog channel ships at launch (ADR-006 revised) — is available from day one. That was not true under the staged plan, so this decision is better supported now than when it was made.

---

### ADR-002 — Mobile architecture: feature-first modular Clean Architecture

**Context.** The app must stay maintainable for years under a single developer, must keep calculation logic independently testable and portable, and must accommodate a roadmap that adds substantial subsystems (sync, barcode, AI, health integration) without destabilising what already works.

**Options considered.** MVVM + repositories with no explicit domain layer · layer-first Clean Architecture · **feature-first modular Clean Architecture** · full DDD with aggregates and domain events · a single-store Redux-style architecture.

**Decision.** **Feature-first modules, each internally layered (presentation → application → domain ← data), with shared `nutrition_core`, `nourishly_domain`, `nourishly_data`, `nourishly_sync`, and `nourishly_ui` packages.** Riverpod for DI and state. Selected DDD concepts (value objects, one clear aggregate boundary, a documented ubiquitous language) where they earn their place; no event bus, no repositories-per-aggregate ceremony.

**Rationale.**
1. Feature-first keeps a change local to one directory; layer-first spreads every change across four.
2. The domain layer isolates the product's core intellectual asset — the calculation and scoring rules — so it can be tested in milliseconds without a device, database, or widget harness.
3. A pure-Dart domain is portable to a server or a future client if ever needed.
4. Package boundaries make the "domain imports nothing" rule mechanically enforceable in CI (NFR-M-02) rather than a convention that erodes.
5. Riverpod provides compile-time-safe DI without a service locator and without coupling the domain to `BuildContext`.

**Trade-offs accepted.**
- More boilerplate than a direct MVVM approach: mappers between DTOs, entities, and view models.
- More initial setup than a single-package app.
- Requires discipline: the value evaporates if the layering rule is not enforced — hence the CI lint.

**Future implications.** Adding sync, barcode, or AI features means adding an adapter behind an existing port rather than reshaping the app. If a second developer joins, module boundaries give a clean division of work.

---

### ADR-003 — Local database: SQLite via Drift

**Context.** The device holds the authoritative copy of user data plus a ~30k-item food catalog. Required: fast full-text search (< 120 ms), efficient nutrient aggregation, reactive queries driving the UI, transactional multi-row writes, and safe schema migration over a multi-year lifetime.

**Options considered.** SQLite via Drift · SQLite via `sqflite` (raw SQL) · Isar · Hive · ObjectBox · Realm.

**Decision.** **SQLite, accessed through Drift.**

**Rationale.**
1. The workload is fundamentally relational: sum nutrient values grouped by nutrient, filtered by date range, joined to targets. SQL expresses this directly; document stores require either denormalisation or in-memory fan-out.
2. FTS5 provides the offline search performance the product needs, with no additional dependency.
3. Drift adds compile-time-checked queries, generated type-safe models, a first-class migration framework, and reactive `Stream` queries that feed Riverpod directly — the mechanism behind the single state path in §14.5.
4. SQLite is the most battle-tested embedded database in existence, with excellent crash-safety guarantees (NFR-R-02).
5. Ships a pre-built catalog file as a bundle asset trivially (§16.4).

**Why not the alternatives.**
- **Realm** was rejected outright: Atlas Device Sync's deprecation makes its main differentiator a liability.
- **Isar** is fast and pleasant but is effectively single-maintainer and weaker at relational aggregation — an unacceptable dependency risk for the app's core storage over a multi-year horizon.
- **Hive** has no query engine; every aggregation would be in-memory.
- **ObjectBox** is capable but its sync offering is commercial and its model less standard.
- **Raw `sqflite`** would work but discards type safety, migration tooling, and reactive queries for no benefit.

**Trade-offs accepted.** Code generation in the build; a learning curve; a schema that must be migrated carefully as the model evolves.

**Future implications.** Standard SQLite means the export path, any desktop tooling, and any future server-side representation all speak the same model. Migrations must be forward-tested against populated databases (NFR-R-03) — non-negotiable given that the local database is the source of truth.

---

### ADR-004 — Offline-first strategy: local source of truth

**Context.** Logging happens in restaurants, transit, and buildings with poor signal. Any dependency on connectivity in the logging path is a direct threat to the product's core habit loop.

**Options considered.**
- **A. Online-first with a cache** — server authoritative, local cache for reads.
- **B. Offline-capable** — works offline in a degraded mode, syncs on reconnect.
- **C. Offline-first with a local source of truth** — all reads and writes local; network is purely for durability and multi-device.

**Decision.** **Option C.** The local SQLite database is authoritative for user-generated data. The server is a replica.

**Rationale.**
1. Matches actual usage: the moments of highest logging intent are often the moments of worst connectivity.
2. It is an architectural guarantee rather than a feature: `LogFoodUseCase` has no network dependency, so a connectivity error in the logging path is structurally impossible (NFR-O-02).
3. Every read is local, so performance is uniform and independent of network conditions (NFR-P-01…07).
4. It makes the backend optional to *capability* rather than load-bearing: the app is complete without it, and the server adds durability and reach rather than function.
5. It is the strongest privacy property the product has: with no account, data never leaves the device (PR-1).
6. A backend outage leaves the app fully working and merely not syncing. Backend incidents are P2 — the property that makes solo operation of production infrastructure viable (§13.5).

**Trade-offs accepted.**
- Device loss while in guest mode means data loss. Mitigated by account-based sync from launch (ADR-006 revised) and by account-free local export, and stated honestly to users rather than glossed over.
- Sync becomes genuinely harder than in a server-authoritative model — the client must reconcile rather than accept. Addressed by ADR-005 and by modelling choices that make most conflicts impossible.
- The catalog must be bundled, increasing app size.

**Future implications.** Every future feature must respect this. Any feature that cannot work offline (AI parsing, barcode lookup of unknown products) must degrade gracefully to a manual path that always works, never block the user.

---

### ADR-005 — Synchronisation strategy: outbox + delta pull with domain-aware merge

> **⛔ Superseded in rev 0.3 — no synchronisation is built.** There is nothing to sync between: each family member's data lives on one device and is never shared (§0.4). What survives from this ADR is narrow but real: **UUIDv7 primary keys, `updated_at`, and `deleted_at` tombstones are retained**, because import-merge on restore needs exactly those properties. The outbox, cursors, `server_revision`, conflict policies and device registry are not built. The analysis below stands if the scope ever widens.

**Context.** The product must synchronise a local source of truth across devices from its first release, tolerating long offline periods, partial failures, lost acknowledgements, and untrustworthy device clocks, without ever losing or duplicating a user's data.

**Options considered.**
- **A. Full state replacement** — upload/download everything. Simple; unusable at scale and destructive on conflict.
- **B. Naive timestamp LWW on all entities** — one global rule. Simple; produces silent data loss on additive data (the "water total went backwards" class of bug).
- **C. Full CRDTs** — mathematically conflict-free. Correct but heavy: significant metadata overhead and complexity for a single-user, mostly-single-writer domain.
- **D. Outbox + cursor-based delta sync with per-entity merge policies** ✅
- **E. Operational transform** — designed for collaborative text editing; wrong problem shape entirely.

**Decision.** **Option D**, with these specifics:
- Client-generated **UUIDv7** primary keys.
- **Outbox** written in the same transaction as every mutation.
- **Pull before push**, cursor-based on a server-assigned monotonic `server_seq`; the cursor advances in the same transaction as the applied batch.
- **Idempotency keys** on every pushed item.
- **Per-entity conflict policies** (§17.6), the most important of which is that **water logs are modelled as immutable additive rows** so their merge is conflict-free by construction.
- **Soft deletes** with a 180-day tombstone window and a full-resync directive for devices beyond it.
- Exponential backoff with jitter; a dead-letter table so a poison item cannot block the queue.

**Rationale.**
1. The outbox makes the sync queue durable, observable, and retryable, and removes any need to scan the database for changes.
2. Same-transaction outbox writes make the change and the intent to sync atomic — the property that turns best-effort sync into exactly-once-effective sync.
3. Modelling water as immutable rows rather than a mutable daily counter eliminates the single most likely conflict in the product without any CRDT machinery. **This modelling choice does more for sync correctness than any algorithm would.**
4. Domain-aware policies handle the remaining cases correctly: delete beats edit (resurrecting a deleted entry is worse than losing an edit); effective-dated records are append-only and never merged; derived data is not synced at all.
5. Server-assigned sequence numbers make ordering independent of untrustworthy device clocks.

**Trade-offs accepted.**
- More implementation complexity than naive LWW — an estimated 2–3 weeks, now on the pre-launch critical path rather than in a later phase.
- Tombstones consume storage and require a purge job.
- LWW still loses one side of a genuine concurrent edit; retained in a local conflict log for 30 days for diagnostics rather than prompting the user, since asking a single user to adjudicate their own edit is bad UX.

**Future implications.** The schema must carry UUID keys, timestamps, tombstones, `owner_id`, and sync-state columns from the very first migration. This was the load-bearing prerequisite that made ADR-006's reversal a sequencing change rather than a redesign — and it remains mandatory, because these columns cannot be retrofitted onto a populated production database without pain.

---

### ADR-006 — Backend strategy: no backend *(revised twice)*

> **Status: Accepted (revised 2026-09-09, rev 0.3).** This decision has been taken three times as the scope changed. Rev 0.1 proposed a sync-ready model with the backend deferred to a second phase. Rev 0.2 moved the backend into the first release on the reviewer's instruction to ship the complete application. **Rev 0.3 removes it permanently**, because the product is a private household app for 2–3 family members with no distribution. Both superseded versions are summarised below, because the reasoning is what makes the final answer defensible rather than merely convenient.

**Context.** Nourishly is used by the author and 2–3 family members, on their own phones, with no public distribution, no revenue, and an explicit constraint of no paid services or infrastructure of any kind (§0.1). Each person tracks their own food; **no data is shared between them.**

**Options considered.**
- **A. Managed backend with accounts and sync** *(rev 0.2's decision)*. Provides cross-device sync, cloud backup, account recovery, over-the-air catalog updates. Rejected now: it costs ~7 weeks and ongoing money and operations to solve problems this deployment does not have. There is no multi-user data to share, and a household of four does not need account recovery.
- **B. Free-tier hosted backend.** Rejected: free tiers pause inactive projects, change terms, and require an account and monitoring. It reintroduces an operational dependency to buy very little.
- **C. Self-hosted backend on a home machine.** Rejected: a device that must stay powered and reachable is worse than no server, and dramatically worse than a file.
- **D. No backend. Local storage only, with backup by platform auto-backup and file export.** ✅ **Chosen.**

**Decision.** **No backend, permanently.** SQLite on the device is the only store. Backup is (1) Android Auto Backup to each person's own Google Drive, configured to include user data and exclude the rebuildable catalog replica, and (2) explicit JSON/CSV export and import that merges by UUID (§0.5). Local switchable profiles replace accounts (§0.4). Catalog updates arrive by rebuilding and reinstalling the app, which the author controls anyway.

**Rationale.**
1. **The requirements a backend would satisfy do not exist here.** No sharing between users, no account recovery, no cross-user features, no distribution channel needing a server. Building one would be answering questions nobody asked.
2. **Backup — the one genuine need — is solved better without a server.** Android Auto Backup is automatic, free, and stores data in the user's own Drive rather than in a database the author would be responsible for. A file export is portable, inspectable, and outlives any service.
3. **It eliminates the entire class of risks that dominated rev 0.2**: sync correctness (R-6), guest→account migration data loss (R-5), production operations (R-21), live compliance obligations (R-22), and infrastructure cost (R-23). Five risks removed by deleting code rather than by mitigating it.
4. **The architecture already assumed this.** Because ADR-004 made the device the source of truth, removing the server removes work without removing capability. Nothing in the calculation, scoring, reporting, or UX design changes at all. **This is the strongest retrospective evidence that ADR-004 was correct** — a design that had leaned on the server would now need rewriting.

**Trade-offs accepted.**
- **No automatic cross-device sync.** A person using both a phone and a tablet must export and import. Judged acceptable: rare in this deployment, and the merge-by-UUID import makes it correct when it happens.
- **Backup on iOS is weaker than on Android**, since there is no equivalent of Auto Backup under the app's control. File export is the fallback, and it is the reason the export prompt exists (§0.5).
- **Catalog corrections require a rebuild and reinstall.** Trivial for an author-built app; it was only a burden when a store release stood in the way.
- **Losing the Android signing keystore means uninstall-and-reinstall, which destroys local data.** This is now the single most likely data-loss path in the whole design (R-26). Mitigated by keystore backup and by the export habit.

**Future implications.** If the scope ever widens to public distribution, this ADR reverts to rev 0.2's analysis, and the work is largely additive — UUID keys, timestamps, and tombstones are retained precisely so that path stays open (§0.4). What is *not* retained is the outbox, cursor, and device-registry machinery: keeping unused sync infrastructure in a four-user app would be exactly the over-engineering this document argues against throughout.

### ADR-007 — Authentication strategy: guest-first, no signup wall

> **⛔ Superseded in rev 0.3 — there are no accounts.** With no backend there is nothing to authenticate against. Local switchable profiles replace this entirely (§0.4). The one durable contribution of this ADR is the `owner_id` column it argued for: designed for guest→account migration, it now provides per-profile data separation for free, which is a neater outcome than the one it was designed for.

**Context.** Requiring registration before first use is among the largest avoidable drop-offs in consumer apps. But accounts are needed for backup and multi-device use.

**Options considered.** Account required upfront · account required after N days · **guest-first with optional accounts** · device-identity-only (no accounts ever).

**Decision.** **Guest-first.** Full functionality, forever, with no account. Optional accounts — available from the first release — via Sign in with Apple, Google Sign-In, and email OTP. No passwords.

**Rationale.**
1. The first-run experience should reach the first logged food in under 90 seconds; an account wall makes that impossible.
2. It is also the strongest privacy position available: no account means no server-side personal data at all (PR-1).
3. Accounts sold on benefit — "back up and use on another phone" — convert better and generate less resentment than accounts imposed as a toll.
4. **Email OTP over passwords**: no password storage, no reset flow, no credential-stuffing exposure, and no user-remembered secret. The security and support benefits are substantial and the UX is at least as good.
5. **Sign in with Apple is mandatory on iOS** if any third-party sign-in is offered (App Store guideline 4.8), so it is a requirement rather than a choice.
6. Keying identity on the provider's stable subject rather than on email is what prevents Apple private-relay address changes from silently orphaning accounts.

**Trade-offs accepted.**
- Guest→account migration is a genuinely hard flow that must be lossless, resumable, and verified (§18.5). It is the highest-consequence flow in the product and needs disproportionate testing.
- Guest users who lose their device lose their data unless they exported.
- Supporting three providers means three integrations and three sets of edge cases.

**Future implications.** The `owner_id` sentinel must exist from the first schema version. Any future feature requiring server identity (family sharing, dietician access) must degrade gracefully for guests rather than forcing an upgrade.

**Interaction with ADR-006 as revised.** Because sync now ships at launch, guest→account migration is live from the first release and is the modal path into an account rather than a later special case. It carries no prior period of local-only operation in which to find its bugs, which is why R-5 is a Critical risk and why §18.5's verification step (reconcile per-entity counts before claiming success) is a hard requirement rather than a refinement.

---

### ADR-008 — Food nutrition data: owned curated catalog from open sources

**Context.** Food data determines whether every number in the product is right, and whether users can log what they actually eat. The initial market is India, where generic international databases perform poorly.

**Options considered.** Commercial nutrition API (Nutritionix, Edamam, FatSecret, Spoonacular) · public data only (USDA FDC, Open Food Facts) · fully user-generated · **owned curated catalog built from open sources plus manual Indian curation** · a hybrid with a commercial API as the primary source.

**Decision.** **Own the catalog.** Build it offline from public-domain and open-licensed sources, add a hand-curated Indian tier of 1,500–2,500 items with correct household measures, bundle it in the app, and update it by over-the-air delta from the first release. Keep a `FoodDataProvider` port so third-party providers can be added later as *enrichment*, never as a dependency.

**Rationale.**
1. **Most commercial nutrition APIs prohibit persistent local caching. Offline-first requires it. They are architecturally incompatible** — this single constraint, not cost, is decisive (§19.3).
2. USDA FoodData Central is public domain, downloadable in bulk, and has the deepest micronutrient coverage available — the right backbone for generic ingredients.
3. Open Food Facts (ODbL) covers packaged goods and barcodes globally, with growing Indian coverage.
4. The curated Indian tier is the product's actual differentiator. No automated pipeline turns "dal" into *Dal tadka (toor), 1 katori (150 g)*; that requires human curation, and accepting that cost is the correct call.
5. Owning the catalog means owning quality: provenance, quality tiers, completeness metadata, and the QA gates that catch unit errors and zero-vs-null encoding — all of which feed the coverage gating in ADR-010.
6. No per-request cost, no rate limits, no vendor dependency in the critical path.

**Trade-offs accepted.**
- **3–4 weeks of manual curation** — the largest single non-engineering cost in the plan and the biggest scope risk (§33, R-1).
- ~~The catalog ages between releases.~~ **No longer a trade-off:** delta updates ship at launch (ADR-006 revised), so the catalog improves continuously. This is the clearest benefit the full-application decision delivers to this ADR, and it lowers R-1.
- Bundling adds 25–45 MB to the app.
- A legal dependency: Indian food-composition source licensing must be verified before use ([OPEN Q-1]). Fallback if it cannot be cleared: build the Indian tier from USDA ingredient data plus published dish compositions, with an explicit accuracy caveat.
- ODbL share-alike obligations for Open Food Facts data must be understood and complied with ([OPEN Q-2]).

**Future implications.** The catalog becomes a durable asset that improves with use — failed searches and custom-food creation frequency directly prioritise the curation queue (§31.6). The `FoodExternalRef` table makes barcode support a query rather than a new subsystem. The `kind` discriminator on `FoodItem` makes recipes an extension rather than a redesign.

---

### ADR-009 — Reporting: materialised daily summaries, on-demand periods

**Context.** The app must present daily, weekly, and monthly reports, computed on-device, remaining correct under edits, back-dated logging, target changes, and scoring-rule changes.

**Options considered.** All on demand · all pre-computed and stored (including weekly/monthly as entities) · TTL-cached · **materialise daily, aggregate periods on demand**.

**Decision.** **Materialise daily summaries on write with explicit invalidation. Compute weekly and monthly on demand from those daily rows. Cache only in memory, for the current view.**

**Rationale.**
1. Read/write ratios differ by an order of magnitude across periods. Today's summary is read on every dashboard render and every edit; a monthly report is read less than once a day.
2. Once daily summaries exist, a weekly report aggregates 7 rows and a monthly report 31. Materialising those would save microseconds and add a second staleness surface — a bad trade.
3. Invalidation is precise and cheap: a write marks exactly one date stale, with no cascade.
4. Report cost is bounded by period length rather than total history, which is what makes NFR-SC-01 hold and keeps a ten-year user's experience identical to a ten-day user's.
5. Tagging each summary with its `ruleset_version` makes scoring-rule changes detectable and lazily recomputable, rather than silently inconsistent.

**Trade-offs accepted.**
- Invalidation logic must be correct; a missed stale-mark shows a wrong number. Mitigated by centralising invalidation in the repository layer and testing it directly.
- Derived rows consume storage (~500 KB/year — negligible).
- A new device must recompute summaries after its first sync; a one-time background cost.

**Future implications.** Because summaries are fully rebuildable, changing the scoring rules is safe: mark stale, recompute lazily. Materialising weekly/monthly can be added later if a use case ever demands it, without changing the model.

---

### ADR-010 — Nutrition scoring: capped weighted sub-scores with coverage gating

**Context.** Users cannot judge raw nutrient numbers (P-3), so the product needs a compressed signal. But a score in a health context risks implying precision the data lacks, inviting gaming, encouraging restriction, and being read as a medical verdict.

**Options considered.** Simple goal-completion percentage · an adapted published index (HEI, NRF, Nutri-Score-like) · **weighted capped sub-scores with asymmetric curves** · a learned/ML score · no score at all.

**Decision.** A **Daily Nourishment Score (0–100)** composed of five visible sub-scores (energy adherence, macro balance, micronutrient coverage, limit nutrients, hydration), each computed from a nutrient-appropriate curve (range / floor / ceiling / plateau), **capped at 100**, weighted by the user's goal, and aggregated with a bounded minimum-component dampener. **Scoring is gated on data coverage and day completeness**, and the composite is fully dismissible.

**Rationale.**
1. Capping every sub-score removes the incentive to game: 3× protein cannot offset zero fibre.
2. Range targets on energy mean under-eating lowers the score exactly as over-eating does — there is no path where restriction improves the number (§21.8).
3. **Coverage gating is the key correctness property.** Sparse micronutrient data treated as zeros is why nutrition apps report deficiencies that do not exist. Refusing to score below 60% coverage, and saying so, is the honest behaviour.
4. Full decomposition makes the score explainable and auditable — the user can see exactly what produced it (FR-D-03), which is what makes it trustworthy rather than arbitrary.
5. The minimum-component dampener stops one catastrophic component hiding behind four good ones, while capping the penalty at 15% so the score stays stable and non-punitive.
6. Rejected alternatives: published indices are population- and cuisine-calibrated and not personalised, which is the opposite of what the product promises; an ML score has no ground truth, cannot be explained, and would create implied health claims with no evidential basis.

**Trade-offs accepted.**
- **The weights are a considered judgement, not evidence.** [ASSUMPTION A-7] They require review by a qualified nutrition professional before launch — stated plainly rather than dressed up as science.
- More complex to implement and explain than a simple percentage.
- Coverage gating means some users see "insufficient data" instead of a score, which is less satisfying and correct.
- Any change to weights or curves changes historical scores; handled by ruleset versioning and honest disclosure (§25.7).

**Future implications.** Because curves, weights, and thresholds are data under a `ruleset_version` (AP-6), the scoring model can evolve without a code change and with full historical traceability. If expert review substantially changes the weights, it is a data change plus a lazy recompute, not a rewrite. A published diet-quality index could later be added as a *secondary* metric alongside the personalised score.

---

*Continue to [Part XI — Risks, Assumptions, Open Questions, and Roadmap](./11-risks-roadmap.md).*
