import 'package:flutter/material.dart';
import 'package:nourishly_ui/nourishly_ui.dart';

/// A scaffolded feature screen with nothing behind it yet.
///
/// Phase 1 wires the navigation shell and the module layout (§12.3,
/// §14.4); the screens themselves — search, logging, reports, scoring —
/// are Phase 2 onward. This widget is what every feature's placeholder
/// screen renders in the meantime, so the shell is fully navigable today.
class FeaturePlaceholder extends StatelessWidget {
  const FeaturePlaceholder({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(NourishlySpace.s6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.construction_rounded, color: colors.ink3, size: 32),
              const SizedBox(height: NourishlySpace.s4),
              Text(
                subtitle ?? 'Coming in a later phase.',
                textAlign: TextAlign.center,
                style: text.body.copyWith(color: colors.ink3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
