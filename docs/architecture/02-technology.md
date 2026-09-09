# Part II — Technology Selection

*Sections 11–12 · [Back to index](./README.md)*

---

## 11. Cross-Platform Technology Evaluation

### 11.1 What this app actually demands of a framework

Generic framework comparisons are useless. The evaluation below is scored against *this* product's real technical demands, derived from Part I:

| # | Demand | Origin |
|---|---|---|
| D1 | A capable embedded relational database with fast full-text search over ~30k rows and reactive queries | NFR-P-03, §19.5 |
| D2 | Heavy, correct, testable numeric domain logic shared across platforms | TO-2, §20 |
| D3 | Rich, custom data visualisation: progress rings, target-marked bars, trend lines, all theme- and accessibility-aware | §27.11 |
| D4 | Long, smooth scrolling lists (search results, day breakdowns, monthly views) on mid-range Android | NFR-P-08 |
| D5 | Camera + barcode, local notifications, health-platform integration — **all in the first release**; widgets and watch (v1.1) | §9.1 |
| D6 | Reliable background sync scheduling | NFR-E-02 |
| D7 | Fast iteration by **one developer**, indefinitely | TO-7 |
| D8 | Low long-term maintenance burden: few dependencies, slow churn, predictable upgrades | NFR-M-* |
| D9 | Pixel-consistent UI across both platforms so one design and one set of tests suffice | §27 |
| D10 | Small app size and low cold-start cost on low-end devices | NFR-P-01, NFR-P-09 |

Notably absent: real-time collaboration, 3D/graphics-heavy rendering, deep platform-UI conformance, and a web target. Their absence removes the usual strongest arguments for native and for React Native respectively.

### 11.2 Options considered

#### Option A — Flutter (Dart)

**Fit for demands**

- *D1:* Excellent. `sqlite3`/Drift give typed queries, migrations, transactions, reactive `Stream` queries, and direct access to SQLite's FTS5. Drift is mature and actively maintained.
- *D2:* Excellent. Pure-Dart packages compile identically on both platforms; the calculation core can be a dependency-free package with fast, headless unit tests (no device, no widget harness).
- *D3:* Best in class. Flutter renders everything itself via its own compositor, so custom painting (`CustomPainter`) is a first-class, high-performance path rather than a fallback. Rings, target-marked bars, and animated transitions are straightforward and behave identically on both OSes.
- *D4:* Excellent. Sliver-based lazy lists are a core competency; AOT-compiled Dart avoids a JS-bridge cost per frame.
- *D5:* Good. `mobile_scanner`, `flutter_local_notifications`, `health`/Health Connect plugins all exist and are widely used. Some are community-maintained — a real but bounded risk, mitigated by the port/adapter boundaries in §14.
- *D6:* Good. `workmanager`/platform-channel integration with WorkManager and BGTaskScheduler.
- *D7:* Excellent. One language, one toolchain, hot reload, exceptionally good "batteries included" story. Least context-switching of all options.
- *D8:* Very good. First-party ownership of framework + UI + rendering means fewer moving parts than the RN ecosystem; upgrades are generally mechanical.
- *D9:* Best in class *by construction* — Flutter does not delegate to platform widgets, so there is one rendering result.
- *D10:* Acceptable. Engine adds roughly 5–8 MB per architecture; comfortably inside NFR-P-09. Cold start is good with AOT.

**Costs**

- UI does not automatically inherit platform-native look and feel; matching iOS conventions requires deliberate effort (Cupertino widgets, platform-aware navigation transitions).
- Dart has a smaller talent pool and a smaller general-purpose library ecosystem than JS/TS — relevant if the project later grows beyond a solo developer.
- Text rendering and accessibility are Flutter's own implementations; they are good, but occasionally diverge from platform behaviour in edge cases and must be tested explicitly (NFR-A-02).
- No code reuse toward a web app of production quality (Flutter Web is real, but is a poor fit for a content/SEO web presence).

#### Option B — React Native + Expo (TypeScript)

**Fit for demands**

- *D1:* Good. `expo-sqlite` and `op-sqlite` are solid; `op-sqlite` in particular is fast and supports FTS5. WatermelonDB offers a batteries-included offline-sync-oriented layer, though it imposes its own model.
- *D2:* Good. TypeScript with a strict configuration is expressive; the calculation core can be a plain TS package. Numeric determinism is fine, but JS's single number type means more discipline around integer/decimal handling than Dart's typed alternative.
- *D3:* Adequate to good. Requires `react-native-skia` (which is, essentially, adopting Flutter's rendering approach as a library) or `react-native-svg` + Reanimated for high-quality custom charts. Achievable, but with more dependency surface and more per-platform verification.
- *D4:* Good with the New Architecture (Fabric/JSI/Hermes); the historical bridge bottleneck is largely resolved. Still requires more attention on low-end Android than Flutter.
- *D5:* Excellent. Expo modules cover camera, barcode, notifications, and more, with a coherent config-plugin system. This is RN's strongest advantage for this product.
- *D6:* Good. `expo-background-task`/`expo-task-manager`.
- *D7:* Excellent, and arguably better than Flutter for a TypeScript-native developer. Expo's managed workflow and EAS Build remove a large amount of native-toolchain pain.
- *D8:* Mixed. The strongest single differentiator: **EAS Update (OTA)** lets a solo developer ship a JS-layer fix in minutes instead of waiting on App Store review — genuinely valuable for a one-person team. Against it: a larger and faster-churning dependency graph; upgrades historically more painful, though much improved with Expo SDK's coordinated releases.
- *D9:* Good but not free. RN maps to platform primitives, so consistency requires effort and per-platform testing; text metrics, shadows, and list behaviour differ.
- *D10:* Acceptable; comparable order of magnitude to Flutter.

**Costs**

- Two rendering realities to verify instead of one — for a chart-heavy product, this is a recurring tax.
- More dependencies means more supply-chain and maintenance surface (NFR-S-09, NFR-M-*).
- Achieving Flutter-grade custom visuals means adopting Skia anyway, at which point the framework's "native widgets" advantage is partly forfeited.

#### Option C — Kotlin Multiplatform (+ Compose Multiplatform)

**Fit for demands**

- *D1:* Excellent. SQLDelight is arguably the best typed-SQL layer of any option; Kotlin's data modelling is strong.
- *D2:* **Best in class.** Kotlin's type system, sealed hierarchies, and `kotlin.time`/`BigDecimal`-equivalent handling make a nutrition domain core a pleasure to write and test. Shared business logic is KMP's core value proposition and it delivers.
- *D3:* Compose Multiplatform on iOS is now stable-ish but is the least mature of the three UI stacks, especially for text, accessibility, and scroll physics on iOS. The alternative — shared logic + two native UIs (SwiftUI + Compose) — doubles the UI work, which is exactly the cost a solo developer cannot absorb.
- *D4:* Excellent on Android; iOS depends on which UI strategy is chosen.
- *D5:* Excellent if writing native integrations per platform; that is also more work.
- *D6:* Excellent (native APIs directly).
- *D7:* **Weakest.** Highest setup complexity, longest build times, most toolchain friction, and — if two native UIs are chosen — roughly 1.6–1.8× the UI effort.
- *D8:* Good; JetBrains backing is solid and the ecosystem is maturing quickly.
- *D9:* Depends entirely on the UI choice: Compose MP gives consistency, two native UIs give divergence by design.
- *D10:* Good.

**Verdict:** KMP is the technically most elegant option for the *domain layer* and the least suitable for a solo developer shipping a UI-heavy consumer app in Q1. Its sweet spot is a team with existing native iOS and Android expertise wanting to unify business logic — the opposite of this project's constraints.

#### Option D — Fully native (SwiftUI + Jetpack Compose)

- Best possible platform integration, accessibility, performance, and access to new OS features on day one.
- Two codebases, two languages, two test suites, two release pipelines, and — most damaging — **two independent implementations of the nutrition calculation and scoring engine**, which is precisely the code that must not diverge (TO-2). Keeping them consistent would require a shared spec plus duplicated golden tests, and drift would be silent and harmful.
- Realistically 1.8–2.2× the effort for feature parity.
- **Rejected** for this project. It would be the right answer for a funded team where deep platform integration (widgets, Live Activities, watch apps, HealthKit depth) is the core value proposition. Here it is not.

#### Option E — Web/PWA wrapper (Capacitor / Ionic)

Evaluated and rejected quickly: PWA offline storage on iOS is subject to eviction, background sync support is inconsistent, and chart-and-list performance on mid-range Android in a WebView will not meet NFR-P-08. The offline-first requirement (NFR-O-01) alone disqualifies it.

### 11.3 Comparison matrix

Weights reflect this product's demands. Scores 1–5.

| Criterion | Weight | Flutter | RN + Expo | KMP | Native ×2 |
|---|---|---|---|---|---|
| Solo-developer throughput (D7) | 5 | 5 | 5 | 2 | 1 |
| UI consistency across platforms (D9) | 4 | 5 | 3 | 4 | 1 |
| Custom visualisation quality (D3) | 4 | 5 | 4 | 3 | 5 |
| Offline/local DB capability (D1) | 5 | 5 | 4 | 5 | 5 |
| Shared, testable domain logic (D2) | 5 | 5 | 4 | 5 | 1 |
| Performance on mid-range Android (D4) | 4 | 5 | 4 | 5 | 5 |
| Native integrations, present + future (D5) | 3 | 4 | 5 | 5 | 5 |
| Long-term maintainability (D8) | 4 | 4 | 3 | 4 | 3 |
| Ecosystem maturity & hiring pool | 2 | 4 | 5 | 3 | 5 |
| App size & cold start (D10) | 2 | 4 | 4 | 4 | 5 |
| OTA fix capability | 2 | 2 | 5 | 2 | 1 |
| **Weighted total (max 200)** | | **180** | **161** | **156** | **125** |

The matrix is a communication device, not the decision. The decision rests on three qualitative points, below.

### 11.4 Why the matrix lands where it does

**1. This is a chart-and-list app with a numeric core.** Flutter's owning of the render pipeline turns the hardest recurring UI work — bespoke, animated, theme-aware, accessible data visualisation that looks identical on both platforms — from a per-platform verification tax into a single implementation. Over hundreds of small chart and layout changes across the product's life, this compounds more than any other factor.

**2. The domain logic must not diverge, ever.** Any option that produces two implementations of the scoring engine is disqualified (rules out D). Options A, B, and C all satisfy this; A and C do so with stronger static typing than B.

**3. Solo-developer throughput is the binding constraint.** This eliminates C and D on effort grounds regardless of their technical merits. Between A and B, throughput is close to a tie, so the tiebreakers are consistency (A) and OTA updates plus native-module breadth (B) — and for a chart-heavy, offline-first product, consistency wins.

### 11.5 The case for React Native — evaluated and closed

> **DECIDED IN REVIEW (2026-09-09): Flutter. Open question Q-15 is closed and this section is retained as a record of what was weighed, not as a live option.**

React Native + Expo was a defensible alternative, and would have been the better answer if **any** of the following had held:

1. **The developer is materially more productive in TypeScript than in Dart.** Framework advantages are smaller than developer-fluency advantages. This single factor outweighs the entire matrix above.
2. **A web application is on the roadmap within 12 months.** Shared TS domain logic between React Native and a React web app is a large, real win that Flutter cannot match.
3. **Rapid OTA hot-fixing is judged business-critical.** EAS Update is a genuine operational advantage for a one-person team, subject to the platforms' rules on what may be updated out of band.
4. **The roadmap becomes dominated by deep native integrations** (widgets, watch, Live Activities), where Expo's module ecosystem and config plugins reduce friction.

None held, and the framework decision is now final. The one condition worth restating, because it is the only thing that would have overturned the analysis: **developer fluency outweighs every row of the matrix above.** That was considered and settled in favour of Flutter.

The two capabilities forfeited by this decision — over-the-air JS updates and code reuse with a React web app — are addressed as follows: OTA is replaced by staged rollouts plus a remotely-toggleable configuration delivered with catalog deltas (§12.5); web reuse is replaced by the versioned calculation specification and golden vectors (§20.3), which make a second implementation verifiable rather than guesswork.

---

## 12. Recommended Technology Direction

### 12.1 Recommendation

> **Build Nourishly with Flutter, using a feature-first modular Clean Architecture, SQLite (Drift) as the on-device source of truth, and Supabase as the managed backend — live at first release.** *(ADR-001, ADR-002, ADR-003, ADR-006 revised)*

*Both halves are now decisions rather than proposals: Flutter was confirmed in review, and the backend was moved into the first release.*

### 12.2 Recommended stack

| Layer | Choice | Why | Alternatives considered |
|---|---|---|---|
| Client framework | **Flutter (stable channel)** | §11.4 | RN+Expo, KMP, native |
| Language | **Dart 3** (sound null safety, sealed classes, pattern matching, records) | Sealed hierarchies model nutrient/target/score states precisely | — |
| State management & DI | **Riverpod** | Compile-time-safe DI without a service locator; testable providers; no `BuildContext` dependency in the domain; good async/stream ergonomics | Bloc (more ceremony, good for large teams), `provider` (weaker), GetX (rejected: encourages architecture violations) |
| Local database | **SQLite via Drift** | Typed SQL, migrations, reactive streams, transactions, FTS5, direct aggregate SQL for daily rollups | Isar (fast but single-maintainer risk and weaker relational aggregation), Hive (no query engine), ObjectBox (licensing/sync model), Realm (**rejected — Atlas Device Sync is deprecated**) |
| Full-text search | **SQLite FTS5** with a custom tokenizer configuration and a transliteration column | Offline, fast at 30k rows, no extra dependency; transliteration column handles "paneer"/"panir" and Devanagari input | Client-side fuzzy libs (slower, no index), remote search (violates NFR-O-01) |
| Key–value / prefs | `shared_preferences` for non-sensitive; `flutter_secure_storage` for tokens (NFR-S-02) | — | — |
| Navigation | **`go_router`** | Declarative, deep-linkable (needed for notification deep links, which ship in v1.0), typed routes | Navigator 2.0 by hand (too costly), auto_route (codegen-heavy) |
| Charts | **Custom `CustomPainter` widgets** for the ring and macro bars; a lightweight chart package (e.g. `fl_chart`) for line/bar trends, wrapped behind an internal `NourishlyChart` API | Bespoke primitives are the product's signature UI and must be accessible; the wrapper means the third-party dependency can be replaced without touching feature code | Adopting a chart library wholesale (loses control of accessibility and theming) |
| Serialisation | `freezed` + `json_serializable` | Immutable models, exhaustive unions, generated equality — essential for a value-object-heavy domain | Hand-written (error-prone at this model size) |
| Backend | **Supabase** — Postgres, GoTrue auth, Row Level Security, Storage, Edge Functions. **Live at first release** | Relational model matches the domain; RLS gives DB-enforced isolation (NFR-S-04); can be self-hosted, so it is an exit-able dependency. With the backend now in scope from day one, the managed-service choice matters more, not less: it is what keeps operations inside a solo developer's capacity (§31.6) | Firebase (NoSQL model is a poor fit for nutrient aggregation; vendor lock-in is harder to exit), custom backend (unjustifiable ops cost), AWS Amplify (heavier) |
| Auth | Supabase Auth + Sign in with Apple + Google Sign-In + email OTP | §18 | — |
| Barcode scanning | `mobile_scanner`, behind the `BarcodeScanner` port | Mature, actively maintained, wraps MLKit/AVFoundation; the port makes replacement a one-file change | ML Kit direct via platform channels (more work, no benefit) |
| Local notifications | `flutter_local_notifications` + `timezone`, behind the `ReminderScheduler` port | Covers scheduling, quiet hours, and reboot rescheduling on both platforms | Server push (unnecessary — nothing in v1.0 requires server-initiated notification) |
| Health platforms | A thin per-platform adapter behind `HealthDataPort` (HealthKit / Health Connect) | Nutrient type mapping and consent differ enough per platform that a shared plugin abstraction leaks; an explicit adapter is clearer and safer for a consent-sensitive surface | A general-purpose health plugin (convenient, but obscures per-platform consent semantics) |
| Localisation | Flutter `intl` + ARB files, English + Hindi at launch | Standard; strings externalised from the first commit | — |
| Analytics | Privacy-preserving, event-only, **no nutrition or health payloads** (NFR-S-05); self-hosted or minimal vendor | Deliberately constrained | — |
| Crash reporting | Sentry with PII scrubbing and a redaction test (NFR-S-08) | — | Firebase Crashlytics (pulls in more Google SDK surface) |
| CI/CD | GitHub Actions + Fastlane (or Codemagic if Actions runner cost becomes an issue) | — | — |

*[ASSUMPTION A-3] Supabase's low tier is adequate through early adoption. Because the backend is now live from launch rather than deferred, the cost begins on day one with no revenue against it — see §31.5 and open question Q-21.*

### 12.3 Package/module layout

Structure is normative; exact names are not. Rationale in §14.

```
nourishly/
├── app/                          # Flutter application shell
│   ├── lib/
│   │   ├── main.dart             # composition root only
│   │   ├── app/                  # routing, theme, localisation, bootstrap
│   │   └── features/             # feature-first modules (§14.4)
│   │       ├── onboarding/
│   │       ├── dashboard/
│   │       ├── food_logging/
│   │       ├── food_catalog/
│   │       ├── water/
│   │       ├── reports/
│   │       ├── goals/
│   │       └── settings/
│   └── test/
├── packages/
│   ├── nutrition_core/           # PURE DART. No Flutter, no I/O.
│   │   ├── units & quantities    # typed units, conversions (§20.6)
│   │   ├── nutrients             # nutrient registry, values, unknown-vs-zero
│   │   ├── targets               # target derivation engine (§20.4)
│   │   ├── aggregation           # entry → daily totals (§20.2)
│   │   ├── scoring               # sub-scores and composite (§21)
│   │   ├── insights              # rule engine (§21.7)
│   │   └── test/golden/          # versioned golden vectors (§20.3)
│   ├── nourishly_domain/         # entities, value objects, repository PORTS
│   ├── nourishly_data/           # Drift DB, DAOs, repository implementations
│   ├── nourishly_sync/           # outbox, sync engine, conflict policy (§17)
│   ├── nourishly_api/            # generated/typed remote client
│   └── nourishly_ui/             # design system: tokens, charts, components
└── tools/
    ├── catalog_pipeline/         # offline ETL for the food catalog (§19.7)
    └── golden_vector_gen/
```

**The load-bearing rule:** `nutrition_core` and `nourishly_domain` must not import Flutter, Drift, or any HTTP client. Enforced in CI by an import lint (NFR-M-02). This is what makes the calculation engine testable in milliseconds, portable to a server if server-side recompute is ever needed, and immune to UI refactors.

### 12.4 What is deliberately *not* adopted

| Not adopted | Why |
|---|---|
| GraphQL | The API is a batch synchronisation surface, not a flexible query surface (§24.5). GraphQL solves a problem this product does not have, and adds a schema layer to maintain |
| A remote feature-flag service | A local config file plus a catalog-delta-delivered config covers it — and this doubles as the kill-switch mechanism that compensates for having no OTA code updates (§12.5) |
| A dependency-injection framework beyond Riverpod | Riverpod is sufficient; a second DI mechanism is pure cost |
| Melos / heavy monorepo tooling | Path dependencies suffice at this size; adopt only if the package count grows |
| A design-system package published externally | Internal package is enough |
| Modular/dynamic feature delivery | App size is well within budget |
| Server-side rendering of reports | Reports are computed on-device from local data (§25) |

### 12.5 Risks of this direction, and mitigations

| Risk | Mitigation |
|---|---|
| Dart/Flutter talent scarcity if the project grows | Domain logic is in pure Dart with a written specification and golden vectors; a rewrite of the *client* would not require re-deriving the *rules* |
| Community plugin abandonment (scanner, notifications, health) | Every native capability sits behind a port in `nourishly_domain` with a thin adapter (§14.6); replacing a plugin touches one file |
| No OTA updates → slow hot-fixes | Strong pre-release testing; staged rollouts; a remotely-toggleable kill-switch config delivered with catalog deltas for risky features |
| Supabase lock-in | Postgres + standard SQL + self-hostable OSS; avoid proprietary features in the hot path; keep all business rules on the client or in plain SQL |
| iOS UI feeling non-native | Adopt platform-adaptive navigation transitions, scroll physics, and haptics deliberately; review against native apps before launch |

---

*Continue to [Part III — System Architecture](./03-system-architecture.md).*
