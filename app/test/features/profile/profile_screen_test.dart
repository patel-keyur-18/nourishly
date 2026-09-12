import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly/app/app.dart';
import 'package:nourishly/app/providers.dart';
import 'package:nourishly/app/router.dart';
import 'package:nourishly/features/food_catalog/data/food_catalog_providers.dart';
import 'package:nourishly/features/profile/presentation/screens/profile_screen.dart';
import 'package:nourishly/features/profile/presentation/screens/profile_setup_screen.dart';
import 'package:nourishly/features/reminders/data/local_notification_scheduler.dart';
import 'package:nourishly/features/reminders/data/reminder_providers.dart';
import 'package:nourishly/features/settings/presentation/screens/settings_screen.dart';
import 'package:nourishly_data/nourishly_data.dart' hide NutrientTarget;
import 'package:nourishly_domain/nourishly_domain.dart';
import 'package:nourishly_ui/nourishly_ui.dart';
import 'package:nutrition_core/nutrition_core.dart';

/// Item 6 of the 2026-09-12 UX revision: **editing one field edits one
/// field.** Every row on the profile screen used to lead to `/profile/setup`
/// — the six-step wizard — which asked five more questions, finished on the
/// dashboard, and (because it started from its own hardcoded defaults
/// rather than from the saved profile) could replace values the user had
/// never touched.
void main() {
  late NourishlyDatabase db;
  late String ownerId;
  final now = DateTime(2026, 9, 12, 10, 0);

  setUp(() async {
    db = NourishlyDatabase.forTesting();
    ownerId = await ensureDefaultOwner(db);
    await PreferencesDao(db).update(ownerId, onboardingSeen: true);
    await ProfileDao(db).saveProfileAndDeriveTargets(
      ownerId: ownerId,
      inputs: const ProfileInputs(
        ageYears: 34,
        heightCm: 181,
        weightKg: 78,
        activityLevel: ActivityLevel.moderate,
        biologicalSex: BiologicalSex.male,
      ),
      dateOfBirth: DateTime(1992, 3, 14),
      goal: GoalType.gainMuscle,
    );
  });

  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, String location) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nourishlyDatabaseProvider.overrideWithValue(db),
          catalogReadyProvider.overrideWith((ref) async {}),
          clockProvider.overrideWithValue(FakeClock(now)),
          reminderSchedulerProvider.overrideWithValue(NoopReminderScheduler()),
        ],
        child: const NourishlyApp(),
      ),
    );
    await tester.pump();
    appRouter.go(location);
    await tester.pumpAndSettle();
  }

  /// Messages are transient but real: the watchdog in `showNourishlySnack`
  /// is a timer, so a test that triggers one pumps past it.
  Future<void> settleMessage(WidgetTester tester) async {
    await tester.pump(nourishlySnackDuration + const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  testWidgets('the profile screen shows what is actually saved', (
    tester,
  ) async {
    await pump(tester, '/profile/me');

    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('181 cm'), findsOneWidget);
    expect(find.text('78.0 kg'), findsOneWidget);
    expect(find.text('Moderately active'), findsOneWidget);
    expect(find.text('Build muscle'), findsOneWidget);
    expect(find.text('14 March 1992'), findsOneWidget);
  });

  testWidgets('Settings opens the profile, and Recipes stays in Settings', (
    tester,
  ) async {
    await pump(tester, '/profile');

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('Your recipes'), findsOneWidget);
    // The profile row, by what it says about the profile.
    expect(find.textContaining('Build muscle'), findsOneWidget);
  });

  testWidgets('editing the height changes the height and nothing else', (
    tester,
  ) async {
    await pump(tester, '/profile/me');

    await tester.tap(find.text('Height'));
    await tester.pumpAndSettle();

    // A dialog, not the wizard.
    expect(find.byType(ProfileSetupScreen), findsNothing);
    expect(find.text('Your height'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '176');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    // Still on the profile screen — not sent back to the dashboard.
    expect(find.byType(ProfileScreen), findsOneWidget);

    final profile = await ProfileDao(db).currentProfile(ownerId);
    expect(profile!.heightCm, 176);
    // Everything else is carried over rather than reset to a default.
    expect(profile.weightKg, 78);
    expect(profile.activityLevel, ActivityLevel.moderate.id);
    expect(profile.dateOfBirth, DateTime(1992, 3, 14));
    final goal = await ProfileDao(db).currentGoal(ownerId);
    expect(goal!.goalType, GoalType.gainMuscle.id);

    await settleMessage(tester);
  });

  testWidgets('changing the goal writes a new effective-dated goal', (
    tester,
  ) async {
    await pump(tester, '/profile/me');

    await tester.tap(find.text('Goal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lose weight'));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileScreen), findsOneWidget);
    final goal = await ProfileDao(db).currentGoal(ownerId);
    expect(goal!.goalType, GoalType.loseWeight.id);
    // §27.12's sentence, which is what makes the history trustworthy.
    expect(find.textContaining('applies from today'), findsOneWidget);

    await settleMessage(tester);
  });

  testWidgets('recording a weight keeps the series and stays put', (
    tester,
  ) async {
    await pump(tester, '/profile/me');

    await tester.tap(find.text('Weight'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '76.5');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileScreen), findsOneWidget);
    final weights = await BodyWeightDao(db).history(ownerId);
    expect(weights.single.weightKg, 76.5);

    await settleMessage(tester);
  });

  testWidgets('the wizard prefills from the saved profile', (tester) async {
    // Re-running setup deliberately is allowed; silently replacing a saved
    // height with the wizard's own default of 174 cm is not.
    await pump(tester, '/profile/setup');

    expect(find.byType(ProfileSetupScreen), findsOneWidget);
    expect(find.text('14 March 1992'), findsOneWidget);
    expect(find.text('34 years old'), findsOneWidget);
  });
}
