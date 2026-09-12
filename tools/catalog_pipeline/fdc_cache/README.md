# FDC response cache

Committed FoodData Central responses, written by
`bin/fetch_catalog.dart` and read back by every later run.

```
index.json          query -> fdcId + description, sorted. Start here.
search/<sha1>.json  the id list one search returned
food/<fdcId>.json   the trimmed detail record (four fields, no portions,
                    no input foods, no lab methods)
```

**Why it is committed.** Without it the catalog seed is not reproducible
from this repository — it is reproducible from this repository *plus
whatever FDC's search ranks today*. FDC re-ranks. A cached search freezes
each match as a decision somebody reviewed, so a USDA-side change arrives
as a diff you accept rather than one that happens to you.

Redistribution is fine: FDC is US Government public domain, the same basis
[scope §0.7](../../../docs/architecture/00-scope.md) already relies on.

**No API key is in here, or can be.** Cache keys hash the canonical query
parameters, never the request URL — the URL is the only place `api_key`
appears.

## Modes

```
dart run tools/catalog_pipeline/bin/fetch_catalog.dart --cache-only
dart run tools/catalog_pipeline/bin/fetch_catalog.dart --refresh-missing   # default
dart run tools/catalog_pipeline/bin/fetch_catalog.dart --refresh-all
```

`--cache-only` needs no key and no network: a miss is reported by name
rather than guessed at. That is how CI and an offline editor validate the
catalog.
