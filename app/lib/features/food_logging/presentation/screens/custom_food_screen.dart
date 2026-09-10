import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nourishly_ui/nourishly_ui.dart';

import '../../../../app/providers.dart';

/// Create a food the catalog doesn't have (UX-6, FR-C-01) — the escape
/// hatch that makes a failed search a starting point rather than a dead
/// end. Reached from the search screen with the query prefilled.
///
/// Only the name and a serving weight are required. Nutrients are
/// optional and each one left blank stays *unknown*, not zero (AP-4) —
/// so a food logged for its portion alone is still honest data.
class CustomFoodScreen extends ConsumerStatefulWidget {
  const CustomFoodScreen({super.key, this.initialName});

  final String? initialName;

  @override
  ConsumerState<CustomFoodScreen> createState() => _CustomFoodScreenState();
}

class _CustomFoodScreenState extends ConsumerState<CustomFoodScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initialName ?? '');
  final _servingLabel = TextEditingController(text: '1 serving');
  final _grams = TextEditingController();
  final _energy = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();
  final _fibre = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [
      _name,
      _servingLabel,
      _grams,
      _energy,
      _protein,
      _carbs,
      _fat,
      _fibre,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Blank stays blank: an empty field means "not known", so it is left
  /// out of the map entirely rather than sent as 0.
  double? _value(TextEditingController c) {
    final raw = c.text.trim();
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false) || _saving) return;
    setState(() => _saving = true);

    final messenger = ScaffoldMessenger.of(context);
    try {
      final ownerId = await ref.read(defaultOwnerProvider.future);
      final foodId = await ref
          .read(customFoodDaoProvider)
          .createCustomFood(
            ownerId: ownerId,
            name: _name.text.trim(),
            servingLabel: _servingLabel.text.trim().isEmpty
                ? '1 serving'
                : _servingLabel.text.trim(),
            servingGrams: _value(_grams)!,
            nutrientsPerServing: {
              for (final (id, controller) in [
                ('energy', _energy),
                ('protein', _protein),
                ('carbs', _carbs),
                ('fat', _fat),
                ('fibre', _fibre),
              ])
                id: ?_value(controller),
            },
          );

      if (!mounted) return;
      // Straight on to the portion screen — creating a food is only ever
      // a step on the way to logging it.
      context.pushReplacement('/log/food/$foodId');
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Could not save that food: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;

    return Scaffold(
      appBar: AppBar(title: const Text('New food')),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  NourishlySpace.s4,
                  NourishlySpace.s4,
                  NourishlySpace.s4,
                  NourishlySpace.s6,
                ),
                children: [
                  _Field(
                    controller: _name,
                    label: 'Name',
                    hint: 'Mummy\'s dal',
                    textCapitalization: TextCapitalization.sentences,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Give it a name you will recognise later.'
                        : null,
                  ),
                  const NourishlySectionHeader(label: 'One serving'),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: _Field(
                          controller: _servingLabel,
                          label: 'Called',
                          hint: '1 katori',
                        ),
                      ),
                      const SizedBox(width: NourishlySpace.s3),
                      Expanded(
                        flex: 2,
                        child: _Field(
                          controller: _grams,
                          label: 'Weighs (g)',
                          hint: '150',
                          numeric: true,
                          validator: (v) {
                            final grams = double.tryParse(v?.trim() ?? '');
                            if (grams == null || grams <= 0) {
                              return 'Required';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const NourishlySectionHeader(label: 'Per serving'),
                  Text(
                    'All optional. Anything you leave blank stays unknown — '
                    'it will never be counted as zero.',
                    style: text.caption.copyWith(color: colors.ink3),
                  ),
                  const SizedBox(height: NourishlySpace.s3),
                  _Field(
                    controller: _energy,
                    label: 'Energy (kcal)',
                    numeric: true,
                  ),
                  const SizedBox(height: NourishlySpace.s3),
                  Row(
                    children: [
                      Expanded(
                        child: _Field(
                          controller: _protein,
                          label: 'Protein (g)',
                          numeric: true,
                        ),
                      ),
                      const SizedBox(width: NourishlySpace.s3),
                      Expanded(
                        child: _Field(
                          controller: _carbs,
                          label: 'Carbs (g)',
                          numeric: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: NourishlySpace.s3),
                  Row(
                    children: [
                      Expanded(
                        child: _Field(
                          controller: _fat,
                          label: 'Fat (g)',
                          numeric: true,
                        ),
                      ),
                      const SizedBox(width: NourishlySpace.s3),
                      Expanded(
                        child: _Field(
                          controller: _fibre,
                          label: 'Fibre (g)',
                          numeric: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(
                  top: BorderSide(
                    color: colors.line,
                    width: NourishlyStroke.hairline,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(NourishlySpace.s4),
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'Saving…' : 'Save and log it'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.numeric = false,
    this.validator,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool numeric;
  final String? Function(String?)? validator;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    return TextFormField(
      controller: controller,
      validator: validator,
      textCapitalization: textCapitalization,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      inputFormatters: numeric
          ? [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))]
          : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: colors.surface2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NourishlyRadius.md),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
