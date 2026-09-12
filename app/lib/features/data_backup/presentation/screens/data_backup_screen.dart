import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nourishly_data/nourishly_data.dart' hide NutrientTarget;
import 'package:nourishly_ui/nourishly_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/providers.dart';
import '../../../../shared/app_version.dart';
import '../../../../shared/formatting.dart';
import '../../../food_catalog/data/food_catalog_providers.dart';
import '../../../profile/data/profile_providers.dart';
import '../../data/backup_providers.dart';
import '../../data/export_file_type.dart';
import '../../../reminders/data/reminder_providers.dart';
import '../../data/export_service.dart';

/// Your data (§0.5, §30.6, §30.7) — reached from prototype 13A's third
/// group, and following the same grouped-list treatment.
///
/// The screen has one job the rest of the app does not: it is the only
/// place a user can lose everything, and the only place they can make sure
/// they do not. So it says what the platform does for them, what it does
/// not, and what they can do themselves — in that order, because that is
/// the order in which the answers stop being automatic.
class DataBackupScreen extends ConsumerStatefulWidget {
  const DataBackupScreen({super.key});

  @override
  ConsumerState<DataBackupScreen> createState() => _DataBackupScreenState();
}

class _DataBackupScreenState extends ConsumerState<DataBackupScreen> {
  double? _progress;
  String? _busyLabel;

  bool get _busy => _busyLabel != null;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    final lastExport = ref.watch(lastExportedAtProvider);
    final catalog = ref.watch(catalogVersionProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Your data')),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(
                NourishlySpace.s4,
                NourishlySpace.s2,
                NourishlySpace.s4,
                NourishlySpace.s7,
              ),
              children: [
                const NourishlySectionHeader(label: 'Automatic backup'),
                NourishlyCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        Platform.isIOS
                            ? 'Nourishly is included in your iPhone backup, '
                                  'so restoring this phone or setting up a '
                                  'new one brings your logging with it.'
                            : 'Nourishly is included in your phone’s '
                                  'automatic backup to your own Google '
                                  'account, so a new phone restores your '
                                  'logging with it.',
                        style: text.body.copyWith(height: 1.5),
                      ),
                      const SizedBox(height: NourishlySpace.s2),
                      Text(
                        // Stated plainly because it is the failure mode
                        // that actually happens: the automatic backup runs
                        // on the platform's schedule, not yours, and it
                        // cannot be checked from in here.
                        'It runs on your phone’s own schedule, and '
                        'nothing in this app can confirm it has. An export '
                        'you keep yourself is the copy you can verify.',
                        style: text.caption.copyWith(
                          color: colors.ink3,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),

                const NourishlySectionHeader(label: 'Export everything'),
                NourishlyCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final format in ExportFormat.values)
                        _ActionRow(
                          title: 'Export as ${format.label}',
                          subtitle: format.description,
                          enabled: !_busy,
                          onTap: () => _export(format),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: NourishlySpace.s2),
                  child: Text(
                    lastExport == null
                        ? 'You have not exported yet.'
                        : 'Last export: ${formatLongDate(lastExport)}.',
                    style: text.caption.copyWith(color: colors.ink3),
                  ),
                ),

                const NourishlySectionHeader(label: 'Import'),
                NourishlyCard(
                  padding: EdgeInsets.zero,
                  child: _ActionRow(
                    title: 'Import a JSON export',
                    subtitle:
                        'Merges by entry. Importing the same file twice '
                        'changes nothing, and an older file never overwrites '
                        'newer logging.',
                    enabled: !_busy,
                    onTap: _import,
                  ),
                ),

                const NourishlySectionHeader(label: 'Delete'),
                NourishlyCard(
                  padding: EdgeInsets.zero,
                  child: _ActionRow(
                    title: 'Delete everything on this phone',
                    subtitle:
                        'Every entry, every custom food, your profile and '
                        'your targets. This cannot be undone.',
                    destructive: true,
                    enabled: !_busy,
                    onTap: _confirmDelete,
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.only(top: NourishlySpace.s5),
                  child: Text(
                    'Nourishly $appVersion'
                    '${catalog == null ? '' : ' · catalog $catalog'}'
                    ' · all data stays on this phone',
                    textAlign: TextAlign.center,
                    style: text.caption.copyWith(color: colors.ink3),
                  ),
                ),
              ],
            ),
            if (_busy) _BusyOverlay(label: _busyLabel!, progress: _progress),
          ],
        ),
      ),
    );
  }

  Future<void> _export(ExportFormat format) async {
    final messenger = ScaffoldMessenger.of(context);
    final colors = context.nourishlyColors;
    setState(() {
      _busyLabel = 'Writing your ${format.label} export…';
      _progress = 0;
    });
    try {
      final ownerId = await ref.read(defaultOwnerProvider.future);
      final result = await ref
          .read(exportServiceProvider)
          .export(
            ownerId: ownerId,
            format: format,
            rulesetVersion: rulesetVersion,
            appVersion: appVersion,
            onProgress: (fraction) {
              if (mounted) setState(() => _progress = fraction);
            },
          );

      await ref
          .read(preferencesDaoProvider)
          .update(
            ownerId,
            lastExportedAt: result.exportedAt,
            // Taking a copy answers the prompt, whether or not it was
            // showing.
            exportPromptSnoozedUntil: result.exportedAt.add(
              const Duration(days: 30),
            ),
          );
      ref.read(summaryRevisionProvider.notifier).bump();

      await SharePlus.instance.share(
        ShareParams(
          files: [for (final file in result.files) XFile(file.path)],
          subject: 'Nourishly export',
          text:
              '${formatThousands(result.rowCount)} rows, '
              '${_sizeLabel(result.bytes)}.',
        ),
      );

      showNourishlySnackOn(
        messenger,
        '${formatThousands(result.rowCount)} rows exported. Keep this file '
        'somewhere that is not this phone.',
      );
    } on Object catch (error) {
      showNourishlySnackOn(
        messenger,
        'The export did not finish: $error',
        isError: true,
        colors: colors,
      );
    } finally {
      if (mounted) setState(() => _busyLabel = null);
    }
  }

  Future<void> _import() async {
    final messenger = ScaffoldMessenger.of(context);
    final colors = context.nourishlyColors;

    // Inside the try, deliberately. This call used to sit outside it, so
    // when the picker threw there was no snackbar, no dialog and no
    // spinner — the button simply did nothing, which is the one failure
    // mode a user cannot report usefully or work around.
    final XFile? file;
    try {
      file = await openFile(
        acceptedTypeGroups: const [nourishlyExportFileType],
      );
    } on Object catch (error) {
      showNourishlySnackOn(
        messenger,
        'Could not open the file picker: $error',
        isError: true,
        colors: colors,
      );
      return;
    }
    if (file == null) return;

    setState(() {
      _busyLabel = 'Reading the file…';
      _progress = 0;
    });
    try {
      final ownerId = await ref.read(defaultOwnerProvider.future);
      final report = await ref
          .read(exportServiceProvider)
          .import(
            file: File(file.path),
            ownerId: ownerId,
            onProgress: (fraction) {
              if (mounted) setState(() => _progress = fraction);
            },
          );
      ref.read(summaryRevisionProvider.notifier).bump();

      if (!mounted) return;
      await showNourishlyDialog<void>(
        context: context,
        builder: (context) => _ImportReportDialog(report: report),
      );
    } on ExportFormatException catch (error) {
      showNourishlySnackOn(
        messenger,
        error.message,
        isError: true,
        colors: colors,
      );
    } on Object catch (error) {
      showNourishlySnackOn(
        messenger,
        'The import did not finish: $error',
        isError: true,
        colors: colors,
      );
    } finally {
      if (mounted) setState(() => _busyLabel = null);
    }
  }

  /// §30.7: two steps, export offered first, and irreversibility stated
  /// rather than implied. No dark patterns — but no one-tap either.
  Future<void> _confirmDelete() async {
    final offered = await showNourishlyDialog<_DeleteChoice>(
      context: context,
      builder: (context) => NourishlyDialog(
        title: 'Delete everything?',
        icon: Icons.delete_forever_rounded,
        danger: true,
        message:
            'This removes every entry, every custom food, your profile and '
            'your targets from this phone. It cannot be undone, and an '
            'automatic phone backup taken after this will not contain them '
            'either.\n\nWould you like to export a copy first?',
        actions: [
          NourishlyDialogAction(
            label: 'Cancel',
            onPressed: () => Navigator.of(context).pop(_DeleteChoice.cancel),
          ),
          NourishlyDialogAction(
            label: 'Export first',
            onPressed: () =>
                Navigator.of(context).pop(_DeleteChoice.exportFirst),
          ),
          NourishlyDialogAction(
            label: 'Continue',
            isPrimary: true,
            danger: true,
            onPressed: () =>
                Navigator.of(context).pop(_DeleteChoice.continueToDelete),
          ),
        ],
      ),
    );

    if (offered == _DeleteChoice.exportFirst) {
      await _export(ExportFormat.json);
      return;
    }
    if (offered != _DeleteChoice.continueToDelete || !mounted) return;

    // Step two: a typed confirmation, and the confirming button stays
    // disabled until the word is actually typed — it used to accept the tap
    // and then silently do nothing, which reads as a broken button.
    final typed = await showNourishlyPrompt(
      context: context,
      title: 'Type DELETE to confirm',
      icon: Icons.delete_forever_rounded,
      danger: true,
      message:
          'The one destructive action in the app is the one place a stray '
          'tap must not be enough.',
      label: 'Confirmation',
      hint: 'DELETE',
      confirmLabel: 'Delete everything',
      textCapitalization: TextCapitalization.characters,
      validator: (value) => value.toUpperCase() == 'DELETE',
    );
    final confirmed = typed?.toUpperCase() == 'DELETE';
    if (!confirmed || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final colors = context.nourishlyColors;
    setState(() {
      _busyLabel = 'Deleting…';
      _progress = null;
    });
    try {
      final ownerId = await ref.read(defaultOwnerProvider.future);
      await ref.read(profileEraserProvider).eraseEverything(ownerId);

      // Housekeeping after the deletion, not part of it, and deliberately
      // not awaited.
      //
      // Clearing leftover export files still matters — §30.3 does not
      // want a complete unencrypted archive of somebody's food diary
      // sitting in app storage after they asked for it all to go — but
      // walking a directory is not something to make the user watch,
      // and neither it nor cancelling notifications failing would mean
      // the data is still there. Reporting either as a failed deletion
      // would be a lie in the more alarming direction.
      unawaited(
        Future.wait([
          ref.read(exportServiceProvider).clearGenerated(),
          ref.read(reminderSchedulerProvider).cancelAll(),
        ]).catchError((Object error) {
          debugPrint('Nourishly: post-deletion cleanup failed ($error).');
          return <void>[];
        }),
      );

      ref.read(summaryRevisionProvider.notifier).bump();
      // §30.7: the app returns to a fresh state, not an error state.
      showNourishlySnackOn(
        messenger,
        'Deleted. Nourishly is back to a clean start.',
      );
    } on Object catch (error) {
      showNourishlySnackOn(
        messenger,
        'The deletion did not finish: $error',
        isError: true,
        colors: colors,
      );
    } finally {
      if (mounted) setState(() => _busyLabel = null);
    }
  }

  static String _sizeLabel(int bytes) {
    if (bytes < 1024) return '$bytes bytes';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

enum _DeleteChoice { cancel, exportFirst, continueToDelete }

/// §0.5's reconciliation rule, made visible.
///
/// The report is shown rather than collapsed into "Imported": an import is
/// the one operation where "it worked" needs evidence, and the per-entity
/// counts are that evidence. A user restoring a phone deserves to see that
/// 412 entries went in and 412 entries are there.
class _ImportReportDialog extends StatelessWidget {
  const _ImportReportDialog({required this.report});

  final ImportReport report;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    final changed = report.entities
        .where((e) => e.inserted > 0 || e.updated > 0)
        .toList();

    return NourishlyDialog(
      title: report.succeeded ? 'Imported' : 'Imported with gaps',
      icon: report.succeeded
          ? Icons.check_circle_outline_rounded
          : Icons.info_outline_rounded,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            report.succeeded
                ? '${formatThousands(report.totalInserted)} added, '
                      '${formatThousands(report.totalUpdated)} updated, '
                      '${formatThousands(report.totalSkipped)} already '
                      'newer here.'
                : 'Some rows in the file did not make it. Nothing already '
                      'on this phone was changed by the ones that failed.',
            style: text.body.copyWith(height: 1.5),
          ),
          if (changed.isEmpty && report.succeeded)
            Padding(
              padding: const EdgeInsets.only(top: NourishlySpace.s2),
              child: Text(
                'Everything in the file was already here.',
                style: text.caption.copyWith(color: colors.ink3),
              ),
            ),
          for (final entity in changed)
            Padding(
              padding: const EdgeInsets.only(top: NourishlySpace.s1),
              child: Text(
                '${_label(entity.table)}: ${entity.inserted} added'
                '${entity.updated > 0 ? ', ${entity.updated} updated' : ''}',
                style: text.caption.copyWith(color: colors.ink3),
              ),
            ),
          for (final entity in report.unreconciled)
            Padding(
              padding: const EdgeInsets.only(top: NourishlySpace.s1),
              child: Text(
                '${_label(entity.table)}: ${entity.missing} missing',
                style: text.caption.copyWith(color: colors.danger),
              ),
            ),
          if (report.daysAffected > 0)
            Padding(
              padding: const EdgeInsets.only(top: NourishlySpace.s3),
              child: Text(
                '${report.daysAffected} '
                '${report.daysAffected == 1 ? 'day' : 'days'} will be '
                'recalculated the next time you open them.',
                style: text.caption.copyWith(color: colors.ink3, height: 1.5),
              ),
            ),
        ],
      ),
      actions: [
        NourishlyDialogAction(
          label: 'Done',
          isPrimary: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  static String _label(String table) => switch (table) {
    'food_log_entries' => 'Food entries',
    'log_entry_nutrients' => 'Nutrient snapshots',
    'water_log_entries' => 'Water',
    'food_items' => 'Custom foods and recipes',
    'meal_templates' => 'Templates',
    'body_weight_entries' => 'Weight',
    'reminder_rules' => 'Reminders',
    'target_sets' => 'Target sets',
    _ => table.replaceAll('_', ' '),
  };
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.enabled,
    this.destructive = false,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: NourishlySpace.s4,
            vertical: NourishlySpace.s3,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: text.body.copyWith(
                        color: destructive
                            ? colors.danger
                            : enabled
                            ? colors.ink
                            : colors.inkDisabled,
                        fontWeight: destructive
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: text.caption.copyWith(
                        color: colors.ink3,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (!destructive)
                Icon(Icons.chevron_right_rounded, size: 20, color: colors.ink3),
            ],
          ),
        ),
      ),
    );
  }
}

class _BusyOverlay extends StatelessWidget {
  const _BusyOverlay({required this.label, this.progress});

  final String label;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    return Positioned.fill(
      child: ColoredBox(
        color: colors.scrim,
        child: Center(
          child: NourishlyCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 200,
                  child: LinearProgressIndicator(value: progress),
                ),
                const SizedBox(height: NourishlySpace.s3),
                Text(label, style: text.caption.copyWith(color: colors.ink2)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
