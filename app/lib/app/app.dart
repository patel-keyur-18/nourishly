import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nourishly_ui/nourishly_ui.dart';

import '../features/food_catalog/data/food_catalog_providers.dart';
import 'router.dart';

/// The Nourishly application shell: theme + routing, nothing else. Actual
/// screens live in `features/` (§14.1).
///
/// Waits on [catalogReadyProvider] (the first-run catalog import, §16.4)
/// before showing routed content — the import is a few hundred rows and
/// finishes well under a second, so a brief plain loading screen is
/// simpler and more honest than threading a "catalog not ready yet" state
/// through every screen that might search.
class NourishlyApp extends ConsumerWidget {
  const NourishlyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogReady = ref.watch(catalogReadyProvider);

    return MaterialApp.router(
      title: 'Nourishly',
      debugShowCheckedModeBanner: false,
      theme: NourishlyTheme.light(),
      darkTheme: NourishlyTheme.dark(),
      // Dark mode is first-class, not an afterthought (§27.14) — follow
      // the system setting rather than defaulting to light.
      themeMode: ThemeMode.system,
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
