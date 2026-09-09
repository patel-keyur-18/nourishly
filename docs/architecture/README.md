# Nourishly — Software Architecture & Product Design Document

**Status:** Draft for review · **Version:** 0.1 · **Date:** 2026-09-09
**Author:** Architecture & design exercise (pre-implementation)
**Scope:** Design and architecture only. No implementation, scaffolding, or migrations exist yet and none should be created until this document is reviewed and finalized.

---

## How to read this document

This is a single logical document split across files for reviewability. The 37 sections requested are numbered continuously across the parts; each file header states the sections it contains.

| Part | Sections | File |
|---|---|---|
| I — Product | 1–10 | [`01-product.md`](./01-product.md) |
| II — Technology Selection | 11–12 | [`02-technology.md`](./02-technology.md) |
| III — System & Mobile & Backend Architecture | 13–15 | [`03-system-architecture.md`](./03-system-architecture.md) |
| IV — Offline, Sync, Auth | 16–18 | [`04-offline-sync-auth.md`](./04-offline-sync-auth.md) |
| V — Food Data, Nutrition Calculation, Scoring | 19–21 | [`05-food-and-nutrition.md`](./05-food-and-nutrition.md) |
| VI — Data Model, ERD, API Domains | 22–24 | [`06-data-model.md`](./06-data-model.md) |
| VII — Reporting & Analytics | 25 | [`07-reporting.md`](./07-reporting.md) |
| VIII — UX, Screens, Navigation, Notifications | 26–29 | [`08-ux.md`](./08-ux.md) |
| IX — Privacy, Security, Scalability | 30–31 | [`09-privacy-scalability.md`](./09-privacy-scalability.md) |
| X — Architecture Decision Records | 32 | [`10-adrs.md`](./10-adrs.md) |
| XI — Risks, Assumptions, Open Questions, Roadmap | 33–37 | [`11-risks-roadmap.md`](./11-risks-roadmap.md) |

## Section index

1. Executive Summary — Part I
2. Product Vision — Part I
3. Goals and Objectives — Part I
4. User Problems Being Solved — Part I
5. User Personas — Part I
6. Core User Journeys — Part I
7. Functional Requirements — Part I
8. Non-Functional Requirements — Part I
9. MVP Scope — Part I
10. Future Scope — Part I
11. Cross-Platform Technology Evaluation — Part II
12. Recommended Technology Direction — Part II
13. High-Level System Architecture — Part III
14. Mobile Application Architecture — Part III
15. Backend Architecture — Part III
16. Offline-First Architecture — Part IV
17. Synchronization Strategy — Part IV
18. Authentication Strategy — Part IV
19. Food and Nutrition Data Strategy — Part V
20. Nutrition Calculation Architecture — Part V
21. Nutrition Performance and Scoring Design — Part V
22. Data Model — Part VI
23. Entity Relationship Diagram — Part VI
24. API Domain Design — Part VI
25. Reporting and Analytics Architecture — Part VII
26. UX Information Architecture — Part VIII
27. Screen and Feature Design — Part VIII
28. Navigation Design — Part VIII
29. Notification Architecture — Part VIII
30. Privacy and Security Considerations — Part IX
31. Scalability Considerations — Part IX
32. Architecture Decision Records — Part X
33. Risks — Part XI
34. Assumptions — Part XI
35. Open Questions — Part XI
36. Recommended MVP Roadmap — Part XI
37. Recommended Next Steps Before Implementation — Part XI

## Document conventions

- **[ASSUMPTION]** — a decision made in the absence of a stated requirement. Every assumption is repeated in §34 so it can be confirmed or overturned in one pass.
- **[OPEN]** — an unresolved question. Every one carries a *recommended default* so design and implementation are never blocked waiting for an answer. Collected in §35.
- **[RISK]** — collected in §33.
- **MVP / Post-MVP / Future** — release classification, defined in §9 and §10.
- Requirement IDs are stable (`FR-*`, `NFR-*`, `ADR-*`) and should be referenced by implementation tickets.

## The five decisions that shape everything else

If a reviewer reads nothing else, read these. Each is defended in the ADR named.

1. **Flutter** for the client (ADR-001). One codebase, one rendering model, one language, strong offline + charting story, best solo-developer throughput.
2. **SQLite (Drift) as the on-device source of truth** (ADR-003). Reads and writes never wait on a network. The server is a replica, not the authority, for user-generated logs.
3. **Nutrient values are snapshotted onto every log entry at the moment of logging** (ADR-008, §20.5). Correcting a food's data in the catalog must never silently rewrite a user's history.
4. **Nutrition targets are effective-dated and versioned** (§20.4). Changing your goal today must not re-score last month.
5. **The daily score is a transparent composite of capped sub-scores, and refuses to score what it cannot measure** (ADR-010, §21). Sparse micronutrient data is the single largest source of misleading nutrition conclusions; the design treats "unknown" as a first-class state instead of as zero.

## Non-goals of this document

- It does not specify screen pixel layouts, component libraries, or a visual design system beyond the principles in §27.
- It does not select a specific chart library, CI provider, or crash reporter. Those are implementation-phase choices constrained, not decided, here.
- It does not constitute legal or regulatory advice. §30 flags where counsel is required.
