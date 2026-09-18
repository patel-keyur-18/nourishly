import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nourishly_data/nourishly_data.dart';
import 'package:nourishly_ui/nourishly_ui.dart';

import '../../../../app/providers.dart';
import '../../../profile/data/profile_providers.dart';
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
              Expanded(child: Text(template.name, style: text.heading)),
              if (mealSlotName != null) NourishlyChip(label: mealSlotName!),
            ],
          ),
          if (template.energyKcal != null || template.useCount > 0) ...[
            const SizedBox(height: NourishlySpace.s1),
            Text(
              [
                if (template.energyKcal != null)
                  '~${template.energyKcal!.round()} kcal',
                if (template.useCount > 0)
                  'Used ${template.useCount} '
                      'time${template.useCount == 1 ? '' : 's'}',
              ].join(' · '),
              style: text.caption.copyWith(color: colors.ink3),
            ),
          ],
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

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showNourishlyConfirm(
      context: context,
      title: 'Delete this template?',
      message:
          '${template.name} will be removed. Meals already logged '
          'from it are not affected.',
      confirmLabel: 'Delete',
      danger: true,
    );
    if (!confirmed) return;
    await ref.read(mealTemplateDaoProvider).deleteTemplate(template.id);
    ref.read(mealTemplateRevisionProvider.notifier).bump();
  }
}
