import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/nourishly_theme.dart';
import '../tokens.g.dart';

/// One dialog shape for the whole app.
///
/// Before this existed every screen assembled its own [AlertDialog]: some
/// with a title only, some with a title and a paragraph, actions in three
/// different orders, destructive actions styled in two different ways, and
/// content that clipped rather than scrolled at large text sizes. A dialog
/// is the most interruptive thing the app can do, so it is the last place
/// that should look improvised.
///
/// The shape, in order: an optional icon, a short question as the title,
/// one paragraph of supporting text saying what will happen, an optional
/// content slot, then the actions — cancel on the left, the thing the user
/// came to do on the right. Nothing else.
///
/// Every dialog in the app is built from [NourishlyDialog] or one of the
/// three helpers below, which cover what the app actually asks:
/// [showNourishlyConfirm] for a yes/no, [showNourishlyPrompt] for one
/// value, and [showNourishlyOptions] for one choice from a list.
class NourishlyDialog extends StatelessWidget {
  const NourishlyDialog({
    super.key,
    required this.title,
    this.message,
    this.icon,
    this.content,
    this.actions = const [],
    this.danger = false,
  });

  /// A short question or statement. Sentence case, not a heading.
  final String title;

  /// One paragraph saying what happens next. Optional, but a dialog that
  /// cannot explain itself in a sentence is usually a screen.
  final String? message;

  /// Reserved for the destructive and the genuinely informative. Most
  /// dialogs do not need one.
  final IconData? icon;

  /// Anything interactive — a field, a list, a slider.
  final Widget? content;

  /// Cancel first, confirm last. Built with [NourishlyDialogAction] so the
  /// emphasis is consistent across every dialog in the app.
  final List<Widget> actions;

  /// Tints the icon and marks this as the one kind of dialog the user must
  /// read. Red is reserved for destruction (§21.8).
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    final accent = danger ? colors.danger : colors.accent;

    return AlertDialog(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NourishlyRadius.xl),
        side: BorderSide(color: colors.line, width: NourishlyStroke.hairline),
      ),
      insetPadding: const EdgeInsets.symmetric(
        horizontal: NourishlySpace.s5,
        vertical: NourishlySpace.s6,
      ),
      titlePadding: const EdgeInsets.fromLTRB(
        NourishlySpace.s5,
        NourishlySpace.s5,
        NourishlySpace.s5,
        0,
      ),
      contentPadding: const EdgeInsets.fromLTRB(
        NourishlySpace.s5,
        NourishlySpace.s3,
        NourishlySpace.s5,
        NourishlySpace.s2,
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        NourishlySpace.s3,
        NourishlySpace.s2,
        NourishlySpace.s3,
        NourishlySpace.s3,
      ),
      // Wraps rather than clips once the labels stop fitting side by side,
      // which is what happens at 200% text (NFR-A-04).
      actionsOverflowDirection: VerticalDirection.down,
      actionsOverflowButtonSpacing: NourishlySpace.s1,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Container(
              width: NourishlySpace.s8,
              height: NourishlySpace.s8,
              decoration: BoxDecoration(
                color: danger ? colors.dangerSoft : colors.accentSoft,
                borderRadius: BorderRadius.circular(NourishlyRadius.md),
              ),
              child: Center(child: Icon(icon, size: 20, color: accent)),
            ),
            const SizedBox(height: NourishlySpace.s3),
          ],
          Text(title, style: text.heading),
        ],
      ),
      content: (message == null && content == null)
          ? null
          // Scrolls rather than overflows: a dialog at 200% text with a
          // paragraph and a field does not fit on a phone otherwise.
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message != null)
                    Text(
                      message!,
                      style: text.body.copyWith(
                        color: colors.ink2,
                        height: 1.55,
                      ),
                    ),
                  if (message != null && content != null)
                    const SizedBox(height: NourishlySpace.s4),
                  ?content,
                ],
              ),
            ),
      actions: actions.isEmpty ? null : actions,
    );
  }
}

/// A dialog action, so emphasis means the same thing everywhere: the
/// confirming action is filled, everything else is a text button, and a
/// destructive confirmation is filled in red rather than merely labelled
/// in it.
class NourishlyDialogAction extends StatelessWidget {
  const NourishlyDialogAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.isPrimary = false,
    this.danger = false,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final bool danger;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final callback = enabled ? onPressed : null;

    if (!isPrimary) {
      return TextButton(
        onPressed: callback,
        style: TextButton.styleFrom(
          foregroundColor: colors.ink2,
          minimumSize: const Size(
            NourishlyTarget.minTouch,
            NourishlyTarget.minTouch,
          ),
          padding: const EdgeInsets.symmetric(horizontal: NourishlySpace.s4),
        ),
        child: Text(label),
      );
    }

    return FilledButton(
      onPressed: callback,
      style: FilledButton.styleFrom(
        backgroundColor: danger ? colors.danger : colors.accent,
        // `accentInk` is the token for "ink on a filled surface": white in
        // the light theme, near-black in the dark one. Hard-coding white
        // would be invisible on the dark theme's danger colour, which is a
        // light pink rather than a dark red.
        foregroundColor: colors.accentInk,
        // Not the theme's full-width button: a dialog's actions sit in a
        // row, and a minimum height of 48 is the part that matters
        // (NFR-A-03).
        minimumSize: const Size(0, NourishlyTarget.minTouch),
        padding: const EdgeInsets.symmetric(horizontal: NourishlySpace.s5),
      ),
      child: Text(label),
    );
  }
}

/// The app's single `showDialog` call. Routes everything through one
/// barrier colour, one barrier label (so a screen reader announces the
/// dialog rather than "dismiss"), and one set of semantics.
Future<T?> showNourishlyDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    useSafeArea: true,
    barrierDismissible: barrierDismissible,
    barrierColor: context.nourishlyColors.scrim,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    builder: builder,
  );
}

/// A yes/no. Returns true only if the user chose the confirming action —
/// a dismissed dialog is a no, never a maybe.
Future<bool> showNourishlyConfirm({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  IconData? icon,
  bool danger = false,
}) async {
  final confirmed = await showNourishlyDialog<bool>(
    context: context,
    builder: (context) => NourishlyDialog(
      title: title,
      message: message,
      icon: icon,
      danger: danger,
      actions: [
        NourishlyDialogAction(
          label: cancelLabel,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        NourishlyDialogAction(
          label: confirmLabel,
          isPrimary: true,
          danger: danger,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// One value, typed. Returns null if the user cancelled, and never an
/// empty string — "saved nothing" is a cancel.
///
/// [validator] gates the confirming action live rather than rejecting the
/// value after the fact, which is the difference between a dialog that
/// helps and one that argues.
Future<String?> showNourishlyPrompt({
  required BuildContext context,
  required String title,
  String? message,
  String? initialValue,
  String? label,
  String? hint,
  String? suffix,
  String? helper,
  String confirmLabel = 'Save',
  String cancelLabel = 'Cancel',
  bool numeric = false,
  TextCapitalization textCapitalization = TextCapitalization.none,
  bool Function(String value)? validator,
  IconData? icon,
  bool danger = false,
}) {
  return showNourishlyDialog<String>(
    context: context,
    builder: (context) => _PromptDialog(
      title: title,
      message: message,
      icon: icon,
      danger: danger,
      initialValue: initialValue,
      label: label,
      hint: hint,
      suffix: suffix,
      helper: helper,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      numeric: numeric,
      textCapitalization: textCapitalization,
      validator: validator,
    ),
  );
}

class _PromptDialog extends StatefulWidget {
  const _PromptDialog({
    required this.title,
    required this.message,
    required this.icon,
    required this.danger,
    required this.initialValue,
    required this.label,
    required this.hint,
    required this.suffix,
    required this.helper,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.numeric,
    required this.textCapitalization,
    required this.validator,
  });

  final String title;
  final String? message;
  final IconData? icon;
  final bool danger;
  final String? initialValue;
  final String? label;
  final String? hint;
  final String? suffix;
  final String? helper;
  final String confirmLabel;
  final String cancelLabel;
  final bool numeric;
  final TextCapitalization textCapitalization;
  final bool Function(String value)? validator;

  @override
  State<_PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<_PromptDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue ?? '',
  );

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  bool get _isValid {
    final value = _controller.text.trim();
    if (value.isEmpty) return false;
    return widget.validator?.call(value) ?? true;
  }

  void _submit() {
    if (!_isValid) return;
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;

    return NourishlyDialog(
      title: widget.title,
      message: widget.message,
      icon: widget.icon,
      danger: widget.danger,
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: widget.textCapitalization,
        keyboardType: widget.numeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        inputFormatters: widget.numeric
            ? [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))]
            : null,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          suffixText: widget.suffix,
          helperText: widget.helper,
          helperMaxLines: 3,
          filled: true,
          fillColor: colors.surface2,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(NourishlyRadius.md),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      actions: [
        NourishlyDialogAction(
          label: widget.cancelLabel,
          onPressed: () => Navigator.of(context).pop(),
        ),
        NourishlyDialogAction(
          label: widget.confirmLabel,
          isPrimary: true,
          danger: widget.danger,
          enabled: _isValid,
          onPressed: _submit,
        ),
      ],
    );
  }
}

/// One option from a short list, as a bottom sheet rather than a dialog:
/// the choice is the whole interaction, the list can be long, and a sheet
/// puts it within thumb reach.
///
/// Selecting closes the sheet, so there is no group state to hold and no
/// Save button to press — which is why these are plain rows with a tick
/// rather than radios.
class NourishlyOption<T> {
  const NourishlyOption({
    required this.value,
    required this.label,
    this.subtitle,
  });

  final T value;
  final String label;
  final String? subtitle;
}

Future<T?> showNourishlyOptions<T>({
  required BuildContext context,
  required String title,
  required List<NourishlyOption<T>> options,
  String? message,
  T? selected,
}) {
  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    // Long option lists (the appearance list is short; a nutrient list is
    // not) scroll inside the sheet instead of forcing it past the screen.
    isScrollControlled: true,
    backgroundColor: context.nourishlyColors.surface,
    builder: (context) {
      final colors = context.nourishlyColors;
      final text = context.nourishlyText;
      return SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  NourishlySpace.s5,
                  0,
                  NourishlySpace.s5,
                  NourishlySpace.s2,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: text.heading),
                    if (message != null) ...[
                      const SizedBox(height: NourishlySpace.s1),
                      Text(
                        message,
                        style: text.caption.copyWith(
                          color: colors.ink3,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: NourishlySpace.s3),
                  children: [
                    for (final option in options)
                      _OptionRow<T>(
                        option: option,
                        isSelected: option.value == selected,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _OptionRow<T> extends StatelessWidget {
  const _OptionRow({required this.option, required this.isSelected});

  final NourishlyOption<T> option;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.nourishlyColors;
    final text = context.nourishlyText;
    return Semantics(
      selected: isSelected,
      button: true,
      child: InkWell(
        onTap: () => Navigator.of(context).pop(option.value),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: NourishlyTarget.minTouch,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: NourishlySpace.s5,
              vertical: NourishlySpace.s3,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        option.label,
                        style: text.body.copyWith(
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: isSelected ? colors.accent : colors.ink,
                        ),
                      ),
                      if (option.subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          option.subtitle!,
                          style: text.caption.copyWith(
                            color: colors.ink3,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isSelected)
                  Padding(
                    padding: const EdgeInsets.only(left: NourishlySpace.s3),
                    child: Icon(
                      Icons.check_rounded,
                      size: 20,
                      color: colors.accent,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
