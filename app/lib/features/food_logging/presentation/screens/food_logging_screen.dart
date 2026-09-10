import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The logging flow, opened modally from the bottom nav's centre action
/// (§27.3, §28.4) and dismissed back to wherever the user was. Search,
/// recents, templates, and portion selection are Phase 2 — this Phase 1
/// placeholder exists so the modal route and its dismiss behaviour are
/// already correct before any of that is built.
class FoodLoggingScreen extends StatelessWidget {
  const FoodLoggingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log food or water'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: const Center(
        child: Text('Search, recents, and templates land here in Phase 2.'),
      ),
    );
  }
}
