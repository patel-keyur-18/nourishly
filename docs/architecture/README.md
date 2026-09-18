# Nourishly — Software Architecture & Product Design Document

**Status:** Revised for personal-use scope · **Version:** 0.3 · **Date:** 2026-09-09
**Author:** Architecture & design exercise (pre-implementation)
**Scope:** Design and architecture only. No implementation, scaffolding, or migrations exist yet and none should be created until this document is reviewed and finalized.

> ## ⚠️ Start with [Part 0 — Personal-Use Scope](./00-scope.md)
>
> Revision 0.3 narrowed this from a public product to **a private app for one household — 2–3 family members, sideloaded, no servers, no accounts, no distribution.** Part 0 is the authoritative scope statement and supersedes Parts I–XI wherever they disagree.
>
> The sections covering backend, authentication, synchronisation, API design, compliance, and scalability are **Deferred** — retained as reference, not built.

---

## How to read this document

This is a single logical document split across files for reviewability. The 37 sections requested are numbered continuously across the parts; each file header states the sections it contains.

| Part | Sections | File | Status |
|---|---|---|---|
| **0 — Personal-Use Scope** | — | [**`00-scope.md`**](./00-scope.md) | **Authoritative** |
| I — Product | 1–10 | [`01-product.md`](./01-product.md) | Current, scope per Part 0 |
| II — Technology Selection | 11–12 | [`02-technology.md`](./02-technology.md) | Current |
| III — System & Mobile Architecture | 13–15 | [`03-system-architecture.md`](./03-system-architecture.md) | Current; **§15 deferred** |
| IV — Offline, Sync, Auth | 16–18 | [`04-offline-sync-auth.md`](./04-offline-sync-auth.md) | **§16 current; §17–18 deferred** |
| V — Food Data, Calculation, Scoring | 19–21 | [`05-food-and-nutrition.md`](./05-food-and-nutrition.md) | Current |
| VI — Data Model, ERD, API Domains | 22–24 | [`06-data-model.md`](./06-data-model.md) | Current; **§24 deferred** |
| VII — Reporting & Analytics | 25 | [`07-reporting.md`](./07-reporting.md) | Current |
| VIII — UX, Screens, Navigation | 26–29 | [`08-ux.md`](./08-ux.md) | Current |
| IX — Privacy, Security, Scalability | 30–31 | [`09-privacy-scalability.md`](./09-privacy-scalability.md) | **Largely N/A** — see Part 0 |
| X — Architecture Decision Records | 32 | [`10-adrs.md`](./10-adrs.md) | Current |
| XI — Risks, Assumptions, Open Questions | 33–37 | [`11-risks-roadmap.md`](./11-risks-roadmap.md) | **Superseded by Part 0** for scope and roadmap |

## Section index

1. Executive Summary — Part I
2. Product Vision — Part I
3. Goals and Objectives — Part I
4. User Problems Being Solved — Part I
5. User Personas — Part I
6. Core User Journeys — Part I
7. Functional Requirements — Part I
8. Non-Functional Requirements — Part I
9. v1.0 Launch Scope — Part I *(see Part 0)*
10. Future Scope — Part I
11. Cross-Platform Technology Evaluation — Part II
12. Recommended Technology Direction — Part II
13. High-Level System Architecture — Part III
14. Mobile Application Architecture — Part III
15. Backend Architecture — Part III *(deferred)*
16. Offline-First Architecture — Part IV
17. Synchronization Strategy — Part IV *(deferred)*
18. Authentication Strategy — Part IV *(deferred)*
19. Food and Nutrition Data Strategy — Part V
20. Nutrition Calculation Architecture — Part V
21. Nutrition Performance and Scoring Design — Part V
22. Data Model — Part VI
23. Entity Relationship Diagram — Part VI
24. API Domain Design — Part VI *(deferred)*
25. Reporting and Analytics Architecture — Part VII
26. UX Information Architecture — Part VIII
27. Screen and Feature Design — Part VIII
28. Navigation Design — Part VIII
29. Notification Architecture — Part VIII
30. Privacy and Security Considerations — Part IX
31. Scalability Considerations — Part IX *(not applicable)*
32. Architecture Decision Records — Part X
33. Risks — Part XI
34. Assumptions — Part XI
35. Open Questions — Part XI
36. Recommended v1.0 Roadmap — Part XI *(see Part 0.8)*
37. Recommended Next Steps Before Implementation — Part XI

## Document conventions

- **[ASSUMPTION]** — a decision made in the absence of a stated requirement. Every assumption is repeated in §34 so it can be confirmed or overturned in one pass.
- **[OPEN]** — an unresolved question. Every one carries a *recommended default* so design and implementation are never blocked waiting for an answer. Collected in §35.
- **[RISK]** — collected in §33.
- **v1.0 / v1.1 / v2 / Future** — release classification, defined in §9 and §10. (Revision 0.1 used MVP / Post-MVP; the vocabulary changed when the staged plan was dropped.)
- Requirement IDs are stable (`FR-*`, `NFR-*`, `ADR-*`) and should be referenced by implementation tickets.

## The five decisions that shape everything else

If a reviewer reads nothing else, read these. Each is defended in the ADR named.

1. **Flutter** for the client (ADR-001). One codebase, one rendering model, one language, strong offline + charting story, best solo-developer throughput. **Decided in review; Q-15 is closed.**
2. **SQLite (Drift) as the on-device source of truth** (ADR-003, ADR-004). Nothing ever waits on a network. This is the decision that let the scope collapse from a public product to a household app without redesigning anything (§13.2).
3. **Nutrient values are snapshotted onto every log entry at the moment of logging** (ADR-008, §20.5). Correcting a food's data in the catalog must never silently rewrite a user's history.
4. **Nutrition targets are effective-dated and versioned** (§20.4). Changing your goal today must not re-score last month.
5. **The daily score is a transparent composite of capped sub-scores, and refuses to score what it cannot measure** (ADR-010, §21). Sparse micronutrient data is the single largest source of misleading nutrition conclusions; the design treats "unknown" as a first-class state instead of as zero. *This is the one decision still awaiting outside expertise (Q-6).*

## Revision history

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-09-09 | Initial design document — public product, staged MVP |
| 0.2 | 2026-09-09 | Flutter confirmed; full application at launch |
| **0.3** | **2026-09-09** | **Personal-use scope.** Private household app: no backend, no accounts, no sync, no distribution. See [Part 0](./00-scope.md) |

### Decisions taken in the second review (rev 0.3)

| # | Decision | Effect |
|---|---|---|
| 1 | **Private household app, 2–3 family users, no public distribution** | Backend, accounts, sync, compliance programme, store distribution and scalability all removed. Effort 32–38 weeks → **10–14 weeks** |
| 2 | **No infrastructure of any kind** | ADR-006 reversed to *no backend, permanently*. Backup via platform auto-backup + file export (§0.5) |
| 3 | **No paid platform accounts, ever** | Android self-signed and permanent. **iOS free provisioning expires every 7 days** — the one open problem (§0.2) |
| 4 | **Licensing not required for private use** | Q-1/Q-2 closed. One catch: the GitHub repo is public, so catalog data must stay out of it or the repo goes private (§0.2) |
| 5 | **India region; AI logging deferred** | Q-22, Q-24 closed |

### Decisions taken in the first review (rev 0.2)

| # | Decision | Effect on this document |
|---|---|---|
| 1 | **Flutter confirmed** as the client framework | ADR-001 moves from Proposed to Accepted; open question Q-15 closed; §11.5 retained as a record of what was weighed |
| 2 | **Ship the complete application**, not a staged MVP | **ADR-006 reversed.** Backend, accounts, sync, barcode, recipes, reminders, health-platform integration, monthly reports and Hindi all move into the first release. §9 rewritten as "v1.0 Launch Scope"; §33–37 re-scored and re-planned; runway 14–18 weeks → **32–38 weeks** |
| 3 | **Proceed on the remaining recommendations**, prioritising quality | 16 open questions closed with the recommended defaults (§35); ADR-002–005 and 007–009 accepted. **ADR-010 deliberately left Proposed** pending nutrition-professional review (Q-6) |

**Nine open questions remain, all marked ★ in §35.** They cannot be answered from within the architecture — they need legal enquiry, an external reviewer, or a business decision. The most consequential is **Q-25: is this a personal app or a product for public distribution?** The document assumes the latter (A-20); confirming or correcting that is cheap now and expensive later.

## Non-goals of this document

- It does not specify screen pixel layouts, component libraries, or a visual design system beyond the principles in §27.
- It does not select a specific chart library, CI provider, or crash reporter. Those are implementation-phase choices constrained, not decided, here.
- It does not constitute legal or regulatory advice. §30 flags where counsel is required — and with the backend now shipping at launch, that counsel is a prerequisite for building the backend rather than a pre-launch formality (§30.1, R-22).
