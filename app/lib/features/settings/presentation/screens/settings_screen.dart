import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nourishly_ui/nourishly_ui.dart';

/// Profile, goals, preferences and data (prototype screen 13, option A —
/// grouped list).
///
/// Rows whose feature has not been built yet say so when tapped rather
/// than opening a dead screen; only Goals & targets navigates today.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            NourishlySpace.s4,
            NourishlySpace.s2,
            NourishlySpace.s4,
            NourishlySpace.s7,
          ),
          children: [
            Text('Profile', style: text.title),
            const NourishlySectionHeader(label: 'Targets'),
            NourishlyCard(
              padding: EdgeInsets.zero,
              child: _SettingsRow(
                label: 'Goals & targets',
                onTap: () => context.go('/profile/goals'),
              ),
            ),
            const NourishlySectionHeader(label: 'Preferences'),
            NourishlyCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _SettingsRow(label: 'Units', detail: 'Metric', comingSoon: true),
                  _Divider(color: colors.line),
                  _SettingsRow(
                    label: 'Week starts',
                    detail: 'Monday',
                    comingSoon: true,
                  ),
                  _Divider(color: colors.line),
                  _SettingsRow(
                    label: 'Day rolls over',
                    detail: '4:00 am',
                    comingSoon: true,
                  ),
                  _Divider(color: colors.line),
                  _SettingsRow(
                    label: 'Reminders',
                    detail: 'Off',
                    comingSoon: true,
                  ),
                ],
              ),
            ),
            const NourishlySectionHeader(label: 'Your data'),
            NourishlyCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _SettingsRow(
                    label: 'Export everything',
                    detail: 'JSON and CSV',
                    comingSoon: true,
                  ),
                  _Divider(color: colors.line),
                  _SettingsRow(
                    label: 'Backup',
                    detail: 'Handled by your phone',
                    comingSoon: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: NourishlySpace.s5),
            Text(
              'Nourishly v0.1 · all data stays on this phone',
              textAlign: TextAlign.center,
              style: text.caption.copyWith(color: colors.ink3),
            ),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, thickness: 1, color: color);
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.label,
    this.detail,
    this.onTap,
    this.comingSoon = false,
  });

  final String label;
  final String? detail;
  final VoidCallback? onTap;
  final bool comingSoon;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap:
            onTap ??
            (comingSoon
                ? () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$label arrives in a later phase.')),
                  )
                : null),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: NourishlySpace.s4,
            vertical: NourishlySpace.s4,
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  label,
                  style: text.body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (detail != null) ...[
                const SizedBox(width: NourishlySpace.s2),
                Flexible(
                  flex: 2,
                  child: Text(
                    detail!,
                    style: text.caption.copyWith(color: colors.ink3),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              const SizedBox(width: NourishlySpace.s2),
              Icon(Icons.chevron_right_rounded, color: colors.ink3, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
