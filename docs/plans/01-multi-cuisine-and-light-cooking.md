# Plan — Multi-cuisine catalog, a safe way to keep adding to it, and "our kitchen" light-cooking versions

*Draft 0.3 · 2026-09-12 · awaiting approval · [Catalog spec](../catalog/README.md) · [Food & nutrition](../architecture/05-food-and-nutrition.md) · [Scope](../architecture/00-scope.md)*

> **0.2 → 0.3** — Part A (§6) rewritten against the ~30 dishes you named: nine are already in the app, only six ingredients are missing, and the Punjabi and Indo-Chinese files are cut. Work packages resized.
>
> **0.1 → 0.2** — adds the agreed division of labour (§2), the FDC cache design (§3), a root-cause fix for name collisions with measurements from the committed catalog (§4), and what `cuisineTags` should actually do (§5). Part A and Part B are unchanged in substance and condensed here.

Still nothing implemented. This is the plan to approve or change.

---

## 1. The division of labour

Agreed workflow, and the whole of §2–§4 exists to make it safe:

| Step | Who | Needs network? |
|---|---|---|
| Write new ingredient and dish rows in `docs/catalog/*.md`, plus their ingredient mappings | **Me** | No |
| `parse_catalog --check` — prove the new rows break nothing | **Me** | **No** ← the point of §3 and §4 |
| `fetch_catalog` — resolve against FoodData Central | **You** | Only for genuinely new lookups |
| `build_seed` — regenerate `seed_v1.json` | **You** | No |
| Review the seed diff, commit | **You** | No |

The problem to solve is in the phrase *"without breaking existing ones."* Today the pipeline cannot tell you whether a new row broke an old dish, and in one case it cannot tell you at all — see §4.

---

## 2. Where the code stands, measured

| Fact | Where |
|---|---|
| 408 source rows → 383 foods in the seed: 134 USDA ingredients, **249 recipes**, 25 held for manual review | `app/assets/catalog/seed_v1.json` |
| Every regional dish is already a recipe with a component list | `recipe_components`, 711 rows |
| The pipeline globs `docs/catalog/*.md` — a new file needs no code change | `fetch_catalog.dart:246` |
| **150 distinct ingredient names** are referenced by those recipes; all 150 resolve today | measured |
| **71 of the 150 resolve only via `ingredientAliases`** — the curated map already carries half the load | measured |
| `FoodItems.cuisineTags` exists and **nothing writes it or reads it** | `catalog_tables.dart:20` |
| A user recipe is computed by the same maths as a catalog recipe | `RecipeDao.saveRecipe` |
| A log entry snapshots its nutrients, so edits never rewrite history | `LogEntryNutrients`, §20.5 |

Three properties of the current build that matter for your workflow:

- **`build_seed` mints a fresh random `uuid.v7()` per food on every run.** Regenerating seed v1 therefore rewrites all 2.3 MB — `git diff` shows the whole file changed and you cannot see what actually moved.
- **`fetch_catalog` reads the catalog directory in `listSync()` order**, which is not sorted (`parse_catalog` does sort). Row order in the draft, and so in the seed, can differ between machines.
- **Nothing is cached.** Every run re-fetches ~600 FDC responses over the network.

---

## 3. The FDC response cache

Agreed — and it is worth more than the time it saves.

### 3.1 What it buys

| | Without | With |
|---|---|---|
| Adding 30 Punjabi dishes | ~600 live lookups | ~35 — only the genuinely new ones |
| A run with no API key or no network | impossible | full run from cache |
| Rebuilding the seed a year from now | FDC search ranking has moved; **different foods, silently** | byte-identical |
| CI checking the pipeline | can't | can |

The third row is the real prize. Right now the seed is not reproducible from the repository — it is reproducible from the repository *plus whatever USDA's search returns that day*. A cached search result freezes "Toor dal → FDC 172421" as a reviewed decision instead of a query re-run on faith.

### 3.2 Design

```
tools/catalog_pipeline/fdc_cache/
  index.json                  query + dataType -> fdcId, with fetchedAt
  search/<sha1>.json          the id list one search returned
  food/<fdcId>.json           the detail response, TRIMMED
```

- **Committed to the repository.** USDA FDC is US-Government public domain — the same basis §0.7 of the scope doc already relies on to make this repo public. No licence problem.
- **Trimmed detail responses.** Full FDC records carry portions, input foods and lab methods the normalizer never reads. Keep `fdcId`, `description`, `dataType`, and the `foodNutrients` triples. ~2–5 KB each; ~250 foods ≈ 1 MB.
- **`index.json` is the human-reviewable layer** — one line per query showing what it resolved to, so a reviewer never opens the per-food files.
- **The cache key is the query parameters with `api_key` removed.** The key must never reach the cache, the filenames, or a commit.
- **A `CachingFdcClient` decorator** wrapping the existing `FdcClient` — the client itself does not change, and its API-key hygiene (never in an exception message) is untouched.

### 3.3 Three modes

| Flag | Behaviour | Who uses it |
|---|---|---|
| `--cache-only` *(default in CI)* | Never touches the network. A miss is a reported failure naming the exact query to fetch. | Me, CI |
| `--refresh-missing` *(your normal run)* | Network only for misses. New rows only. | You |
| `--refresh-all` | Re-fetch everything — a deliberate USDA data refresh | Rare, reviewed |

A refreshed entry that changes an existing food's nutrients shows up as a diff in `index.json` and as a `--check` failure (§4.4), so a USDA-side change is something you decide to accept rather than something that happens to you.

---

## 4. Name collisions — the proper fix

### 4.1 What is actually wrong

`CatalogIndex` resolves an ingredient string like `besan` by inference over three tiers: the row's own **name**, then any `Also` **alias**, then the **prefix** before a comma. A key claimed by two rows is dropped rather than guessed.

That rule is sound. The flaw is one level up: **what a name resolves to depends on which other rows exist.** So adding a row anywhere in the catalog can change the meaning of a row you did not touch.

Measured against the committed catalog:

**52 keys are already dropped for ambiguity** — 12 names (`idli`, `upma`, `coconut rice` ×3, `bhakhri`…), 18 aliases (`phulka`, `thayir sadam`, `uppuma`…), 22 prefixes (`dosa` ×5, `rasam` ×4, `rice` ×4, `milk` ×3…). Nothing breaks today only because `ingredientAliases` already names the right row for every ingredient that matters.

**Adding 45 plausible new-cuisine rows** (Punjabi, Kathiyawadi, biryani, Indo-Chinese, Italian, street, pantry) breaks 3 existing ingredient references:

```
'butter'      x4 uses   was -> Butter [01-common]   now ambiguous
'butter oil'  x1        was -> Butter [01-common]   now ambiguous
'2 puri'      x1        was -> Puri   [01-common]   now ambiguous
```

An ingredient that stops resolving makes `fetch_catalog` **drop the entire dish from the seed** and report it in `failures`; `build_seed` prints a warning and builds anyway. So an Italian butter row quietly removes four Gujarati and Kannadiga dishes from your catalog, behind a stderr line.

That one is loud enough to catch. The next one is not:

**Adding four innocuous pantry rows — `Besan`, `Wheat flour`, `Peanuts`, `Toor dal` — silently retargets 63 ingredient references:**

```
'besan'       x20 uses  Besan, gram flour [01]  ->  Besan [11-pantry]
'wheat flour' x18       Wheat flour, atta [01]  ->  Wheat flour [11-pantry]
'peanuts'     x14       Peanuts, raw [01]       ->  Peanuts [11-pantry]
'toor dal'    x11       Toor dal, raw [01]      ->  Toor dal [11-pantry]
```

No failure. No warning. Dozens of dishes recomputed from a different USDA food, shipped under the same `verified` badge. **This is exactly the failure mode §0.3b was written to eliminate** when it deleted the blind FDC search — a name resolving to whatever the machinery happened to pick, rather than to a row someone chose. The tier inference is the same guess, one level up, and it is still in place.

There is a second, visible face of the same cause. **12 display names are duplicated in the shipped seed right now** — search "coconut rice" in the app today and you get three identical rows with nothing to tell them apart (`Coconut rice` ×3, `Idli` ×2, `Upma` ×2, `Bhakhri` ×2, `Curd rice`, `Ghee rice`, `Lemon rice`, `Tomato rice`, `Ragi mudde`, `Ragi rotti`, `Rava idli`, `Akki rotti`). The 45 new rows take that from 12 names to 22.

### 4.2 The fix, in one sentence

**Stop using prose names as identity: give every row a derived stable key, and make every ingredient reference point at a key that a human chose.**

Four layers, in order.

#### Layer 1 — Every row gets a stable key, with no markdown edits

```
key = <file number>:<slug of Food name>        e.g.  01:besan-gram-flour
                                                     03:coconut-rice
                                                     04:coconut-rice
```

I checked: **no file contains two rows with the same name**, so this is globally unique across all 408 rows today with zero edits to any table. The rule CI enforces is the natural one — *names are unique within a file* — and duplicate names **across** files stay legal, because "Coconut rice" genuinely is a Tamil dish and a Kannadiga dish (§0.6 already says regional variants are separate foods).

This key is then:
- the seed's `FoodItems.id`, via `uuid.v5(namespace, key)` — deterministic, so regenerating seed v1 produces a diff you can read instead of 2.3 MB of churn;
- the join key for the lockfile in Layer 3;
- what `build_seed`'s name-based `foodIdByName` map is replaced by, ambiguity handling and all.

#### Layer 2 — Ingredient references resolve through an explicit map only

Rename `ingredientAliases` → `ingredientTargets` and require an entry for **every** distinct ingredient string, pointing at a Layer-1 key:

```dart
'besan':       '01:besan-gram-flour',
'wheat flour': '01:wheat-flour-atta',
'oil':         '01:groundnut-oil',
```

The three-tier inference is **not deleted — it is demoted to a suggestion generator.** `parse_catalog --suggest` prints ready-to-paste lines for every unmapped ingredient, flagging the ambiguous ones for a human decision. Inference helps write the map; it never resolves anything at build time.

The consequence is the one worth having: **adding a row anywhere can no longer change what an existing ingredient means**, because resolution stops depending on what else exists. The coupling is removed, not merely detected.

Cost: the map grows from 72 entries to ~150 now, plus ~60 for the new cuisines. Generated mechanically, reviewed once. 71 of the 150 already go through it, so this is finishing a job that is half done.

#### Layer 3 — A committed resolution lockfile

`docs/catalog/catalog.lock.json`, written by `fetch_catalog`, one entry per row:

```json
"02:gujarati-dal": {
  "name": "Gujarati dal",
  "kind": "recipe",
  "ingredients": { "toor dal": "01:toor-dal-raw", "jaggery": "01:jaggery", "...": "..." },
  "yieldFactor": 1.83,
  "kcalPer100g": 92.4
}
```

This is a golden-file test for food data — the same instinct as the golden nutrient vectors already in Phase 1. `--check` diffs current source against the lock and classifies every change:

| Change | Verdict |
|---|---|
| New key | fine, expected |
| Removed key | must be intentional |
| Same key, **different ingredient target** | ❌ fail — this is the silent retarget |
| Same key, energy moved > 2% | ⚠️ explain it |
| Ingredient mapped to nothing | ❌ fail |

#### Layer 4 — The gate in CI, offline

`parse_catalog --check` runs with **no API key and no network** (it reads the lock and the cache) and fails on: a duplicate name within a file, an unmapped ingredient, a lock retarget, an unexplained nutrient move, or a yield factor outside 0.5×–15×.

That is the mechanism that makes the §1 workflow honest: **I can prove my rows break nothing before you ever run `fetch_catalog`.**

### 4.3 And the duplicate names in search

Not a rename. `Coconut rice` from Tamil Nadu and `Coconut rice` from Karnataka are different dishes and both should appear — the user just needs to tell them apart. That is a display problem, and it is what `cuisineTags` is for (§5.1). Keys stay unique; names need not be.

---

## 5. What `cuisineTags` should actually do

The column exists and is empty. The pipeline has the data for **two** independent axes and has been throwing both away:

- **Cuisine**, from the source file: `gujarati`, `kathiyawadi`, `tamil`, `kannadiga`, `punjabi`, `indo-chinese`, `italian`, `pan-indian`.
- **Course**, from the `## N.` section heading the row sits under: `tiffin`, `farsan`, `sweet`, `bread`, `rice`, `gravy`, `snack`, `beverage`, `pickle`.

Both are free. Ranked by what they are worth:

### 5.1 ★ Disambiguate search results — fixes a bug shipping today
`Coconut rice · Tamil` / `Coconut rice · Kannadiga`. One subtitle line, and the twelve indistinguishable pairs in today's catalog become choosable. This alone justifies populating the column, before any new cuisine lands.

### 5.2 ★ Rank search by what this household actually eats
A Gujarati household typing "dal" should get Gujarati dal first, not dal makhani. Boost by the cuisine mix of the profile's own recent log entries — no configuration, no preference screen, and it gets better the more you use it. Cheap, and it is what keeps a 690-food catalog feeling like a 90-food one.

### 5.3 Browse when search fails
Cuisine chips on the log screen, drilling into course sections. At 383 foods you remember what is in there; at 690 across seven cuisines you do not. UX-6's "custom food is one tap from a failed search" was designed for a small catalog — browse is the other half of that.

### 5.4 Cuisine mix in the monthly report
*"September: 61% Gujarati, 14% Punjabi, 11% Indo-Chinese, 8% Italian, 6% Tamil."* Zero new data — log entries already point at food items. It is the most interesting thing a household tracker can tell you that a public app cannot, because it knows your kitchen rather than a population.

### 5.5 Cuisine against the score — honestly gated
*"Your daily score averages 74 on Gujarati days and 61 on Indo-Chinese days."* Genuinely useful and entirely descriptive of your own logs. Gate it like every other derived claim in this design: no cuisine gets a number until it has enough days behind it, and the card says how many.

### 5.6 Aim the light-cooking feature (§7)
Sort the "make this our version" suggestions by *oil per serving × how often you log it*. From your own list that puts pav bhaji, the parathas, dosa and the sabzis at the top; a chapati has nothing to give back.

### 5.7 What not to do
Do not let a tag infer nutrition — "Italian ⇒ high fat" is exactly the invented number this architecture refuses. Tags describe where a dish is from, never what is in it.

---

## 6. Part A — the catalog expansion, resized against what you actually cook

You named ~30 dishes. I checked every one against the committed catalog. The result changes this section substantially, and in your favour.

### 6.1 Nine of the thirty are already in the app

Loggable today, nothing to add:

| Your dish | Already in the catalog as |
|---|---|
| Chapati | **①** `Rotli / Chapati` [01] |
| Aloo subji | **①** `Potato sabzi, dry` [01] · `Bataka nu shaak` [02] |
| Different types of dosa | Nine rows — **①** plain, **①** masala, ghee roast, rava, onion, set, **①** Mysore masala, **①** uttapam, kuzhi paniyaram |
| Idli | **①** [03] and **①** [04] |
| Rava idli | [03] and [04] |
| Tomato chutney | `Tomato chutney` [03] |
| Upma | `Upma` [01] and [03] · `Uppittu` [04] |
| Poha | **①** `Poha` [02] · `Aval upma` [03] · `Avalakki` [04] |
| Vermicelli, plain | `Semiya upma` [03] · `Shavige bath` [04] |

### 6.2 Only six ingredients are actually missing

The pantry is far better stocked than rev 0.2 assumed. Everything these dishes need already has a row — `Sweet potato`, `Raw banana`, `Spinach`, `Paneer`, `Egg`, `Chana, whole (kabuli)`, `Chawli / Lobia`, `Mint leaves`, `Pumpkin`, `Pav`, `Capsicum`, `Green peas`, `Honey`, `Almonds`, `Cashew`, `Cheese, processed`, `Butter`, `Refined flour, maida`, `Milk`, `Curd` — except these:

| Missing ingredient | Needed by | Note |
|---|---|---|
| **Mushroom** | mushroom subji, mushroom biryani | straightforward USDA lookup |
| **Oats, rolled** | overnight oats | straightforward |
| **Pasta, dry (durum)** | white sauce, pumpkin sauce pasta | straightforward |
| **Millet pasta** | millet pasta | ⚠️ FDC has no such food — needs a composition row (millet flour + water) or your decision on the closest match |
| **Millet vermicelli** | millet vermicelli | ⚠️ same problem |
| **Chia seeds** | overnight oats — *if yours uses them* | pending your answer |

The two flagged rows are the only genuine data problem in your whole list. §0.2 forbids inventing a number, and the honest options are a composition row built from the millet flour that is already in the catalog, or logging them against durum pasta and accepting a known small error. **My recommendation: composition row from millet flour** — it is traceable, and it is what the pipeline is for.

### 6.3 One real gap the list exposed

There is a **`Gujarati dal`** (sweet, with jaggery) and a `Dal dhokli`, but **no plain dal tadka row anywhere in the catalog.** The spec's §0.6 even uses "Dal, cooked" as its worked example of a row that should exist, and it does not. Your "normal daal and rice" needs it, and so do "moong daal" and "palak daal".

### 6.4 "X daal and rice" are meal templates, not foods

Four of your entries — moong dal + rice, palak dal + rice, normal dal + rice — are plates, not dishes. The catalog already has "Meal templates worth defining" sections and the app already has `MealTemplates` / `MealTemplateItems` tables. So each becomes **one dal row plus one template**, and logging the plate is one tap rather than two.

### 6.5 Revised wave 1 — about 34 rows, not 310

| File | Rows | Contents |
|---|---|---|
| `01-common.md` *(additions)* | 3 | Mushroom · Oats, rolled · Chia seeds |
| `05-everyday-north.md` *(new)* | ~14 | **①** Dal tadka, plain · **①** Moong dal · Palak dal · Chhole · Kabuli chana subji · Cowpea subji · Tomato subji · Mushroom subji · Raw banana fry · Sweet potato paratha · Palak paneer paratha · Egg bhurji |
| `06-rice-and-biryani.md` *(new)* | ~6 | Paneer biryani · Egg biryani · Mushroom biryani · Pudina pulav · Tawa pulav |
| `07-pasta-and-modern.md` *(new)* | ~9 | Pasta, dry · Millet pasta · Millet vermicelli · White sauce pasta · Pumpkin sauce pasta · Millet pasta (dish) · Overnight oats · Lemon vermicelli · Millet vermicelli upma |
| `05`/`06` template sections | 4 | The three dal-and-rice plates, plus pav bhaji |
| **Total** | **~34** | Covers **100%** of what you told me you cook |

`Pav bhaji` goes in `05-everyday-north.md` for now rather than earning a street-food file of its own; one dish does not need a file.

### 6.6 The finding worth acting on: your list contains no Chinese, and almost no Punjabi

Rev 0.2 proposed a 40-row Indo-Chinese file and a 75-row Punjabi file. Against your actual list:

- **Chinese: zero dishes.** No noodles, no fried rice, no manchurian, no chilli paneer, no momos.
- **Punjabi: one dish** — chhole. No dal makhani, no rajma, no paneer gravies, no naan.
- **Italian: three pasta dishes**, not forty.
- **Kathiyawadi: zero dishes** — though several Gujarati rows are already there from the existing `02-gujarat.md`.

This is exactly what risk **R-1** and catalog spec **§0.5** warn about: curating to the length of a list rather than to the kitchen. Writing 115 Punjabi and Indo-Chinese rows nobody logs would be the most expensive mistake available here, and it would bury the ~25 rows you would actually use.

**Recommendation:** build the ~34 rows above, use the app for a month, and let the search-failure queue (§31.6) name the next wave. If Chinese and Punjabi are food you eat *out* rather than cook, they are worth adding later and at a much smaller size — restaurant portions, not recipes.

### 6.7 Spec additions still needed

Small, and unchanged in intent from rev 0.2:

- **New serving units** — plate (pasta), bowl (overnight oats), and pasta's raw-vs-cooked weight, which is the same trap as rice (§0.6: cooked and raw are different foods, never a conversion).
- **Deep-fried rows state absorbed oil separately from cooking oil**, so Part B cannot halve absorbed oil — a puri fried in less oil absorbs about the same.
- **Cuisine may be overridden per section**, not only per file: `06-rice-and-biryani.md` and `07-pasta-and-modern.md` are not single-cuisine files, and `Overnight oats` belongs to no cuisine at all. §5's tags need a `modern` / `pan-indian` value and a section-level override.

---

## 7. Part B — "our kitchen" light-cooking versions *(unchanged from 0.1, condensed)*

Rejected: a second catalog row per dish (doubles the catalog, and "light" is still a guess about someone else's kitchen); a global oil multiplier (silently rewrites every dish including deep-fried ones, and breaks the rule that a dish's nutrients equal its components).

**Recommended: fork the catalog recipe into one you own.** One action on a catalog dish — *"Make this our version"* — opens the existing recipe builder pre-filled from that dish's `recipe_components`. Change `Groundnut oil 8 g` to `4 g`, save. From there it is an ordinary user recipe: same computation, same coverage gating, same honesty guarantees, just her pot.

Plus: a **"lighter oil" preset** (halves cooking fats, leaves *absorbed* oil alone, always shown before saving); **search prefers your version** with a *Yours* badge, the standard row still reachable; a **household default** so dish twenty takes one tap.

The payoff, computable from data that already exists:

> **Your aloo subji** — 36 kcal and 4 g of fat less per katori than the standard recipe.
> **This week:** 84 g of oil not eaten, across 11 meals. ≈ 740 kcal.

Guardrail: warn (never block — §19.8 says offer, never impose) if a fork drops a fried dish's fat below ~30% of the catalog value.

---

## 8. Work packages

| # | Package | Contents | Size |
|---|---|---|---|
| **WP0** | **Safe-to-extend pipeline** | Stable keys + `uuid.v5` ids (§4.1) · explicit `ingredientTargets` + `--suggest` (§4.2) · `catalog.lock.json` + `--check` (§4.3) · sort the catalog file list · CI gate (§4.4) | ~1.5 days |
| **WP1** | **FDC cache** | `CachingFdcClient`, trimmed records, `index.json`, three modes (§3) | ~half day |
| **WP2** | Catalog spec additions | Serving units, absorbed-oil convention, key/uniqueness rules, section-level cuisine override (§6.7) | ~2 h |
| **WP3** | **Wave 1 rows** | The ~34 rows of §6.5 — every dish you named. One `fetch_catalog` run, one `build_seed`, one reviewable seed diff | ~5 h |
| **WP4** | `cuisineTags` populated + search subtitles | §5.1 — fixes the duplicate-name bug shipping today | ~half day |
| **WP5** | Cuisine ranking + browse chips | §5.2, §5.3 | ~1 day |
| **WP6** | Light cooking: fork + preset + *Yours* ranking | §7 | ~1 day |
| **WP7** | Oil-saved insight + cuisine mix in reports | §5.4, §7 | ~half day |
| **WP8** | Wave 2, scoped from a month of real search failures | Deliberately unscheduled | — |

**Order: WP0 → WP1 → WP2 → WP3 → WP4 → WP6 → WP5 → WP7.**

WP0 and WP1 come first because every later package is a seed rebuild, and until they land each rebuild is an unreviewable 2.3 MB diff produced by ~600 live network calls. WP3 is now small enough that it is a single afternoon and one fetch run.

WP6 (light cooking) moved ahead of WP5 (browse) because §6 shrank: at ~420 foods rather than ~690, browse is less urgent, and the light-cooking feature is the part of this that is actually about your kitchen. It depends only on WP0.

**Which dishes to fork first**, once WP6 lands — the oil-heaviest things you cook often: pav bhaji (butter), the parathas (7–12 g oil each), dosa (6–15 g), and every sabzi (6–9 g). A chapati has nothing to give back.

**On seed versioning:** regenerating `seed_v1.json` in place is correct *today*, because the app is not on anyone's phone yet (Phase 6). The moment it is, a rebuild with today's random ids would import a second copy of the entire catalog. Stable keys cost nothing now and are the only thing that makes a later v2 a reviewable delta — the main reason WP0 is first.

---

## 9. What I need from you

Seven questions from rev 0.2 are resolved by your list. These are what is left, and only #1–#4 block WP3:

| # | Question | Why it matters |
|---|---|---|
| 1 | **Overnight oats — what goes in yours?** Milk or curd, how much oats, fruit, chia, nuts, honey? | It is the one dish on your list I cannot infer. Everything else has a standard shape |
| 2 | **"Normal daal"** — toor only, or a mix? Tempered in oil or ghee, and roughly how much? | Decides the plain-dal row every other dal row is built from |
| 3 | **Millet pasta and millet vermicelli** — which millet (ragi, jowar, foxtail), and is it 100% millet or a blend? | §6.2 — composition row versus closest match |
| 4 | **Which dosas** do you actually make? | Nine rows exist; I want to mark the right ones **①** rather than all nine |
| 5 | **Chinese and Punjabi** — eaten out, or just not on the list? | §6.6 — decides whether wave 2 is recipes or restaurant portions |
| 6 | **Does she measure the oil, or estimate it?** | If she measures even roughly, the forked numbers in Part B stop being estimates. A tablespoon and one week (§0.3) |
| 7 | Commit the FDC cache (≈1 MB)? | Public domain, and it is what makes the seed reproducible |

---

## 10. Explicitly not in this plan

- **The 115 Punjabi and Indo-Chinese rows from rev 0.2** — §6.6. Cut against your own list, not deferred on a guess.
- **Nutrient retention factors** (vitamin C loss on boiling) — still a §9.2 should-have, still not attempted.
- **Per-entry cooking modifiers** — revisit once forking is in daily use.
- **Re-curating the existing 383 rows** — they work; leave them.
- **Renaming the 12 duplicate display names** — §4.3 makes it unnecessary.
- **Any implementation.** Nothing here has been built.

---

### Appendix — how the §4 numbers were obtained

`CatalogIndex`'s three-tier resolution, `CompositionParser`'s ingredient extraction and `ingredientAliases` were re-implemented against the committed `docs/catalog/*.md` and the current alias map, then re-run with candidate new rows appended. The §6 audit is a direct search of the same files. The Dart toolchain is not available in this environment; WP0 turns the same analysis into `parse_catalog --check`, where it belongs. Every figure above is reproducible from the repository as committed.
