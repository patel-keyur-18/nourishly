# Nourishly

A cross-platform nutrition and hydration tracking app that helps users monitor daily food and water intake, track nutrients, and gain meaningful daily, weekly, and monthly health insights.

> **Status: design phase, revision 0.3.** No implementation exists yet. Implementation begins only once the design is finalised.
>
> **Scope: a private tracker for one household — 2–3 family members, self-built and sideloaded. No servers, no accounts, no public distribution.**
>
> Decided: **Flutter** for the client, **SQLite on-device as the only store**, and **no backend of any kind**. Three questions remain open — see [Part 0 §0.7](./docs/architecture/00-scope.md#07-what-i-still-need-from-you).

## Documentation

**→ [Part 0 — Personal-Use Scope](./docs/architecture/00-scope.md)** — start here. The authoritative scope statement.

**→ [Full Architecture & Design Document](./docs/architecture/README.md)** — index for all parts.

**→ [Food Catalog Specification](./docs/catalog/README.md)** — ~365 Gujarati, Tamil, Kannadiga and pan-Indian foods with household serving weights and ingredient recipes.

A complete pre-implementation design covering product scope, cross-platform technology selection, system and mobile architecture, offline-first design, food-data strategy, the nutrition calculation and scoring model, the data model, reporting, UX and navigation, privacy, architecture decision records, risks, and a phased roadmap. Sections on backend, authentication, synchronisation, API design, and scalability are retained as reference but are **not built** in the current scope.

| Part | Sections | |
|---|---|---|
| **0** | — | [**Personal-Use Scope**](./docs/architecture/00-scope.md) |
| I | 1–10 | [Product](./docs/architecture/01-product.md) |
| II | 11–12 | [Technology Selection](./docs/architecture/02-technology.md) |
| III | 13–15 | [System Architecture](./docs/architecture/03-system-architecture.md) |
| IV | 16–18 | [Offline, Sync, Auth](./docs/architecture/04-offline-sync-auth.md) |
| V | 19–21 | [Food Data, Calculation, Scoring](./docs/architecture/05-food-and-nutrition.md) |
| VI | 22–24 | [Data Model, ERD, API Domains](./docs/architecture/06-data-model.md) |
| VII | 25 | [Reporting & Analytics](./docs/architecture/07-reporting.md) |
| VIII | 26–29 | [UX, Screens, Navigation](./docs/architecture/08-ux.md) |
| IX | 30–31 | [Privacy & Scalability](./docs/architecture/09-privacy-scalability.md) |
| X | 32 | [Architecture Decision Records](./docs/architecture/10-adrs.md) |
| XI | 33–37 | [Risks, Open Questions, Roadmap](./docs/architecture/11-risks-roadmap.md) |

## Licence

[MIT](./LICENSE)
