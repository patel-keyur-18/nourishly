# Share with Navmaas — the share file

Navmaas, the owner's pregnancy tracker, shows the meals she logs here instead of asking her to type them twice. Nourishly writes one small file that only Navmaas, on the same phone, can read ([ADR-012](architecture/10-adrs.md#adr-012--share-with-navmaas-a-read-only-file-off-by-default)). Nothing leaves the phone.

## When it exists

- Only while **Settings → Your data → Share with Navmaas** is on (off by default).
- Rewritten about 2 seconds after any change to her food log, and whenever Nourishly goes to the background.
- Deleted at once when sharing is turned off, and by "Delete everything on this phone".

## Where it lives

| Platform | Location | Who can read it |
|---|---|---|
| Android | `filesDir/share/nourishly-share.json`, served read-only at `content://com.nourishly.app.nourishly.share/navmaas` | Apps holding `com.patelkeyur.permission.NOURISHLY_SHARE`, a `signature` permission: only apps signed with the owner's key (ADR-011), i.e. Navmaas |
| iPhone | App Group `group.com.patelkeyur.share`, `share/nourishly-share.json` | Apps in that App Group under the owner's team, i.e. Navmaas |

The file is derived data and stays out of Android Auto Backup and iCloud backup.

## Format (version 1)

A sample is in [`packages/nourishly_data/test/fixtures/nourishly-share-v1.sample.json`](../packages/nourishly_data/test/fixtures/nourishly-share-v1.sample.json); Navmaas tests against a copy of it.

| Field | Meaning |
|---|---|
| `format` | Always `"nourishly-share"` |
| `version` | `1` |
| `generatedAt` | When the file was written: local ISO-8601 with its UTC offset |
| `days` | Newest first; only log dates with something eaten, from the last 90 log dates up to today's (the day-rollover setting decides which date an entry belongs to) |
| `days[].date` | `yyyy-MM-dd` |
| `days[].meals` | In meal-slot order, empty slots left out: `{ "slot": <slot name>, "items": [{ "name", "amount" }] }` |
| `items[].amount` | `"<serving> · <grams> g"`, or `"<quantity> × <serving> · <grams> g"` when the quantity isn't 1; grams whole |
| `days[].totals` | Day totals, the same numbers the dashboard shows: `energy` (kcal), `protein` (g), `iron` (mg), `calcium` (mg), `folate` (µg), `fibre` (g). A nutrient with no data that day is left out |
| `days[].partial` | Ids from `totals` where some of that day's foods had no data (coverage below 1). Unknown is never counted as zero |

**Never in the file:** targets, % of target, scores, insights, statuses, profile details (age, weight, height, due date, lifestage), water, planned meals that weren't eaten.

## Compatibility

Readers ignore fields they don't know. A new optional field keeps `version` at 1; anything that changes or removes a field is version 2, which a version-1 reader treats as unreadable.

## Planned additions

The owner plans these as enhancements to both apps (2026-10-10). Nothing is built yet; this is what they would take.

- **Water and weight.** New optional fields, so version 1 readers keep working and `version` stays 1:
  - `days[].water`: `{ "amount": 6, "unit": "glass" }`, where `unit` is `"glass"` or `"ml"`, as Nourishly logged it.
  - `weight`: `{ "kg": 61.2, "date": "2026-10-09" }`, her latest logged weight.

  Like everything else here they are values only: no goals, targets or statuses. Turning sharing off still removes them with the file. Building this lifts two exclusions that stand today: water, and weight from the profile details, under "Never in the file" above and in ADR-012. Both must be amended in the same change, with the owner's approval.
- **"Open Nourishly" from Navmaas.**
  - **Android:** Navmaas adds `<package android:name="com.nourishly.app.nourishly" />` to its `<queries>` and opens Nourishly by its launch intent. Nourishly needs nothing.
  - **iPhone:** Nourishly declares a `nourishly://` URL scheme in `Info.plist`, and Navmaas lists `nourishly` under `LSApplicationQueriesSchemes`.
