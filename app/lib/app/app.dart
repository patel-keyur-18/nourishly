import 'package:flutter/material.dart';
import 'package:nourishly_ui/nourishly_ui.dart';

import 'router.dart';

/// The Nourishly application shell: theme + routing, nothing else. Actual
/// screens live in `features/` (§14.1).
class NourishlyApp extends StatelessWidget {
  const NourishlyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Nourishly',
      debugShowCheckedModeBanner: false,
      theme: NourishlyTheme.light(),
      darkTheme: NourishlyTheme.dark(),
      // Dark mode is first-class, not an afterthought (§27.14) — follow
      // the system setting rather than defaulting to light.
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
    );
  }
}
