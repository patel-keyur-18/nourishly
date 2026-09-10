# food_catalog

No screens of its own — it's consumed by `food_logging`'s search (§27.4)
and by `reports`/`dashboard` when they need food details. Empty in Phase 1;
the catalog pipeline and search UI are Phase 2 (§0.9).

Kept as its own feature module per §12.3/§14.4 rather than folded into
`food_logging`, because reports and templates will need it too — "if two
features need a type, it belongs in the shared domain package; a feature
other screens depend on stays its own module" (§14.4).
