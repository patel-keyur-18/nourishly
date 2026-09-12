import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/nourishly_colors.dart';
import '../theme/nourishly_theme.dart';
import '../theme/nourishly_typography.dart';
import '../tokens.g.dart';

/// How long a message stays up. Long enough to read a sentence and reach
/// an Undo; short enough that it is gone before it is in the way.
const Duration nourishlySnackDuration = Duration(seconds: 5);

/// Counts the messages shown, so the watchdog below can tell "mine is
/// still up" from "someone else's replaced it".
int _shown = 0;

/// The watchdog for the message currently up, cancelled when another
/// replaces it so at most one is ever outstanding.
Timer? _watchdog;

/// The app's only way to show a transient message.
///
/// Three things were wrong with calling `showSnackBar` directly, and all
/// three were visible to the user:
///
/// - **Nothing set a duration.** The default is four seconds, but Flutter
///   suppresses its own dismiss timer in two cases — while the messenger's
///   route is not the current one, and, for a message carrying an action,
///   while accessible navigation is on. Either one leaves the message up
///   until something else replaces it, which is exactly what "Removed
///   200 ml" did.
/// - **Nothing cleared the previous message**, so quick taps queued five
///   deep and each one waited its turn.
/// - **Nothing could be dismissed by hand**, so a message that did get
///   stuck had no way out.
///
/// So: an explicit duration, one message at a time, a close button, swipe
/// to dismiss, and a watchdog that removes the message at the deadline
/// even when Flutter's own timer never started. Five seconds means five
/// seconds.
///
/// Note for widget tests: the watchdog is a real timer, so a test that
/// triggers a message must pump past it —
/// `await tester.pump(nourishlySnackDuration + someSlack)` — or the test
/// ends with a pending timer.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showNourishlySnack(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
  bool isError = false,
  Duration duration = nourishlySnackDuration,
}) {
  return showNourishlySnackOn(
    ScaffoldMessenger.of(context),
    message,
    actionLabel: actionLabel,
    onAction: onAction,
    isError: isError,
    duration: duration,
    colors: context.nourishlyColors,
    typography: context.nourishlyText,
  );
}

/// The same, for the common case of a write that awaits: capture the
/// messenger before the `await`, show the message after it, and never
/// touch a [BuildContext] across an async gap.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showNourishlySnackOn(
  ScaffoldMessengerState messenger,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
  bool isError = false,
  Duration duration = nourishlySnackDuration,
  NourishlyColors? colors,
  NourishlyTypography? typography,
}) {
  // One at a time. A queue of five messages about the same tap is noise,
  // and the last one of them would appear twenty seconds late.
  messenger.clearSnackBars();

  _watchdog?.cancel();
  final mine = ++_shown;
  final controller = messenger.showSnackBar(
    SnackBar(
      duration: duration,
      behavior: SnackBarBehavior.floating,
      dismissDirection: DismissDirection.horizontal,
      showCloseIcon: true,
      margin: const EdgeInsets.all(NourishlySpace.s4),
      padding: const EdgeInsets.fromLTRB(
        NourishlySpace.s4,
        NourishlySpace.s3,
        NourishlySpace.s2,
        NourishlySpace.s3,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NourishlyRadius.md),
      ),
      backgroundColor: isError ? colors?.danger : colors?.ink,
      // `surface` is the contrasting ink for both backgrounds in both
      // themes — the dark theme's `ink` and `danger` are both light
      // colours, so white text on either would be unreadable. Everything
      // else comes from `snackBarTheme`.
      content: Text(
        message,
        style: typography?.body.copyWith(color: colors?.surface, height: 1.4),
      ),
      action: (actionLabel == null || onAction == null)
          ? null
          : SnackBarAction(label: actionLabel, onPressed: onAction),
    ),
  );

  var closed = false;
  controller.closed.then((_) => closed = true);
  // The watchdog. `removeCurrentSnackBar` is a no-op when there is nothing
  // up, and the counter makes sure this only ever removes *this* message —
  // never a newer one that replaced it.
  _watchdog = Timer(duration + const Duration(milliseconds: 250), () {
    _watchdog = null;
    if (closed || _shown != mine) return;
    messenger.removeCurrentSnackBar();
  });

  return controller;
}
