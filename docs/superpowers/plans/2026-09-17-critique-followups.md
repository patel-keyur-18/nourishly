# Critique Followups Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the 5 issues from the 2026-09-17 `/impeccable critique` run (`.impeccable/critique/2026-09-17T10-49-11Z__app-lib.md`), in priority order, each verified by `flutter analyze` + `flutter test` before moving on.

**Architecture:** Five independent-ish changes to the existing Flutter app (`app/`) and its `nourishly_data` package. No new dependencies, no schema migration (the `MealTemplates`/`MealTemplateItems` tables already exist in `database.dart` at `schemaVersion == 6`, unused by any DAO). Every new provider/DAO follows the hand-written pattern already used throughout (`RecipeDao`/`recipe_providers.dart`, `FoodLoggingDao`/`app/lib/app/providers.dart`) — no codegen anywhere in this repo.

**Tech Stack:** Flutter, Riverpod (`flutter_riverpod` — hand-written providers, no `riverpod_generator`), `go_router`, `drift` (SQLite), `flutter_test` widget tests matching the existing `pumpWater`-style per-file harness (see `app/test/features/water/water_message_test.dart`).

**Spec:** `.impeccable/critique/2026-09-17T10-49-11Z__app-lib.md` (the critique report), `docs/design/decisions.md` (screen 7 = meal templates, option A "cards with contents"), `DESIGN.md` (never-colour-alone, no-red-for-over, unknown-is-not-zero rules — Task 2 must follow AP-4).

## Global Constraints

- No schema/migration changes — `MealTemplates`/`MealTemplateItems` already exist and are registered; only DAOs/providers/UI are missing.
- Every DB write goes through a DAO, never raw `db.select`/`db.into` from a widget (match `RecipeDao`/`FoodLoggingDao` pattern).
- AP-4 (unknown-is-not-zero): a missing nutrient value renders as `—`, never `0`.
- No red for "over target" — violet (`NourishlyStatus.high`) only, red is destructive-only.
- Match existing widget test harness: `NourishlyDatabase.forTesting()`, `ensureDefaultOwner(db)`, `ProviderScope` overrides for `nourishlyDatabaseProvider`, `catalogReadyProvider`, `clockProvider` (`FakeClock`), `reminderSchedulerProvider` (`NoopReminderScheduler`).
- Run `flutter analyze` (from `app/`) and the relevant `flutter test` after every task; do not proceed to the next task on a red build.

---

## Task 1: Meal templates (P0)

**Files:**
- Create: `packages/nourishly_data/lib/src/dao/meal_template_dao.dart`
- Modify: `packages/nourishly_data/lib/nourishly_data.dart` — add `export 'src/dao/meal_template_dao.dart';` (alphabetical, after `custom_food_dao.dart` export)
- Create: `app/lib/features/meal_templates/data/meal_template_providers.dart`
- Create: `app/lib/features/meal_templates/presentation/screens/meal_templates_screen.dart`
- Modify: `app/lib/app/router.dart` — add `/templates` route (root navigator, same shape as `/recipes`)
- Modify: `app/lib/features/food_logging/presentation/screens/food_logging_screen.dart` — `_BrowseByCuisine`: remove the stale "later phase" copy, add a "Your meal templates" entry row
- Modify: `app/lib/features/food_logging/presentation/screens/day_log_screen.dart` — `_ByMealList`: add a "Save as template" action to each populated meal group's header
- Test: `packages/nourishly_data/test/dao/meal_template_dao_test.dart`
- Test: `app/test/features/meal_templates/meal_templates_screen_test.dart`

**Interfaces:**
- Produces: `MealTemplateDao` with `templatesFor(String ownerId) → Future<List<SavedMealTemplate>>`, `createFromEntries({required String ownerId, required String name, String? defaultMealSlotId, required List<MealTemplateItemInput> items}) → Future<String>`, `applyTemplate({required String templateId, required String ownerId, required DateTime logDate, String? mealSlotId}) → Future<int>`, `deleteTemplate(String templateId) → Future<void>`.
- Produces: `SavedMealTemplate {id, name, defaultMealSlotId, items: List<MealTemplateItemDetail>}`, `MealTemplateItemDetail {foodId, foodName, servingSizeId, servingLabel, quantity}`, `MealTemplateItemInput {foodId, servingSizeId, quantity}`.
- Produces providers: `mealTemplateDaoProvider`, `mealTemplatesProvider` (`FutureProvider<List<SavedMealTemplate>>`), `mealTemplateRevisionProvider` (`NotifierProvider<MealTemplateRevision, int>`, `.bump()`).
- Consumes: `NourishlyDatabase` (`nourishlyDatabaseProvider`), `FoodLoggingDao.logFood` (existing, see `app/lib/app/providers.dart` — `foodLoggingDaoProvider`), `defaultOwnerProvider`, `todayProvider`, `mealSlotsProvider` (all existing, `app/lib/app/providers.dart`).

- [ ] **Step 1: Write the failing DAO test**

```dart
// packages/nourishly_data/test/dao/meal_template_dao_test.dart
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly_data/nourishly_data.dart';

void main() {
  late NourishlyDatabase db;
  late String ownerId;

  setUp(() async {
    db = NourishlyDatabase.forTesting();
    ownerId = await ensureDefaultOwner(db);
    await db
        .into(db.foodItems)
        .insert(
          FoodItemsCompanion.insert(
            id: 'food-dal',
            kind: 'ingredient',
            canonicalName: 'Dal',
            qualityTier: 'verified',
            provenanceSource: 'usda',
          ),
        );
    await db
        .into(db.servingSizes)
        .insert(
          ServingSizesCompanion.insert(
            id: 'serving-dal-katori',
            foodId: 'food-dal',
            label: '1 katori',
            grams: 150,
          ),
        );
    await db
        .into(db.mealSlots)
        .insert(
          MealSlotsCompanion.insert(
            id: 'slot-lunch',
            key: 'lunch',
            displayName: 'Lunch',
            sortOrder: 1,
          ),
        );
  });

  tearDown(() => db.close());

  test('creates a template and reads it back with resolved food names', () async {
    final dao = MealTemplateDao(db);
    final id = await dao.createFromEntries(
      ownerId: ownerId,
      name: 'Usual lunch',
      defaultMealSlotId: 'slot-lunch',
      items: const [
        MealTemplateItemInput(
          foodId: 'food-dal',
          servingSizeId: 'serving-dal-katori',
          quantity: 2,
        ),
      ],
    );

    final templates = await dao.templatesFor(ownerId);
    expect(templates, hasLength(1));
    expect(templates.single.id, id);
    expect(templates.single.name, 'Usual lunch');
    expect(templates.single.defaultMealSlotId, 'slot-lunch');
    expect(templates.single.items.single.foodName, 'Dal');
    expect(templates.single.items.single.quantity, 2);
  });

  test('rejects a template with no items', () async {
    final dao = MealTemplateDao(db);
    expect(
      () => dao.createFromEntries(
        ownerId: ownerId,
        name: 'Empty',
        defaultMealSlotId: null,
        items: const [],
      ),
      throwsArgumentError,
    );
  });

  test('applying a template logs one entry per item and bumps useCount', () async {
    final dao = MealTemplateDao(db);
    final id = await dao.createFromEntries(
      ownerId: ownerId,
      name: 'Usual lunch',
      defaultMealSlotId: 'slot-lunch',
      items: const [
        MealTemplateItemInput(
          foodId: 'food-dal',
          servingSizeId: 'serving-dal-katori',
          quantity: 2,
        ),
      ],
    );

    final logged = await dao.applyTemplate(
      templateId: id,
      ownerId: ownerId,
      logDate: DateTime(2026, 9, 17),
    );
    expect(logged, 1);

    final entries = await db.select(db.foodLogEntries).get();
    expect(entries, hasLength(1));
    expect(entries.single.foodId, 'food-dal');
    expect(entries.single.mealSlotId, 'slot-lunch');
    expect(entries.single.quantity, 2);
    expect(entries.single.gramsConsumed, 300);
    expect(entries.single.source, 'manual');

    final templates = await dao.templatesFor(ownerId);
    expect(templates.single.id, id);
    final updated = await (db.select(
      db.mealTemplates,
    )..where((t) => t.id.equals(id))).getSingle();
    expect(updated.useCount, 1);
    expect(updated.lastUsedAt, isNotNull);
  });

  test('applying with an explicit meal slot overrides the default', () async {
    final dao = MealTemplateDao(db);
    await db
        .into(db.mealSlots)
        .insert(
          MealSlotsCompanion.insert(
            id: 'slot-breakfast',
            key: 'breakfast',
            displayName: 'Breakfast',
            sortOrder: 0,
          ),
        );
    final id = await dao.createFromEntries(
      ownerId: ownerId,
      name: 'Usual lunch',
      defaultMealSlotId: 'slot-lunch',
      items: const [
        MealTemplateItemInput(
          foodId: 'food-dal',
          servingSizeId: 'serving-dal-katori',
          quantity: 1,
        ),
      ],
    );

    await dao.applyTemplate(
      templateId: id,
      ownerId: ownerId,
      logDate: DateTime(2026, 9, 17),
      mealSlotId: 'slot-breakfast',
    );

    final entry = await db.select(db.foodLogEntries).getSingle();
    expect(entry.mealSlotId, 'slot-breakfast');
  });

  test('deleteTemplate soft-deletes; it drops out of templatesFor', () async {
    final dao = MealTemplateDao(db);
    final id = await dao.createFromEntries(
      ownerId: ownerId,
      name: 'Usual lunch',
      defaultMealSlotId: 'slot-lunch',
      items: const [
        MealTemplateItemInput(
          foodId: 'food-dal',
          servingSizeId: 'serving-dal-katori',
          quantity: 1,
        ),
      ],
    );
    await dao.deleteTemplate(id);
    expect(await dao.templatesFor(ownerId), isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/nourishly_data && flutter test test/dao/meal_template_dao_test.dart`
Expected: FAIL — `MealTemplateDao`/`MealTemplateItemInput`/`SavedMealTemplate` not defined.

- [ ] **Step 3: Write `meal_template_dao.dart`**

```dart
// packages/nourishly_data/lib/src/dao/meal_template_dao.dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database.dart';
import 'food_logging_dao.dart';

const _uuid = Uuid();

/// One food a template will log, before it is saved.
class MealTemplateItemInput {
  const MealTemplateItemInput({
    required this.foodId,
    required this.servingSizeId,
    required this.quantity,
  });

  final String foodId;
  final String? servingSizeId;
  final double quantity;
}

/// One food inside a saved template, with the food name and serving label
/// already resolved for display.
class MealTemplateItemDetail {
  const MealTemplateItemDetail({
    required this.foodId,
    required this.foodName,
    required this.servingSizeId,
    required this.servingLabel,
    required this.quantity,
  });

  final String foodId;
  final String foodName;
  final String? servingSizeId;
  final String? servingLabel;
  final double quantity;
}

/// A saved meal template, read back for the templates screen.
class SavedMealTemplate {
  const SavedMealTemplate({
    required this.id,
    required this.name,
    required this.defaultMealSlotId,
    required this.items,
  });

  final String id;
  final String name;
  final String? defaultMealSlotId;
  final List<MealTemplateItemDetail> items;
}

/// A saved set of foods a profile logs together often (screen 7, "cards
/// with contents" — decisions.md). Applying a template creates independent
/// [FoodLogEntries] rows with their own frozen nutrient snapshots; entries
/// never reference the template back, so editing or deleting one never
/// alters a meal already logged from it (matches [RecipeDao]'s ADR-008
/// stance, restated on the table's own doc comment in
/// `logging_tables.dart`).
class MealTemplateDao {
  MealTemplateDao(this._db);

  final NourishlyDatabase _db;

  /// Every template this profile has saved, newest first.
  Future<List<SavedMealTemplate>> templatesFor(String ownerId) async {
    final templates =
        await (_db.select(_db.mealTemplates)
              ..where(
                (t) => t.ownerId.equals(ownerId) & t.deletedAt.isNull(),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.id)]))
            .get();
    return [for (final template in templates) await _hydrate(template)];
  }

  Future<SavedMealTemplate> _hydrate(MealTemplate template) async {
    final items =
        await (_db.select(_db.mealTemplateItems)
              ..where((i) => i.templateId.equals(template.id))
              ..orderBy([(i) => OrderingTerm.asc(i.sortOrder)]))
            .get();

    final foodIds = items.map((i) => i.foodId).toSet().toList();
    final foods = foodIds.isEmpty
        ? <FoodItem>[]
        : await (_db.select(_db.foodItems)..where((f) => f.id.isIn(foodIds))).get();
    final names = {for (final f in foods) f.id: f.canonicalName};

    final servingIds = items
        .map((i) => i.servingSizeId)
        .whereType<String>()
        .toSet()
        .toList();
    final servings = servingIds.isEmpty
        ? <ServingSize>[]
        : await (_db.select(
            _db.servingSizes,
          )..where((s) => s.id.isIn(servingIds))).get();
    final servingById = {for (final s in servings) s.id: s};

    return SavedMealTemplate(
      id: template.id,
      name: template.name,
      defaultMealSlotId: template.defaultMealSlotId,
      items: [
        for (final item in items)
          MealTemplateItemDetail(
            foodId: item.foodId,
            foodName: names[item.foodId] ?? 'Unknown food',
            servingSizeId: item.servingSizeId,
            servingLabel: item.servingSizeId == null
                ? null
                : servingById[item.servingSizeId]?.label,
            quantity: item.quantity,
          ),
      ],
    );
  }

  /// Saves [items] as a new template named [name].
  Future<String> createFromEntries({
    required String ownerId,
    required String name,
    required String? defaultMealSlotId,
    required List<MealTemplateItemInput> items,
  }) async {
    if (items.isEmpty) {
      throw ArgumentError.value(
        items,
        'items',
        'A template is its foods — there is nothing to save without at '
            'least one.',
      );
    }

    final id = _uuid.v7();
    await _db.transaction(() async {
      await _db
          .into(_db.mealTemplates)
          .insert(
            MealTemplatesCompanion.insert(
              id: id,
              ownerId: ownerId,
              name: name,
              defaultMealSlotId: Value(defaultMealSlotId),
            ),
          );
      await _db.batch((batch) {
        for (var i = 0; i < items.length; i++) {
          batch.insert(
            _db.mealTemplateItems,
            MealTemplateItemsCompanion.insert(
              id: _uuid.v7(),
              templateId: id,
              foodId: items[i].foodId,
              servingSizeId: Value(items[i].servingSizeId),
              quantity: items[i].quantity,
              sortOrder: Value(i),
            ),
          );
        }
      });
    });
    return id;
  }

  /// Logs every item of [templateId] into [logDate], in [mealSlotId] (or
  /// the template's own default when none is given). Returns how many
  /// items were actually logged — an item whose food has no serving size
  /// recorded is skipped rather than guessed at (AP-4's spirit: no
  /// fabricated portion).
  Future<int> applyTemplate({
    required String templateId,
    required String ownerId,
    required DateTime logDate,
    String? mealSlotId,
  }) async {
    final template = await (_db.select(
      _db.mealTemplates,
    )..where((t) => t.id.equals(templateId))).getSingle();
    final items = await (_db.select(
      _db.mealTemplateItems,
    )..where((i) => i.templateId.equals(templateId))).get();

    final slot = mealSlotId ?? template.defaultMealSlotId;
    if (slot == null) {
      throw StateError(
        'This template has no meal slot — pick one to log it into.',
      );
    }

    final dao = FoodLoggingDao(_db);
    var logged = 0;
    for (final item in items) {
      final servingId = item.servingSizeId ?? await _defaultServingFor(item.foodId);
      if (servingId == null) continue;
      await dao.logFood(
        ownerId: ownerId,
        foodId: item.foodId,
        servingId: servingId,
        quantity: item.quantity,
        mealSlotId: slot,
        logDate: logDate,
      );
      logged++;
    }

    await (_db.update(_db.mealTemplates)..where((t) => t.id.equals(templateId))).write(
      MealTemplatesCompanion(
        lastUsedAt: Value(DateTime.now()),
        useCount: Value(template.useCount + 1),
      ),
    );
    return logged;
  }

  Future<String?> _defaultServingFor(String foodId) async {
    final rows =
        await (_db.select(_db.servingSizes)
              ..where((s) => s.foodId.equals(foodId))
              ..limit(1))
            .get();
    return rows.isEmpty ? null : rows.first.id;
  }

  /// Soft-deletes the template. Meals already logged from it are untouched
  /// — they never referenced it in the first place.
  Future<void> deleteTemplate(String templateId) async {
    await (_db.update(_db.mealTemplates)..where((t) => t.id.equals(templateId))).write(
      MealTemplatesCompanion(deletedAt: Value(DateTime.now())),
    );
  }
}
```

- [ ] **Step 4: Add the barrel export and run the test**

In `packages/nourishly_data/lib/nourishly_data.dart`, add (alphabetically, after the `custom_food_dao.dart` line):
```dart
export 'src/dao/meal_template_dao.dart';
```

Run: `cd packages/nourishly_data && flutter test test/dao/meal_template_dao_test.dart -v`
Expected: PASS (all 5 cases).

- [ ] **Step 5: Commit the data-layer half**

```bash
git add packages/nourishly_data/lib/src/dao/meal_template_dao.dart packages/nourishly_data/lib/nourishly_data.dart packages/nourishly_data/test/dao/meal_template_dao_test.dart
git commit -m "feat(data): add MealTemplateDao over the existing meal_templates tables"
```

- [ ] **Step 6: Write `meal_template_providers.dart`**

```dart
// app/lib/features/meal_templates/data/meal_template_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nourishly_data/nourishly_data.dart';

import '../../../app/providers.dart';
import '../../profile/data/profile_providers.dart';

final mealTemplateDaoProvider = Provider<MealTemplateDao>((ref) {
  return MealTemplateDao(ref.watch(nourishlyDatabaseProvider));
});

/// The profile's saved templates, newest first.
final mealTemplatesProvider = FutureProvider<List<SavedMealTemplate>>((
  ref,
) async {
  ref.watch(mealTemplateRevisionProvider);
  final ownerId = await ref.watch(defaultOwnerProvider.future);
  return ref.watch(mealTemplateDaoProvider).templatesFor(ownerId);
});

/// Bumped after a template is created, applied, or deleted, matching
/// [RecipeRevision]'s pattern in `recipe_providers.dart`.
class MealTemplateRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final mealTemplateRevisionProvider =
    NotifierProvider<MealTemplateRevision, int>(MealTemplateRevision.new);
```

- [ ] **Step 7: Write `meal_templates_screen.dart`**

```dart
// app/lib/features/meal_templates/presentation/screens/meal_templates_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nourishly_data/nourishly_data.dart';
import 'package:nourishly_ui/nourishly_ui.dart';

import '../../../../app/providers.dart';
import '../../data/meal_template_providers.dart';

/// Saved meal templates (screen 7, option A — cards with contents,
/// decisions.md). A template is created from the day log's "Save as
/// template" action, not from a builder here — the household's real
/// templates are meals it has already cooked and logged, not ones typed
/// from scratch.
class MealTemplatesScreen extends ConsumerWidget {
  const MealTemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    final templatesAsync = ref.watch(mealTemplatesProvider);
    final slotsAsync = ref.watch(mealSlotsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Meal templates')),
      body: templatesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(NourishlySpace.s6),
            child: Text('$error', textAlign: TextAlign.center),
          ),
        ),
        data: (templates) {
          final slotNames = {
            for (final slot in slotsAsync.value ?? const [])
              slot.id: slot.displayName,
          };
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              NourishlySpace.s4,
              NourishlySpace.s3,
              NourishlySpace.s4,
              NourishlySpace.s9,
            ),
            children: [
              if (templates.isEmpty)
                NourishlyCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nothing here yet.',
                        style: text.body.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: NourishlySpace.s2),
                      Text(
                        'Save a meal you have already logged as a template: '
                        'open a meal in "By meal" view on the day log and '
                        'tap Save as template. It becomes a one-tap way to '
                        'log the same meal again.',
                        style: text.caption.copyWith(
                          color: colors.ink3,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                )
              else
                for (final template in templates)
                  Padding(
                    padding: const EdgeInsets.only(bottom: NourishlySpace.s3),
                    child: _TemplateCard(
                      template: template,
                      mealSlotName: template.defaultMealSlotId == null
                          ? null
                          : slotNames[template.defaultMealSlotId],
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _TemplateCard extends ConsumerWidget {
  const _TemplateCard({required this.template, required this.mealSlotName});

  final SavedMealTemplate template;
  final String? mealSlotName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;

    return NourishlyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  template.name,
                  style: text.heading,
                ),
              ),
              if (mealSlotName != null)
                StatusChip(label: mealSlotName!, status: NourishlyStatus.unknown),
            ],
          ),
          const SizedBox(height: NourishlySpace.s2),
          for (final item in template.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '${item.foodName}'
                '${item.servingLabel == null ? '' : ' · ${_qty(item.quantity)} × ${item.servingLabel}'}',
                style: text.caption.copyWith(color: colors.ink2),
              ),
            ),
          const SizedBox(height: NourishlySpace.s3),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => _apply(context, ref),
                  child: const Text('Log this meal'),
                ),
              ),
              const SizedBox(width: NourishlySpace.s2),
              IconButton(
                onPressed: () => _delete(context, ref),
                icon: const Icon(Icons.delete_outline_rounded),
                tooltip: 'Delete template',
                color: colors.ink3,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _qty(double quantity) =>
      quantity.toStringAsFixed(quantity % 1 == 0 ? 0 : 1);

  Future<void> _apply(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final ownerId = await ref.read(defaultOwnerProvider.future);
    final logged = await ref
        .read(mealTemplateDaoProvider)
        .applyTemplate(
          templateId: template.id,
          ownerId: ownerId,
          logDate: ref.read(todayProvider),
        );
    ref.read(summaryRevisionProviderRef: null); // placeholder removed below
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showNourishlyConfirm(
      context: context,
      title: 'Delete this template?',
      message: '${template.name} will be removed. Meals already logged '
          'from it are not affected.',
      confirmLabel: 'Delete',
      danger: true,
    );
    if (!confirmed) return;
    await ref.read(mealTemplateDaoProvider).deleteTemplate(template.id);
    ref.read(mealTemplateRevisionProvider.notifier).bump();
  }
}
```

**⚠ Fix before running:** the `_apply` body above has a typo placeholder
(`summaryRevisionProviderRef: null`) — replace it with the real body below,
which bumps `summaryRevisionProvider` (so the dashboard/day-log re-read,
same as every other write path in the app) and shows the count:

```dart
  Future<void> _apply(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final ownerId = await ref.read(defaultOwnerProvider.future);
    final logged = await ref
        .read(mealTemplateDaoProvider)
        .applyTemplate(
          templateId: template.id,
          ownerId: ownerId,
          logDate: ref.read(todayProvider),
        );
    ref.read(summaryRevisionProvider.notifier).bump();
    ref.read(mealTemplateRevisionProvider.notifier).bump();
    if (!context.mounted) return;
    showNourishlySnackOn(
      messenger,
      logged == 0
          ? 'Nothing could be logged — this template has no servings set.'
          : 'Logged $logged item${logged == 1 ? '' : 's'} to today.',
    );
  }
```

(Write the file with this corrected `_apply` directly — the placeholder
above exists only to flag it as a step that needs the fix applied before
first run, per this plan's own no-placeholder rule being satisfied by the
corrected block, not the first one.)

- [ ] **Step 8: Wire the route**

In `app/lib/app/router.dart`:
1. Add the import (alphabetical, after the `goals_screen.dart` import):
```dart
import '../features/meal_templates/presentation/screens/meal_templates_screen.dart';
```
2. Add a new top-level `GoRoute`, placed after the `/recipes` route block (before `StatefulShellRoute.indexedStack`):
```dart
    // Over the shell, like `/recipes` — reached from the add-food flow.
    GoRoute(
      path: '/templates',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const MealTemplatesScreen(),
    ),
```

- [ ] **Step 9: Wire the entry point in `food_logging_screen.dart`**

In `_BrowseByCuisine.build`, replace the stale message and add an always-visible entry row above the cuisine chips. Replace:
```dart
    if (cuisines.isEmpty) {
      return const _Message(
        icon: Icons.search_rounded,
        title: 'Search for a food to log',
        subtitle:
            'Recents, favourites and meal templates arrive in a later phase.',
      );
    }

    final foods = ref.watch(browsedFoodsProvider).value ?? const <FoodItem>[];

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        NourishlySpace.s4,
        0,
        NourishlySpace.s4,
        NourishlySpace.s9,
      ),
      children: [
        Text(
          'Or browse by cuisine',
          style: text.caption.copyWith(color: colors.ink3),
        ),
```
with:
```dart
    if (cuisines.isEmpty) {
      return const _Message(
        icon: Icons.search_rounded,
        title: 'Search for a food to log',
        subtitle: 'Recents and favourites arrive in a later phase.',
      );
    }

    final foods = ref.watch(browsedFoodsProvider).value ?? const <FoodItem>[];

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        NourishlySpace.s4,
        0,
        NourishlySpace.s4,
        NourishlySpace.s9,
      ),
      children: [
        NourishlyCard(
          onTap: () => context.push('/templates'),
          child: Row(
            children: [
              Icon(Icons.repeat_rounded, color: colors.accent, size: 20),
              const SizedBox(width: NourishlySpace.s3),
              Expanded(
                child: Text(
                  'Log from a saved meal template',
                  style: text.label.copyWith(color: colors.accent),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.accent, size: 18),
            ],
          ),
        ),
        const SizedBox(height: NourishlySpace.s3),
        Text(
          'Or browse by cuisine',
          style: text.caption.copyWith(color: colors.ink3),
        ),
```

- [ ] **Step 10: Wire "Save as template" in `day_log_screen.dart`**

In `_ByMealList.build`, replace:
```dart
          for (final slot in slots) ...[
            NourishlySectionHeader(label: slot.displayName),
            for (final food in entries.where(
              (e) => e.entry.mealSlotId == slot.id,
            ))
```
with:
```dart
          for (final slot in slots) ...[
            Builder(
              builder: (context) {
                final slotEntries = entries
                    .where((e) => e.entry.mealSlotId == slot.id)
                    .toList();
                return NourishlySectionHeader(
                  label: slot.displayName,
                  actionLabel: slotEntries.isEmpty
                      ? null
                      : 'Save as template',
                  onActionPressed: slotEntries.isEmpty
                      ? null
                      : () => _saveAsTemplate(context, ref, slot, slotEntries),
                );
              },
            ),
            for (final food in entries.where(
              (e) => e.entry.mealSlotId == slot.id,
            ))
```

Then add these two functions at the bottom of the file (alongside the
existing `_reassignMeal`/`_showEntryActions`/`_deleteEntry` top-level
functions):

```dart
Future<void> _saveAsTemplate(
  BuildContext context,
  WidgetRef ref,
  MealSlot slot,
  List<LoggedFood> entries,
) async {
  final name = await showNourishlyPrompt(
    context: context,
    title: 'Save as template',
    message: '${entries.length} item${entries.length == 1 ? '' : 's'} from '
        '${slot.displayName} will be saved as "${slot.displayName}" — you '
        'can rename it.',
    initialValue: slot.displayName,
    label: 'Template name',
  );
  if (name == null || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  final ownerId = await ref.read(defaultOwnerProvider.future);
  await ref
      .read(mealTemplateDaoProvider)
      .createFromEntries(
        ownerId: ownerId,
        name: name,
        defaultMealSlotId: slot.id,
        items: [
          for (final food in entries)
            MealTemplateItemInput(
              foodId: food.entry.foodId,
              servingSizeId: food.entry.servingSizeId,
              quantity: food.entry.quantity,
            ),
        ],
      );
  ref.read(mealTemplateRevisionProvider.notifier).bump();
  if (!context.mounted) return;
  showNourishlySnackOn(messenger, 'Saved "$name" as a template.');
}
```

Add the import at the top of `day_log_screen.dart`:
```dart
import '../../data/meal_template_providers.dart';
```
(adjust the relative path to match `food_logging`'s existing import style — this file is at
`app/lib/features/food_logging/presentation/screens/day_log_screen.dart`, so the path to
`app/lib/features/meal_templates/data/meal_template_providers.dart` is
`../../../meal_templates/data/meal_template_providers.dart`.)

- [ ] **Step 11: `flutter analyze` and fix any errors**

Run: `cd app && flutter analyze`
Expected: no new errors. Fix anything the compiler flags (in particular:
confirm `MealSlot`'s import is already in scope in `day_log_screen.dart` —
it comes from `nourishly_data`, already imported).

- [ ] **Step 12: Write the widget test**

```dart
// app/test/features/meal_templates/meal_templates_screen_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly/app/app.dart';
import 'package:nourishly/app/providers.dart';
import 'package:nourishly/app/router.dart';
import 'package:nourishly/features/food_catalog/data/food_catalog_providers.dart';
import 'package:nourishly/features/reminders/data/reminder_providers.dart';
import 'package:nourishly_data/nourishly_data.dart';
import 'package:nourishly_ui/nourishly_ui.dart';

void main() {
  late NourishlyDatabase db;
  late String ownerId;
  final now = DateTime(2026, 9, 17, 12, 0);

  setUp(() async {
    db = NourishlyDatabase.forTesting();
    ownerId = await ensureDefaultOwner(db);
    await PreferencesDao(db).update(ownerId, onboardingSeen: true);
    await db
        .into(db.foodItems)
        .insert(
          FoodItemsCompanion.insert(
            id: 'food-dal',
            kind: 'ingredient',
            canonicalName: 'Dal',
            qualityTier: 'verified',
            provenanceSource: 'usda',
          ),
        );
    await db
        .into(db.servingSizes)
        .insert(
          ServingSizesCompanion.insert(
            id: 'serving-dal',
            foodId: 'food-dal',
            label: '1 katori',
            grams: 150,
          ),
        );
    await db
        .into(db.mealSlots)
        .insert(
          MealSlotsCompanion.insert(
            id: 'slot-lunch',
            key: 'lunch',
            displayName: 'Lunch',
            sortOrder: 1,
          ),
        );
    await MealTemplateDao(db).createFromEntries(
      ownerId: ownerId,
      name: 'Usual lunch',
      defaultMealSlotId: 'slot-lunch',
      items: const [
        MealTemplateItemInput(
          foodId: 'food-dal',
          servingSizeId: 'serving-dal',
          quantity: 2,
        ),
      ],
    );
  });

  tearDown(() => db.close());

  Future<void> pumpTemplates(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nourishlyDatabaseProvider.overrideWithValue(db),
          catalogReadyProvider.overrideWith((ref) async {}),
          clockProvider.overrideWithValue(FakeClock(now)),
          reminderSchedulerProvider.overrideWithValue(NoopReminderScheduler()),
        ],
        child: const NourishlyApp(),
      ),
    );
    await tester.pump();
    appRouter.go('/templates');
    await tester.pumpAndSettle();
  }

  testWidgets('shows the saved template with its contents', (tester) async {
    await pumpTemplates(tester);
    expect(find.text('Usual lunch'), findsOneWidget);
    expect(find.textContaining('Dal'), findsOneWidget);
    expect(find.text('Lunch'), findsOneWidget);
  });

  testWidgets('Log this meal creates a food log entry for today', (
    tester,
  ) async {
    await pumpTemplates(tester);
    await tester.tap(find.text('Log this meal'));
    await tester.pumpAndSettle();

    final entries = await db.select(db.foodLogEntries).get();
    expect(entries, hasLength(1));
    expect(entries.single.foodId, 'food-dal');
    expect(entries.single.mealSlotId, 'slot-lunch');
    expect(find.textContaining('Logged 1 item'), findsOneWidget);
  });

  testWidgets('deleting a template removes its card', (tester) async {
    await pumpTemplates(tester);
    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(find.text('Usual lunch'), findsNothing);
    expect(find.textContaining('Nothing here yet'), findsOneWidget);
  });
}
```

- [ ] **Step 13: Run the widget test**

Run: `cd app && flutter test test/features/meal_templates/meal_templates_screen_test.dart -v`
Expected: PASS (all 3 cases).

- [ ] **Step 14: Full app test suite + analyze**

Run: `cd app && flutter analyze && flutter test`
Expected: no regressions in existing suites (`food_logging_screen_test.dart`, `day_log_screen_test.dart`, `browse_by_cuisine_test.dart`, `app/navigation_test.dart` especially — they touch the files this task modified).

- [ ] **Step 15: Commit the app-layer half**

```bash
git add app/lib/features/meal_templates app/lib/app/router.dart \
  app/lib/features/food_logging/presentation/screens/food_logging_screen.dart \
  app/lib/features/food_logging/presentation/screens/day_log_screen.dart \
  app/test/features/meal_templates
git commit -m "feat(app): build the meal templates screen (screen 7)"
```

---

## Task 2: Portion screen nutrient breakdown (P1)

**Files:**
- Modify: `app/lib/features/food_logging/presentation/screens/food_portion_screen.dart`
- Test: `app/test/features/food_logging/food_portion_screen_test.dart` (new)

**Interfaces:**
- Consumes: `nutrientLabelsProvider` (`FutureProvider<Map<String, Nutrient>>`, `app/lib/features/profile/data/profile_providers.dart`), `FoodNutrientValue` (drift row, `foodId`/`nutrientId`/`amountPer100g`).
- Produces: `_FoodPortionScreenState._load()` now returns `(FoodItem, List<ServingSize>, List<FoodNutrientValue>)` — the third element consumed by the new `_NutrientPreview` widget.

- [ ] **Step 1: Write the failing widget test**

```dart
// app/test/features/food_logging/food_portion_screen_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly/app/app.dart';
import 'package:nourishly/app/providers.dart';
import 'package:nourishly/app/router.dart';
import 'package:nourishly/features/food_catalog/data/food_catalog_providers.dart';
import 'package:nourishly/features/reminders/data/reminder_providers.dart';
import 'package:nourishly_data/nourishly_data.dart';
import 'package:nourishly_ui/nourishly_ui.dart';

void main() {
  late NourishlyDatabase db;
  final now = DateTime(2026, 9, 17, 12, 0);

  setUp(() async {
    db = NourishlyDatabase.forTesting();
    final ownerId = await ensureDefaultOwner(db);
    await PreferencesDao(db).update(ownerId, onboardingSeen: true);
    await db
        .into(db.mealSlots)
        .insert(
          MealSlotsCompanion.insert(
            id: 'slot-lunch',
            key: 'lunch',
            displayName: 'Lunch',
            sortOrder: 1,
          ),
        );
    await db
        .into(db.nutrients)
        .insertAll([
          NutrientsCompanion.insert(
            id: 'energy',
            groupId: 'macro',
            displayName: 'Energy',
            canonicalUnit: 'kcal',
            displayPrecision: 0,
            defaultCurveType: 'range',
            sortOrder: 0,
          ),
          NutrientsCompanion.insert(
            id: 'protein',
            groupId: 'macro',
            displayName: 'Protein',
            canonicalUnit: 'g',
            displayPrecision: 1,
            defaultCurveType: 'floor',
            sortOrder: 1,
          ),
        ]);
    await db
        .into(db.foodItems)
        .insert(
          FoodItemsCompanion.insert(
            id: 'food-dal',
            kind: 'ingredient',
            canonicalName: 'Dal',
            qualityTier: 'verified',
            provenanceSource: 'usda',
          ),
        );
    await db
        .into(db.servingSizes)
        .insert(
          ServingSizesCompanion.insert(
            id: 'serving-dal',
            foodId: 'food-dal',
            label: '1 katori',
            grams: 200,
          ),
        );
    await db
        .into(db.foodNutrientValues)
        .insert(
          FoodNutrientValuesCompanion.insert(
            id: 'fnv-1',
            foodId: 'food-dal',
            nutrientId: 'energy',
            amountPer100g: 120,
            valueSource: 'measured',
          ),
        );
    // Protein deliberately has no row — AP-4: renders as "—", never 0.
  });

  tearDown(() => db.close());

  Future<void> pumpPortion(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nourishlyDatabaseProvider.overrideWithValue(db),
          catalogReadyProvider.overrideWith((ref) async {}),
          clockProvider.overrideWithValue(FakeClock(now)),
          reminderSchedulerProvider.overrideWithValue(NoopReminderScheduler()),
        ],
        child: const NourishlyApp(),
      ),
    );
    await tester.pump();
    appRouter.go('/log/food/food-dal');
    await tester.pumpAndSettle();
  }

  testWidgets('shows computed energy for the selected serving', (
    tester,
  ) async {
    await pumpPortion(tester);
    // 1 katori (200 g) at 120 kcal/100g = 240 kcal.
    expect(find.textContaining('240'), findsWidgets);
  });

  testWidgets('a nutrient with no data renders as em dash, not zero', (
    tester,
  ) async {
    await pumpPortion(tester);
    expect(find.text('—'), findsWidgets);
    expect(find.text('0 g'), findsNothing);
  });

  testWidgets('the stale Phase 3 sentence is gone', (tester) async {
    await pumpPortion(tester);
    expect(find.textContaining('Phase 3 aggregation'), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/food_logging/food_portion_screen_test.dart -v`
Expected: FAIL (the "240" and "—" finders find nothing; the stale-sentence
check is the only one that might already pass — irrelevant, run as one
file so the failure is visible).

- [ ] **Step 3: Extend `_load()` and add the nutrient query**

In `food_portion_screen.dart`, change the state's future type and loader:
```dart
  late final Future<(FoodItem, List<ServingSize>, List<FoodNutrientValue>)>
  _food = _load();
```
and in `_load()`, after the existing `servings` query, add:
```dart
    final nutrientValues = await (db.select(
      db.foodNutrientValues,
    )..where((v) => v.foodId.equals(widget.foodId))).get();
```
then change the return to `return (food, servings, nutrientValues);` and
update the `build` method's destructuring:
```dart
          final (food, servings, nutrientValues) = snapshot.data!;
```

- [ ] **Step 4: Replace the stale sentence and add the breakdown widget**

Replace `_FoodHeader`'s trailing `Text('Per-serving nutrients arrive with Phase 3 aggregation…')` block with nothing (delete those lines) — the breakdown itself now carries that information. Then, in `build`'s `ListView` children, insert `_NutrientPreview` right after `_FoodHeader`:
```dart
                    _FoodHeader(food: food),
                    _NutrientPreview(
                      values: nutrientValues,
                      grams: (serving?.grams ?? 0) * _quantity,
                    ),
                    const NourishlySectionHeader(label: 'Serving'),
```

Add the new widget at the end of the file:
```dart
/// The four core macros plus energy, computed for the currently selected
/// serving × quantity (AP-4: a nutrient with no [FoodNutrientValue] row
/// for this food renders as "—", never 0 — mirrors
/// `daily_report_screen.dart`'s `_NutrientRow`).
class _NutrientPreview extends ConsumerWidget {
  const _NutrientPreview({required this.values, required this.grams});

  final List<FoodNutrientValue> values;
  final double grams;

  static const _tracked = ['energy', 'protein', 'carbs', 'fat', 'fibre'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    final labelsAsync = ref.watch(nutrientLabelsProvider);
    final labels = labelsAsync.value ?? const <String, Nutrient>{};
    final byNutrient = {for (final v in values) v.nutrientId: v};

    return NourishlyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final id in _tracked)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    labels[id]?.displayName ?? id,
                    style: text.caption.copyWith(color: colors.ink3),
                  ),
                  Text(
                    _amount(byNutrient[id], labels[id], grams),
                    style: text.body.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _amount(FoodNutrientValue? value, Nutrient? nutrient, double grams) {
    if (value == null) return '—';
    final amount = value.amountPer100g * grams / 100;
    final unit = nutrient?.canonicalUnit ?? '';
    final precision = nutrient?.displayPrecision ?? 0;
    return '${amount.toStringAsFixed(precision)} $unit'.trim();
  }
}
```

- [ ] **Step 5: `flutter analyze`, then run the widget test**

Run: `cd app && flutter analyze`
Expected: no errors (confirm `nutrientLabelsProvider` import resolves —
already imported transitively via `nourishly_data.dart`/`profile_providers.dart`;
add `import '../../../profile/data/profile_providers.dart';` to
`food_portion_screen.dart` if analyze flags it as undefined).

Run: `cd app && flutter test test/features/food_logging/food_portion_screen_test.dart -v`
Expected: PASS (all 3 cases).

- [ ] **Step 6: Full suite + analyze, then commit**

Run: `cd app && flutter analyze && flutter test`
Expected: no regressions, especially `food_logging_screen_test.dart` and
`a11y/accessibility_test.dart` (this screen's semantics changed).

```bash
git add app/lib/features/food_logging/presentation/screens/food_portion_screen.dart \
  app/test/features/food_logging/food_portion_screen_test.dart
git commit -m "fix(app): show a per-serving nutrient preview on the portion screen"
```

---

## Task 3: Water target consistency (P1)

**Files:**
- Modify: `app/lib/features/water/presentation/screens/water_screen.dart`
- Modify: `app/test/features/water/water_message_test.dart` (only if the hardcoded `defaultGoalMl` percentage math it silently relied on changes any existing assertion — check after Step 3, no edit expected since those tests don't assert on percentage text)
- Test: `app/test/features/water/water_target_test.dart` (new)

**Interfaces:**
- Consumes: `daySummaryProvider(DateTime) → FutureProvider<DaySummary>` (existing, `profile_providers.dart`), `DaySummary.waterTargetMl` (existing field), `todayProvider` (existing).

- [ ] **Step 1: Write the failing test**

```dart
// app/test/features/water/water_target_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly/app/app.dart';
import 'package:nourishly/app/providers.dart';
import 'package:nourishly/app/router.dart';
import 'package:nourishly/features/food_catalog/data/food_catalog_providers.dart';
import 'package:nourishly/features/reminders/data/reminder_providers.dart';
import 'package:nourishly_data/nourishly_data.dart';
import 'package:nourishly_domain/nourishly_domain.dart';
import 'package:nourishly_ui/nourishly_ui.dart';

void main() {
  late NourishlyDatabase db;
  late String ownerId;
  final now = DateTime(2026, 9, 17, 10, 0);

  setUp(() async {
    db = NourishlyDatabase.forTesting();
    ownerId = await ensureDefaultOwner(db);
    await PreferencesDao(db).update(ownerId, onboardingSeen: true);
  });

  tearDown(() => db.close());

  Future<void> pumpWater(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nourishlyDatabaseProvider.overrideWithValue(db),
          catalogReadyProvider.overrideWith((ref) async {}),
          clockProvider.overrideWithValue(FakeClock(now)),
          reminderSchedulerProvider.overrideWithValue(NoopReminderScheduler()),
        ],
        child: const NourishlyApp(),
      ),
    );
    await tester.pump();
    appRouter.go('/water');
    await tester.pumpAndSettle();
  }

  testWidgets(
    'with a derived target set, the percentage matches the Goals screen, '
    'not a hardcoded default',
    (tester) async {
      final dao = ProfileDao(db);
      final setId = await dao.startTargetSet(ownerId: ownerId, effectiveFrom: now);
      await dao.setTarget(
        targetSetId: setId,
        nutrientId: 'water',
        amount: 3000,
        source: 'derived',
      );
      await WaterLogDao(
        db,
      ).logWater(ownerId: ownerId, volumeMl: 1500, logDate: DateTime(2026, 9, 17));

      await pumpWater(tester);

      // 1500 / 3000 = 50%, not 1500/2600 ≈ 58%.
      expect(find.textContaining('50%'), findsOneWidget);
      expect(find.textContaining('58%'), findsNothing);
    },
  );

  testWidgets('with no target set, falls back to a stated default', (
    tester,
  ) async {
    await pumpWater(tester);
    expect(find.textContaining('% of'), findsOneWidget);
  });
}
```

If `ProfileDao.startTargetSet`/`setTarget` have different exact names,
grep `packages/nourishly_data/lib/src/dao/profile_dao.dart` for the real
target-writing method before running this — use whatever it actually
exposes for writing a `NutrientTarget` row keyed `'water'`; the shape of
the assertion (percentage matches the derived target, not 2600) is what
matters, not the exact seeding call.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/water/water_target_test.dart -v`
Expected: FAIL on the first case (percentage is computed from 2600, not 3000).

- [ ] **Step 3: Fix `water_screen.dart`**

Change the class from `ConsumerWidget` reading a `static const double defaultGoalMl` to reading the real target with a stated fallback. Replace:
```dart
class WaterScreen extends ConsumerWidget {
  const WaterScreen({super.key});

  /// A placeholder daily goal so the fill visual has a proportion to show.
  /// Real per-profile hydration targets are derived in Phase 3 (§27.12);
  /// this is labelled as a default in the UI rather than presented as a
  /// derived target.
  static const double defaultGoalMl = 2600;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    final entriesAsync = ref.watch(todayWaterLogProvider);
    final totalMl = ref.watch(todayWaterTotalProvider);
    final percent = ((totalMl / defaultGoalMl) * 100).clamp(0, 999).round();
```
with:
```dart
class WaterScreen extends ConsumerWidget {
  const WaterScreen({super.key});

  /// Used only when no derived or manual water target exists yet (no
  /// profile set up) — so the fill visual still has a proportion to show.
  /// Whenever a real target exists (`DaySummary.waterTargetMl`, the same
  /// field `WaterCard` on the dashboard and the Goals screen both read),
  /// that value is used instead, so this screen never disagrees with the
  /// rest of the app about what "today's target" means.
  static const double fallbackGoalMl = 2600;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    final entriesAsync = ref.watch(todayWaterLogProvider);
    final totalMl = ref.watch(todayWaterTotalProvider);
    final summary = ref.watch(daySummaryProvider(ref.watch(todayProvider))).value;
    final goalMl = summary?.waterTargetMl ?? fallbackGoalMl;
    final isDerived = summary?.waterTargetMl != null;
    final percent = ((totalMl / goalMl) * 100).clamp(0, 999).round();
```

Then replace the two remaining `defaultGoalMl` uses:
```dart
                    child: StatusChip(
                      label: '$percent% of default',
```
→
```dart
                    child: StatusChip(
                      label: isDerived ? '$percent% of target' : '$percent% of default',
```
and:
```dart
                    WaterVessel(totalMl: totalMl, goalMl: defaultGoalMl),
```
→
```dart
                    WaterVessel(totalMl: totalMl, goalMl: goalMl),
```

Add the import for `daySummaryProvider`/`todayProvider` if not already in
scope — `todayProvider` is already imported via `app/providers.dart`; add:
```dart
import '../../profile/data/profile_providers.dart';
```
(only if `daySummaryProvider` isn't already reachable — check the existing
import list first; `WaterScreen` currently only imports
`../../../../app/providers.dart`, so this new import is needed).

- [ ] **Step 4: `flutter analyze`, then run both new tests**

Run: `cd app && flutter analyze`
Expected: no errors.

Run: `cd app && flutter test test/features/water/water_target_test.dart -v`
Expected: PASS (both cases).

- [ ] **Step 5: Run the existing water test to confirm no regression**

Run: `cd app && flutter test test/features/water/water_message_test.dart -v`
Expected: PASS unchanged (those tests don't assert on the percentage text).

- [ ] **Step 6: Commit**

```bash
git add app/lib/features/water/presentation/screens/water_screen.dart \
  app/test/features/water/water_target_test.dart
git commit -m "fix(app): read the real derived water target instead of a hardcoded 2600ml"
```

---

## Task 4: Nav tab label mismatch (P2)

**Files:**
- Modify: `app/lib/app/shell/nourishly_shell.dart`
- Modify: `app/test/app/navigation_test.dart` (check for a `'Profile'` text assertion tied to this tab; update it — read the file first, this plan does not assume its exact current content)

**Decision:** relabel the tab to **"Settings"** (matches what it actually
opens — `SettingsScreen`'s own app-bar title) rather than rerouting it to
`/profile/me`, because `/profile` is also the parent route for Goals,
Reminders, and Data — a bare person icon opening a settings *list* reads
correctly once it says "Settings"; rerouting the tab straight to the
profile would strand those under a tab that no longer visibly leads to
them.

- [ ] **Step 1: Read `app/test/app/navigation_test.dart` and note any assertion on the word "Profile" as this tab's label**

Run: `grep -n "'Profile'" app/test/app/navigation_test.dart`

- [ ] **Step 2: Write/update the failing test**

If the grep found a tab-label assertion like `expect(find.text('Profile'), findsOneWidget);` tied to the bottom nav (not to the `/profile/me` screen's own app bar, which legitimately says "Profile"), change it to expect `'Settings'`. Also add a new explicit case if none exists:

```dart
  testWidgets('the settings tab is labelled Settings, matching the screen it opens', (
    tester,
  ) async {
    // ... reuse this file's existing pump helper ...
    await tester.tap(find.text('Settings').first);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Settings'), findsOneWidget);
  });
```

(Match this file's existing pump-helper name and override list exactly —
read the file first; do not invent a second helper if one already pumps
`NourishlyApp` for navigation tests.)

- [ ] **Step 3: Run to verify it fails**

Run: `cd app && flutter test test/app/navigation_test.dart -v`
Expected: FAIL — the tab still reads "Profile".

- [ ] **Step 4: Fix `nourishly_shell.dart`**

Replace:
```dart
  static const _items = [
    NourishlyBottomNavItem(icon: Icons.access_time_rounded, label: 'Today'),
    NourishlyBottomNavItem(icon: Icons.bar_chart_rounded, label: 'Insights'),
    NourishlyBottomNavItem(icon: Icons.water_drop_rounded, label: 'Water'),
    NourishlyBottomNavItem(icon: Icons.person_rounded, label: 'Profile'),
  ];
```
with:
```dart
  // Labelled "Settings", not "Profile": the tab opens SettingsScreen
  // (app-bar title "Settings"), and the actual profile lives one level
  // deeper at /profile/me, reached from the first row inside Settings
  // (decisions.md, "Screen 13 — the profile is its own screen"). The
  // route path stays /profile — it's the branch's root, covering Goals,
  // Reminders and Data too — only the tab's label changes.
  static const _items = [
    NourishlyBottomNavItem(icon: Icons.access_time_rounded, label: 'Today'),
    NourishlyBottomNavItem(icon: Icons.bar_chart_rounded, label: 'Insights'),
    NourishlyBottomNavItem(icon: Icons.water_drop_rounded, label: 'Water'),
    NourishlyBottomNavItem(
      icon: Icons.settings_rounded,
      label: 'Settings',
    ),
  ];
```

(Icon changed from `person_rounded` to `settings_rounded` to match the new
label — a gear reads as "settings" the way a person icon reads as
"profile"; keeping the person icon under a "Settings" label would just
relocate the mismatch from the text to the icon.)

- [ ] **Step 5: `flutter analyze`, then run the test**

Run: `cd app && flutter analyze && flutter test test/app/navigation_test.dart -v`
Expected: PASS.

- [ ] **Step 6: Full suite, then commit**

Run: `cd app && flutter test`
Expected: no regressions (grep the whole `app/test` tree for any other
hardcoded `'Profile'` tab-label assertion this change might break: `grep -rn "find.text('Profile')" app/test`).

```bash
git add app/lib/app/shell/nourishly_shell.dart app/test/app/navigation_test.dart
git commit -m "fix(app): relabel the settings tab from Profile to Settings"
```

---

## Task 5: Draft persistence for an in-progress food log (P2)

**Files:**
- Modify: `app/lib/features/food_logging/presentation/screens/food_portion_screen.dart`
- Test: extend `app/test/features/food_logging/food_portion_screen_test.dart`

**Scope decision:** survive an in-app backgrounding/interruption
(`RestorationMixin`, Flutter's own state-restoration API — covers the
"phone call, stove needing attention" scenario the critique named), not a
full app-restart-after-OS-kill guarantee (which would need writing every
keystroke to disk and is a much bigger, riskier change for a P2). This
matches what `RestorationMixin` actually promises: state survives the
engine being backgrounded and the OS reclaiming memory while the app
*process* is kept in the recents list, which is the common "interrupted,
not force-quit" case.

- [ ] **Step 1: Write the failing test**

```dart
// append to app/test/features/food_logging/food_portion_screen_test.dart
  testWidgets('quantity survives a simulated state restoration', (
    tester,
  ) async {
    await pumpPortion(tester);

    await tester.tap(find.byIcon(Icons.add_circle_outline_rounded));
    await tester.pumpAndSettle();
    // Default 1 → 1.5 after one tap.
    expect(find.text('1.5'), findsOneWidget);

    // Simulate the engine restoring state after being backgrounded and
    // reclaimed, the way RestorationMixin's runtime does on a real device.
    await tester.restoreFrom(await tester.getRestorationData());
    await tester.pumpAndSettle();

    expect(find.text('1.5'), findsOneWidget);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/food_logging/food_portion_screen_test.dart -v`
Expected: FAIL — `tester.getRestorationData()`/`restoreFrom` need
`restorationScopeId` set on the app (check `app/lib/app/app.dart` for
`MaterialApp.router`'s `restorationScopeId`; if absent, add
`restorationScopeId: 'nourishly'` to it as part of this step, since
`RestorationMixin` does nothing without a scope above it), and even with
scope enabled the quantity resets today.

- [ ] **Step 3: Ensure the app has a restoration scope**

In `app/lib/app/app.dart`, find the `MaterialApp.router(` call and add
`restorationScopeId: 'nourishly',` as one of its named arguments (read the
file first to place it consistently with existing formatting).

- [ ] **Step 4: Make `_FoodPortionScreenState` a `RestorationMixin`**

Change the class declaration and add restoration properties. Replace:
```dart
class _FoodPortionScreenState extends ConsumerState<FoodPortionScreen> {
  late final Future<(FoodItem, List<ServingSize>, List<FoodNutrientValue>)>
  _food = _load();
  double _quantity = 1;
  String? _servingId;
  String? _mealSlotId;
  bool _saving = false;
```
with:
```dart
class _FoodPortionScreenState extends ConsumerState<FoodPortionScreen>
    with RestorationMixin {
  late final Future<(FoodItem, List<ServingSize>, List<FoodNutrientValue>)>
  _food = _load();
  final RestorableDouble _quantity = RestorableDouble(1);
  final RestorableStringN _servingId = RestorableStringN(null);
  final RestorableStringN _mealSlotId = RestorableStringN(null);
  bool _saving = false;

  @override
  String? get restorationId => 'food_portion_${widget.foodId}';

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_quantity, 'quantity');
    registerForRestoration(_servingId, 'servingId');
    registerForRestoration(_mealSlotId, 'mealSlotId');
  }

  @override
  void dispose() {
    _quantity.dispose();
    _servingId.dispose();
    _mealSlotId.dispose();
    super.dispose();
  }
```

Every other reference to `_quantity`, `_servingId`, `_mealSlotId` in the
file changes from a bare double/String? to `.value`:
- `initState`: `_mealSlotId = widget.initialMealSlotId;` → `_mealSlotId.value = widget.initialMealSlotId;`
- `_load()`: `_quantity = entry.quantity;` → `_quantity.value = entry.quantity;`, same pattern for `_servingId`/`_mealSlotId`.
- `_save()`: every read of `_servingId`/`_mealSlotId`/`_quantity` becomes `_servingId.value`/`_mealSlotId.value`/`_quantity.value` (`if (_servingId == null || ...)` → `if (_servingId.value == null || ...)`, `servingId: _servingId!` → `servingId: _servingId.value!`, etc).
- `build()`: `_servingId ??= servings.firstOrNull?.id;` → `_servingId.value ??= servings.firstOrNull?.id;`; every `selectedId: _servingId` → `selectedId: _servingId.value`; every `onSelected: (id) => setState(() => _servingId = id)` → `onSelected: (id) => setState(() => _servingId.value = id)`; same pattern for `_mealSlotId` and `_quantity` (`quantity: _quantity` → `quantity: _quantity.value`, `onChanged: (q) => setState(() => _quantity = q)` → `onChanged: (q) => setState(() => _quantity.value = q)`); `enabled: !_saving && _servingId != null && _mealSlotId != null` → `enabled: !_saving && _servingId.value != null && _mealSlotId.value != null`.
- `_MealChips.onDefault` callback `(id) => _mealSlotId ??= id` → `(id) => _mealSlotId.value ??= id`.

Grep after editing to confirm nothing was missed:
```bash
grep -n "_quantity\b\|_servingId\b\|_mealSlotId\b" app/lib/features/food_logging/presentation/screens/food_portion_screen.dart
```
Every occurrence should be `_quantity.value`, `_servingId.value`, or
`_mealSlotId.value` (the field declarations themselves are the only
bare-name lines).

- [ ] **Step 5: `flutter analyze`, then run the new + full portion test file**

Run: `cd app && flutter analyze`
Expected: no errors — this is a mechanical rename, but `RestorableDouble`/
`RestorableStringN` come from `package:flutter/widgets.dart`, already
transitively imported via `package:flutter/material.dart`.

Run: `cd app && flutter test test/features/food_logging/food_portion_screen_test.dart -v`
Expected: PASS (all cases, including the new restoration one).

- [ ] **Step 6: Full suite + analyze**

Run: `cd app && flutter analyze && flutter test`
Expected: no regressions — `day_log_screen_test.dart` navigates to this
screen for editing, worth double-checking manually in the output.

- [ ] **Step 7: Commit**

```bash
git add app/lib/app/app.dart \
  app/lib/features/food_logging/presentation/screens/food_portion_screen.dart \
  app/test/features/food_logging/food_portion_screen_test.dart
git commit -m "fix(app): survive a backgrounding interruption mid food-log entry"
```

---

## Final Step: full verification and wrap-up

- [ ] Run `cd app && flutter analyze` — zero errors.
- [ ] Run `cd app && flutter test` — full suite green.
- [ ] Run `cd packages/nourishly_data && flutter test` — full suite green.
- [ ] `git log --oneline` on this branch shows 6 commits (5 fixes; Task 1 split into a data-layer and app-layer commit makes 6 total across the 5 tasks).
- [ ] Report to the user: what changed per task, test counts, and that `/impeccable critique` is ready to re-run for a fresh score.
