# Share with Navmaas — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Nourishly can share this phone's food log with Navmaas, the owner's pregnancy app on the same phone. It writes one small JSON file (each day's meals and six day totals, the last 90 days) that only Navmaas can read. Sharing is off until she turns it on.

**Architecture:**
- **Builder** (`nourishly_data`, pure Dart): makes the JSON from the existing tables and `DailySummaryDao`.
- **Writer** (app): keeps the file current. It rewrites after any change to her log (debounced) and when the app goes to the background, and deletes the file when sharing is turned off.
- **Where the file lives:**
  - Android: Nourishly's private files, served read-only by a `ContentProvider` guarded by a `signature` permission. Both apps carry the owner's key (ADR-011).
  - iPhone: the shared App Group `group.com.patelkeyur.share`.
- **Navmaas** reads the file in its M8b, a separate PR in the Navmaas repo.

**Tech Stack:** Flutter, drift, Riverpod 3, `path_provider` (already a dependency), Kotlin `ContentProvider`, Swift `FlutterMethodChannel`. No new packages.

**Spec:** Navmaas repo `docs/superpowers/specs/2026-10-10-m8-body-birth-prep-design.md` §6.1–6.2 (approved 2026-10-10), with the rulings below.

## Global Constraints

- **The contract** (spec §6.1), `nourishly-share.json`, format `"nourishly-share"`, version `1`:
  - `generatedAt` (local ISO-8601 with offset).
  - `days`: newest first, only days with something logged.
  - Each day has `date` (`yyyy-MM-dd`) and `meals`: slot order, each `{ "slot": <display name>, "items": [{ "name", "amount" }] }`, empty slots left out.
  - `totals`: ids `energy`, `protein`, `iron`, `calcium`, `folate`, `fibre`, in kcal, g, mg, mg, µg, g. A nutrient with no data that day is left out.
  - `partial`: the ids whose coverage that day is below 1.
- **Never in the file:** targets, %, scores, insights, statuses, profile details (age, weight, due date, lifestage), water, or planned (not yet eaten) meals.
- **Window:** the 90 log dates up to and including today's log date (honours the day-rollover setting).
- **Amount text:**
  - Quantity 1: `"<serving label> · <grams> g"`, e.g. `"1 katori · 150 g"`.
  - Otherwise: `"<quantity> × <serving label> · <grams> g"`, e.g. `"2 × 1 piece · 80 g"`.
  - Grams are rounded to whole grams, and quantities print without a trailing `.0`.
- **Sharing is off by default.** Turning it off deletes the file at once.
- **No network:** nothing leaves the phone. The Android permission is `com.patelkeyur.permission.NOURISHLY_SHARE` with `protectionLevel="signature"`. Provider authority: `com.nourishly.app.nourishly.share`.
- **Backups:** the share file is derived data and stays out of Android Auto Backup and iCloud backup.
- **Branch and PR:** `feat/share-with-navmaas` → `develop`, PR title `feat: share with Navmaas`. Nourishly's tag action makes the next `develop` → `main` release a minor bump (v1.2.0).
- **Process:** after each task, `flutter analyze` (zero issues) and the task's tests, in `app/` or the package it touches. Docs stay in sync in the same PR.

## Rulings on the spec (for owner approval)

1. **No profile picker.** Nourishly has one profile per phone (`ensureDefaultOwner`; there is no profile switcher), so sharing covers this phone's profile. If profiles arrive later, a picker can be added then.
2. **The switch lives in Settings → "Your data"**, as a `NourishlyListRow.switched` row titled "Share with Navmaas". Its subtitle is "Off" or "On · meals and six day totals, last 90 days".
   - When it's on, a short fine-print line underneath says what is shared and what never is.
   - There's no new screen and no prototype board: it's one row in an existing group, built from the existing row component.
3. **Totals come from `DailySummaryDao.summaryFor`,** the same numbers the dashboard shows. Coverage below 1 marks a nutrient as partial, and zero coverage leaves it out.

---

### Task 1: The contract and its sample

**Files:**
- Create: `docs/navmaas-share.md` (the contract, human-readable)
- Create: `packages/nourishly_data/test/fixtures/nourishly-share-v1.sample.json`

- [ ] **Step 1:** Write `docs/navmaas-share.md`. It covers:
  - what the file is and why it exists (ADR-012);
  - every field from Global Constraints, with units;
  - the "never in the file" list;
  - where the file lives on each platform, and the permission;
  - the compatibility rule: readers ignore unknown fields; a new optional field doesn't bump the version; anything else is version 2.
- [ ] **Step 2:** Write the sample, two days with one partial nutrient:

```json
{
  "format": "nourishly-share",
  "version": 1,
  "generatedAt": "2026-10-10T09:40:00.000+05:30",
  "days": [
    {
      "date": "2026-10-10",
      "meals": [
        { "slot": "Breakfast", "items": [ { "name": "Poha", "amount": "1 katori · 150 g" } ] }
      ],
      "totals": { "energy": 245, "protein": 4.6, "iron": 2.1, "calcium": 18, "fibre": 2.4 },
      "partial": []
    },
    {
      "date": "2026-10-09",
      "meals": [
        { "slot": "Lunch", "items": [
          { "name": "Dal tadka", "amount": "1 katori · 150 g" },
          { "name": "Phulka", "amount": "2 × 1 piece · 60 g" } ] },
        { "slot": "Dinner", "items": [ { "name": "Khichdi", "amount": "1 bowl · 250 g" } ] }
      ],
      "totals": { "energy": 1120, "protein": 38.2, "iron": 9.4, "calcium": 310, "folate": 180, "fibre": 21.5 },
      "partial": ["folate"]
    }
  ]
}
```

(The first day has no `folate`: no data at all that day.)

- [ ] **Step 3: Commit** `docs: Navmaas share-file contract and sample`.

### Task 2: The switch in the database (schema v8)

**Files:**
- Modify: `packages/nourishly_data/lib/src/tables/identity_tables.dart` (`UserPreferences`)
- Modify: `packages/nourishly_data/lib/src/database.dart` (`schemaVersion => 8`, the `from < 8` step, the doc comment)
- Modify: `packages/nourishly_data/lib/src/dao/preferences_dao.dart` (`update(… bool? shareWithNavmaas)`)
- Create: `packages/nourishly_data/test/migration_v8_test.dart`

**Interfaces:** Produces `UserPreference.shareWithNavmaas` (`bool`) and `PreferencesDao.update(ownerId, shareWithNavmaas: bool)`.

- [ ] **Step 1: Failing test**, `migration_v8_test.dart`, in the style of `migration_v7_test.dart`. Downgrade a fresh DB by dropping the column, set `PRAGMA user_version = 7`, reopen, and expect:
  - the column exists with `false` for an existing row;
  - `update(…, shareWithNavmaas: true)` round-trips.
- [ ] **Step 2: Run, expect failure:** `cd packages/nourishly_data && flutter test test/migration_v8_test.dart`, which fails on the missing getter.
- [ ] **Step 3: Implement.** Add the column:

```dart
  /// Share with Navmaas (ADR-012): off until she turns it on.
  BoolColumn get shareWithNavmaas =>
      boolean().withDefault(const Constant(false))();
```

  Then add `if (from < 8 && to >= 8) await m.addColumn(userPreferences, userPreferences.shareWithNavmaas);` with a doc line ("v7 -> v8: the Navmaas share switch; additive, off"), add the `update` parameter like `remindersEnabled`, and run `dart run build_runner build`.
- [ ] **Step 4: Run** the package tests: `flutter test`. Expect PASS, including `export_completeness_test`.
- [ ] **Step 5: Commit** `feat(data): share-with-Navmaas preference (schema v8)`.

### Task 3: The builder

**Files:**
- Create: `packages/nourishly_data/lib/src/share/navmaas_share.dart` (exported from `nourishly_data.dart`)
- Create: `packages/nourishly_data/test/navmaas_share_test.dart`

**Interfaces:** Produces:

```dart
const navmaasShareNutrients = ['energy', 'protein', 'iron', 'calcium', 'folate', 'fibre'];
const navmaasShareDays = 90;
Future<Map<String, Object?>> buildNavmaasShare({
  required NourishlyDatabase db,
  required String ownerId,
  required DateTime today,      // today's log date
  required DateTime now,        // for generatedAt and summaryFor
});
```

- [ ] **Step 1: Failing tests** (in-memory DB, `NourishlyDatabase.forTesting()`, catalog seeded the way `daily_summary_dao_test.dart` seeds it):
  1. **Shape:** the top-level keys, and each day's keys, equal the sample's (fixture from Task 1); `format`/`version` are right.
  2. **Only her days:** a day with no entries is left out, and days come newest first.
  3. **The window:** an entry 90 days back is in; one 91 days back is out.
  4. **Planned meals are left out:** a `planned` entry (week planner) never appears.
  5. **Amounts:** quantity 1 → `"1 katori · 150 g"`; quantity 2 → `"2 × 1 piece · 80 g"`; grams rounded.
  6. **Totals and partial:** a day mixing a food with folate data and one without lists `folate` in `partial`; a day with no folate data at all has no `folate` key.
  7. **Never in the file:** the encoded JSON contains none of `target`, `score`, `insight`, `status`, `pct`, `dueDate`, `lifestage`, `water` (string search on the keys).
- [ ] **Step 2: Run, expect failure:** `flutter test test/navmaas_share_test.dart`, failing on the missing function.
- [ ] **Step 3: Implement:**
  1. Query the distinct `logDate`s in the window with actual entries (`isActual`).
  2. For each date, newest first:
     - Read the entries joined to `foodItems.canonicalName`, `mealSlots` (display name, sort order) and `servingSizes.label`.
     - Group them by slot in slot order.
     - Build the amount text with `_amount(quantity, label, grams)`.
     - Call `DailySummaryDao(db).summaryFor(ownerId:, logDate:, now:)` and take `nutrient(id)` for each share id: `coverage == 0` is left out; `coverage < 1` goes in `partial`. Amounts are rounded to the nutrient's display precision (1 decimal, energy and calcium whole).
  3. `generatedAt`: `now` as ISO-8601 with the local offset.
- [ ] **Step 4: Run.** Expect PASS, then run the whole package suite.
- [ ] **Step 5: Commit** `feat(data): build the Navmaas share file`.

### Task 4: Writing the file (app)

**Files:**
- Create: `app/lib/features/navmaas_share/data/share_location.dart`
- Create: `app/lib/features/navmaas_share/data/share_writer.dart`
- Modify: `app/lib/app/app.dart` (start the writer; flush on `paused`)
- Create: `app/test/features/navmaas_share/share_writer_test.dart`

**Interfaces:**
- **`ShareLocation`:** `Future<Directory?> directory()`.
  - Android: `<getApplicationSupportDirectory()>/share` (that is `filesDir/share`, which the provider serves).
  - iOS: the channel `nourishly/share` method `groupDirectory` returns the App Group's `share/` path, created and excluded from backup.
  - Elsewhere: `null`.
- **`shareLocationProvider`:** overridden in tests with a temp directory.
- **`ShareWriter`** (`Notifier<void>`, kept alive):
  - Listens to `preferencesProvider` (the switch) and to `db.tableUpdates(TableUpdateQuery.onAllTables([foodLogEntries, logEntryNutrients, foodItems, servingSizes]))`, debounced 2 s.
  - `flush()` writes now (lifecycle `paused`).
  - When on: build, write `nourishly-share.json.tmp`, then rename over `nourishly-share.json` (atomic).
  - When off: delete both.
  - Errors are logged and never shown. Navmaas shows "couldn't read" if the file is stale or broken.

- [ ] **Step 1: Failing tests** (`pumpApp`-style container with an in-memory DB, the temp dir location, fake async):
  1. **Off by default:** no file after start and after logging a food.
  2. **Turn on:** a file appears with today's food; `format` is `nourishly-share`.
  3. **A log 1 s later:** the file doesn't change yet. At 2 s it does (debounce).
  4. **`flush()`:** writes at once.
  5. **Turn off:** the file is deleted.
- [ ] **Step 2: Run, expect failure** (missing writer).
- [ ] **Step 3: Implement.** In `app.dart`:
  - `initState` post-frame: `ref.read(shareWriterProvider)`.
  - `didChangeAppLifecycleState`: on `paused`, `unawaited(ref.read(shareWriterProvider.notifier).flush())`.
  - On `resumed`, the existing refresh also triggers a rebuild, so the 90-day window moves with the day.
- [ ] **Step 4: Run** `cd app && flutter test test/features/navmaas_share`. Expect PASS.
- [ ] **Step 5: Commit** `feat(app): keep the Navmaas share file current`.

### Task 5: The switch in Settings

**Files:**
- Modify: `app/lib/features/settings/presentation/screens/settings_screen.dart` (`_YourDataGroup`)
- Modify: `app/test/features/settings/…` (the existing settings widget test file) and `app/test/a11y/accessibility_test.dart`

- [ ] **Step 1: Failing widget test:**
  - Settings shows "Share with Navmaas" with subtitle "Off".
  - Tapping the row turns it on: the subtitle becomes "On · meals and six day totals, last 90 days", the fine print appears, and the preference is `true`.
  - Tapping again turns it off.
- [ ] **Step 2: Run, expect failure.**
- [ ] **Step 3: Implement.** The new first row of `_YourDataGroup`:

```dart
        NourishlyListRow.switched(
          title: 'Share with Navmaas',
          subtitle: preferences.shareWithNavmaas
              ? 'On · meals and six day totals, last 90 days'
              : 'Off',
          value: preferences.shareWithNavmaas,
          onChanged: (v) => _update(ref, shareWithNavmaas: v),
        ),
```

`_YourDataGroup` takes `preferences` from the screen, as the Preferences group's rows already do, and the screen's existing `_update` helper gains a `shareWithNavmaas` parameter passed to `PreferencesDao.update`.

  When on, add this fine print under the group, in the style of the About footer: "Navmaas, on this phone only, can read each day's meals and six totals (energy, protein, iron, calcium, folate, fibre) from the last 90 days. Never your targets, scores, profile or water. Nothing leaves your phone. Turn this off to remove the shared copy."
- [ ] **Step 4: Run** the settings and a11y tests: no overflow at large text, the switch row reachable and labelled. Expect PASS.
- [ ] **Step 5: Commit** `feat(settings): Share with Navmaas switch`.

### Task 6: Android, the provider behind a signature permission

**Files:**
- Create: `app/android/app/src/main/kotlin/com/nourishly/app/nourishly/ShareProvider.kt`
- Modify: `app/android/app/src/main/AndroidManifest.xml`
- Modify: `app/android/app/src/main/res/xml/backup_rules.xml`, `data_extraction_rules.xml` (exclude `share/`)

- [ ] **Step 1: Provider:**

```kotlin
package com.nourishly.app.nourishly

import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.net.Uri
import android.os.ParcelFileDescriptor
import java.io.File
import java.io.FileNotFoundException

/**
 * Serves the Navmaas share file (ADR-012), read-only, to apps holding
 * com.patelkeyur.permission.NOURISHLY_SHARE — a signature permission, so
 * only apps signed with the owner's key (ADR-011), i.e. Navmaas.
 */
class ShareProvider : ContentProvider() {
    override fun onCreate() = true

    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor {
        if (mode != "r" || uri.lastPathSegment != "navmaas") throw FileNotFoundException()
        val file = File(context!!.filesDir, "share/nourishly-share.json")
        if (!file.exists()) throw FileNotFoundException()
        return ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
    }

    override fun getType(uri: Uri) = "application/json"
    override fun query(u: Uri, p: Array<String>?, s: String?, a: Array<String>?, o: String?): Cursor? = null
    override fun insert(uri: Uri, values: ContentValues?): Uri? = null
    override fun delete(uri: Uri, s: String?, a: Array<String>?) = 0
    override fun update(uri: Uri, v: ContentValues?, s: String?, a: Array<String>?) = 0
}
```

- [ ] **Step 2: Manifest:**
  - Under `<manifest>`: `<permission android:name="com.patelkeyur.permission.NOURISHLY_SHARE" android:protectionLevel="signature" />`, with a comment naming ADR-012.
  - Under `<application>`: `<provider android:name=".ShareProvider" android:authorities="com.nourishly.app.nourishly.share" android:exported="true" android:readPermission="com.patelkeyur.permission.NOURISHLY_SHARE" />`.
- [ ] **Step 3: Backup rules:** add `<exclude domain="file" path="share/"/>` to both XML files, in their existing form.
- [ ] **Step 4: Verify:**
  - Run `flutter build apk --release`. In the merged manifest, `grep -n "NOURISHLY_SHARE\|ShareProvider"` shows the permission and the provider.
  - On the owner's Android, with sharing on: `adb shell content read --uri content://com.nourishly.app.nourishly.share/navmaas` must be **refused**. The shell doesn't hold the permission, and that refusal proves the guard. Navmaas M8b proves the allowed read.
- [ ] **Step 5: Commit** `feat(android): share provider for Navmaas behind a signature permission`.

### Task 7: iPhone, the shared App Group

**Files:**
- Create: `app/ios/Runner/Runner.entitlements` (`com.apple.security.application-groups` → `group.com.patelkeyur.share`)
- Modify: `app/ios/Runner.xcodeproj/project.pbxproj` (`CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;` in Runner's Debug, Release and Profile configurations)
- Modify: `app/ios/Runner/AppDelegate.swift`

- [ ] **Step 1: Channel** in `didInitializeImplicitFlutterEngine`:

```swift
    let share = engineBridge.pluginRegistry.registrar(forPlugin: "NourishlyShare")!
    FlutterMethodChannel(name: "nourishly/share", binaryMessenger: share.messenger())
      .setMethodCallHandler { call, result in
        guard call.method == "groupDirectory",
              let base = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: "group.com.patelkeyur.share")
        else { result(nil); return }
        var dir = base.appendingPathComponent("share", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true  // derived data, rebuilt from the log
        try? dir.setResourceValues(values)
        result(dir.path)
      }
```

- [ ] **Step 2: Verify:** `flutter build ios --release --no-codesign` compiles.
  - **Owner, once in Xcode:** choose the personal team, check that Signing & Capabilities shows App Groups with `group.com.patelkeyur.share` (Xcode registers it), and run on the iPhone.
  - Navmaas's Runner joins the same group in M8b.
- [ ] **Step 3: Commit** `feat(ios): App Group for the Navmaas share file`.

### Task 8: Docs and the PR

**Files:**
- Modify: `docs/architecture/10-adrs.md` (ADR-012 "Share with Navmaas: a read-only file, off by default", in the existing ADR format)
- Modify: `docs/architecture/09-privacy-scalability.md`:
  - §30.4 consent: the switch, off by default.
  - §30.5 data flows: one on-device reader, Navmaas, guarded by signature / App Group; what's in the file and what never is.
  - §30.7 deletion: turning the switch off, or "Delete everything", removes the file.
- Modify: the data-model doc listing `user_preferences` columns (`grep -rn "quick_add_water_amounts\|quickAddWaterAmounts" docs`), adding `share_with_navmaas`.
- Modify: `README.md` "Built so far" line: sharing with Navmaas.

- [ ] **Step 1: "Delete everything" removes the file too.**
  - Check `ProfileEraser` and the delete flow.
  - If deleting doesn't already go through preferences (which would turn the writer off), add a call to `shareWriter.flush()` after the erase, so the file is rebuilt as off and deleted.
  - Test: sharing on, delete everything, no file.
- [ ] **Step 2: Docs** as listed. Then `grep -rn "Navmaas" docs README.md` to check nothing is stale.
- [ ] **Step 3: Full verification:**
  - `cd app && flutter analyze && flutter test`, plus `flutter test` in each package that changed.
  - The release APK builds, and the merged manifest has the provider and permission.
  - iOS compiles.
- [ ] **Step 4: Push and open the PR** `feat: share with Navmaas` → `develop`. The body lists what's shared, the on-device checks for the owner, and that Navmaas M8b reads it.

## Review Focus

- **Sharing turned off while a debounced write is pending:** the pending write must not recreate the file after it was deleted. Writer test: turn on, log, turn off within 2 s, wait 3 s, no file.
- **A day with only planned (week-planner) meals:** left out entirely, with no empty day. Builder test 4 covers it.
- **The rollover setting:** a 1 am entry with a 4 am rollover belongs to the previous log date in the file. Builder test with `dayRolloverTime: 240`.
- **A very large log** (90 full days): the build stays off the UI thread (drift's background isolate) and under about 1 s. Performance test in the style of `performance_test.dart`, with a generous budget.
- **"Delete everything" while sharing is on:** the file goes too (Task 8 Step 1).

## On-device checks for the owner (after merge to develop and a build)

1. Android, sharing on: the `adb shell content read …` command is refused (permission). Navmaas M8b then shows her meals.
2. Turn sharing off: Navmaas shows "Turn on Share with Navmaas in Nourishly".
3. iPhone: the Xcode run shows the App Group capability; with sharing on, Navmaas (M8b) shows the meals.
