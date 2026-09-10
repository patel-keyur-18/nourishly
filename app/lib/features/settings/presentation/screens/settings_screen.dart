import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Profile, goals & targets, preferences, reminders, and export/data
/// (§27.12-27.13) — the "Profile" tab. `goals`'s `GoalsScreen` nests
/// underneath it at `/profile/goals` (§28.5). Lands in Phase 3/5.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Center(
        child: FilledButton(
          onPressed: () => context.go('/profile/goals'),
          child: const Text('Goals & targets'),
        ),
      ),
    );
  }
}
