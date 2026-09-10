/// Nourishly's domain layer: entities, value objects, and repository/service
/// ports (§12.3, §14.3).
///
/// **Pure Dart. No Flutter, Drift, or network imports** — enforced by the
/// `domain` import-lint group in the root `import_lint.yaml`. Data
/// implements these ports; the domain never names a concrete data class
/// (§13.3's dependency rule).
///
/// Entities and most ports arrive alongside the features that need them
/// (§14.4: "if two features need a type, it belongs in the shared domain
/// package"). [ClockPort] ships from Phase 1 because day-boundary logic
/// needs it testable from the first date-handling feature onward (§14.6).
library;

export 'src/ports/clock_port.dart';
export 'src/ports/fake_clock.dart';
export 'src/ports/system_clock.dart';
