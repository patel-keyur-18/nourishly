import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nourishly_ui/nourishly_ui.dart';

import '../features/food_catalog/data/food_catalog_providers.dart';
import '../features/profile/data/profile_providers.dart';
import '../features/reminders/data/local_notification_scheduler.dart';
import '../features/reminders/data/reminder_providers.dart';
import '../features/settings/presentation/appearance.dart';
import 'router.dart';

/// The Nourishly application shell: theme + routing, nothing else. Actual
/// screens live in `features/` (§14.1).
///
/// Waits on [catalogReadyProvider] (the first-run catalog import, §16.4)
/// before showing routed content — the import is a few hundred rows and
/// finishes well under a second, so a brief plain loading screen is
/// simpler and more honest than threading a "catalog not ready yet" state
/// through every screen that might search.
class NourishlyApp extends ConsumerStatefulWidget {
  const NourishlyApp({super.key});

  @override
  ConsumerState<NourishlyApp> createState() => _NourishlyAppState();
}

class _NourishlyAppState extends ConsumerState<NourishlyApp>
    with WidgetsBindingObserver {
  /// Guards against sending the user to the welcome twice in one run —
  /// preferences can rebuild for reasons that have nothing to do with
  /// onboarding.
  bool _checkedOnboarding = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startReminders());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// §29.4: "rescheduling happens on app resume, on rule change, and after
  /// device reboot."
  ///
  /// Resume is this. Rule changes are handled where the rule changes, and
  /// reboot by the manifest's boot receiver. Resume matters most of the
  /// three, because it is the one that re-evaluates *conditions*: a water
  /// reminder scheduled this morning should stand down once the goal is
  /// met this afternoon, and nothing else would notice.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_resyncReminders());
    }
  }

  Future<void> _startReminders() async {
    final scheduler = ref.read(reminderSchedulerProvider);
    if (scheduler is LocalNotificationScheduler) {
      // Registers the channel and picks up a notification tap that
      // launched the app. Explicitly *not* a permission prompt — §29.1
      // puts that at the moment the first reminder is turned on.
      await scheduler.initialise(onTap: appRouter.go);
    }
    final launchRoute = await scheduler.takeLaunchRoute();
    // §28.5: a tap lands on the right screen, not on whatever the app
    // happened to be showing last.
    if (launchRoute != null) appRouter.go(launchRoute);
    await _resyncReminders();
  }

  Future<void> _resyncReminders() async {
    try {
      await ref.read(reminderSyncProvider).resync();
    } on Object catch (error) {
      // A scheduler that cannot reach the platform must not stop the app
      // from starting. Reminders are an addition to Nourishly, never a
      // precondition for using it (§29.4's "the app remains fully
      // functional").
      debugPrint('Nourishly: could not reschedule reminders ($error).');
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalogReady = ref.watch(catalogReadyProvider);

    // §27.1's one way in.
    //
    // Watched rather than listened to: `ref.listen` only fires on a
    // *change*, and preferences can already be resolved by the time this
    // first builds — which is exactly the first run this needs to catch.
    // Navigation is deferred to after the frame because this runs during
    // build, and happens once: a profile that skipped setup has still
    // *seen* the welcome and should not meet it again.
    final preferences = ref.watch(preferencesProvider).value;
    if (preferences != null && !_checkedOnboarding) {
      _checkedOnboarding = true;
      if (!preferences.onboardingSeen) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          appRouter.go('/onboarding');
        });
      }
    }

    return MaterialApp.router(
      title: 'Nourishly',
      debugShowCheckedModeBanner: false,
      theme: NourishlyTheme.light(),
      darkTheme: NourishlyTheme.dark(),
      // Light by default (the palette was drawn light-first and the
      // prototype was approved in it), but dark stays first-class
      // (§27.14): `UserPreferences.theme` decides, and `system` is
      // honoured in full for anyone who asks for it — which, since
      // Settings grew an Appearance row, someone finally can.
      themeMode: Appearance.fromId(preferences?.theme).themeMode,
      routerConfig: appRouter,
      builder: (context, child) {
        return catalogReady.when(
          data: (_) => child!,
          loading: () => const _LoadingScreen(),
          error: (error, stackTrace) => _LoadingScreen(error: error),
        );
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen({this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: error == null
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(NourishlySpace.s6),
                child: Text(
                  'Could not load the food catalog: $error',
                  textAlign: TextAlign.center,
                ),
              ),
      ),
    );
  }
}
