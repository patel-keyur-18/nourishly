# Nourishly

A cross-platform nutrition and hydration tracking app that helps users monitor daily food and water intake, track nutrients, and gain meaningful daily, weekly, and monthly health insights.

> **Status: design phase, revision 0.2.** No implementation exists yet. The architecture and product design are under review; implementation begins only once the design below is finalised.
>
> Decided so far: **Flutter** for the client, and **ship the complete application** (backend, accounts, sync, barcode, recipes, reminders, health integration) in the first release rather than a staged MVP. Nine open questions remain — see [§35](./docs/architecture/11-risks-roadmap.md#35-open-questions).

## Documentation

**→ [Software Architecture & Product Design Document](./docs/architecture/README.md)**

A complete pre-implementation design covering product scope, cross-platform technology selection, system and mobile architecture, offline-first and synchronization design, food-data strategy, the nutrition calculation and scoring model, the data model, reporting, UX and navigation, privacy, architecture decision records, risks, and a phased roadmap.

Start with the index, or jump to the parts:

| Part | Sections | |
|---|---|---|
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
