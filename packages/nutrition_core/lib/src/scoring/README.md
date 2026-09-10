# Scoring

Deliberately empty in Phase 1.

The composite score, sub-score weights, and exclusion rules (§21) are
**content**, not code (AP-6) — and per [§0.6/§0.8 of the scope
document](../../../../../docs/architecture/00-scope.md), the weights and
curves stay `Proposed` (ADR-010) until the nutrition review packet is
reviewed. Implementing them ahead of that review would mean guessing at
values this project has explicitly deferred to an outside check.

This package is where `DailyScore`/`ScoreComponent` computation lands in
Phase 3, once §21's weights are no longer provisional.
