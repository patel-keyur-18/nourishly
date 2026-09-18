import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../features/data_backup/presentation/screens/data_backup_screen.dart';
import '../features/food_logging/presentation/screens/custom_food_screen.dart';
import '../features/food_logging/presentation/screens/day_log_screen.dart';
import '../features/food_logging/presentation/screens/food_logging_screen.dart';
import '../features/food_logging/presentation/screens/food_portion_screen.dart';
import '../features/goals/presentation/screens/goals_screen.dart';
import '../features/meal_plan/presentation/screens/week_plan_screen.dart';
import '../features/meal_templates/presentation/screens/meal_templates_screen.dart';
import '../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../features/profile/presentation/screens/profile_screen.dart';
import '../features/profile/presentation/screens/profile_setup_screen.dart';
import '../features/reports/presentation/screens/daily_report_screen.dart';
import '../features/reports/presentation/screens/monthly_report_screen.dart';
import '../features/reminders/presentation/screens/reminders_screen.dart';
import '../features/reports/presentation/screens/reports_screen.dart';
import '../features/recipes/presentation/screens/recipe_builder_screen.dart';
import '../features/recipes/presentation/screens/recipes_screen.dart';
import '../features/reports/presentation/screens/weekly_nutrient_screen.dart';
import '../features/reports/presentation/screens/weekly_report_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';
import '../features/water/presentation/screens/water_screen.dart';
import 'shell/nourishly_shell.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

/// Declarative, typed routes (§28.5) so notification deep links resolve to
/// a tab plus a stack rather than a detached screen (§28.4) — even though
/// nothing sends a notification yet, the route shape is right from day one.
///
/// §27.1's one way in: the app always starts at `/today`, and
/// [NourishlyApp] sends a profile that has never seen the welcome to
/// `/onboarding` once, after preferences load. The flag is separate from
/// "has a profile" so that skipping setup does not mean seeing the welcome
/// again on every launch.
///
/// The rest of §28.5's route table (`/log/search`, `/today/nutrient/:id`,
/// …) arrives with the features that need it.
final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  // Without this, the Navigator go_router builds internally has no
  // restoration scope of its own, so no pushed screen (e.g.
  // FoodPortionScreen) ever receives a restoration bucket to register
  // against — RestorationMixin.bucket stays null and nothing survives a
  // backgrounding interruption, regardless of what the screen itself does.
  restorationScopeId: 'nourishly-router',
  initialLocation: '/today',
  routes: [
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    // `?meal=<slotId>` carries the slot the user came in through, so
    // "Add breakfast" on the dashboard lands on a screen that already
    // knows it is breakfast rather than asking again at the end.
    GoRoute(
      path: '/log',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) => MaterialPage(
        fullscreenDialog: true,
        child: FoodLoggingScreen(
          mealSlotId: state.uri.queryParameters['meal'],
          planDate: state.uri.queryParameters['plan'],
        ),
      ),
      routes: [
        // `?entryId=<id>` reuses this same screen to edit an
        // already-logged entry (FR-M-05) rather than log a new one —
        // reached from the day log's "Edit portion" action.
        // `?plan=YYYY-MM-DD` sends the same flow to the week plan
        // instead of to today: the entry is written against that date and
        // marked planned. One search screen, two destinations.
        GoRoute(
          path: 'food/:foodId',
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => FoodPortionScreen(
            foodId: state.pathParameters['foodId']!,
            initialMealSlotId: state.uri.queryParameters['meal'],
            entryId: state.uri.queryParameters['entryId'],
            planDate: DateTime.tryParse(
              state.uri.queryParameters['plan'] ?? '',
            ),
          ),
        ),
        GoRoute(
          path: 'new',
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) =>
              CustomFoodScreen(initialName: state.uri.queryParameters['name']),
        ),
      ],
    ),
    // Over the shell, like the other detail screens: building a recipe is
    // a job you finish and come back from, not a tab.
    GoRoute(
      path: '/recipes',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const RecipesScreen(),
      routes: [
        GoRoute(
          path: 'new',
          parentNavigatorKey: rootNavigatorKey,
          // `?from=<foodId>` starts the form from an existing recipe's
          // ingredients instead of empty — "make this our version". It
          // stays a *new* recipe: the catalog row it came from is never
          // touched.
          builder: (context, state) => RecipeBuilderScreen(
            forkFromId: state.uri.queryParameters['from'],
          ),
        ),
        GoRoute(
          path: ':foodId',
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) =>
              RecipeBuilderScreen(foodId: state.pathParameters['foodId']!),
        ),
      ],
    ),
    // Over the shell, like `/recipes` and `/templates`, and for the same
    // reason: planning a week is a job you finish and come back from.
    //
    // Not a fifth tab. `NourishlyBottomNav` asserts exactly four
    // destinations around the centre action, which is prototype screen
    // 3's approved shape — adding one is a redesign, not a side effect.
    GoRoute(
      path: '/plan',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const WeekPlanScreen(),
    ),
    // Over the shell, like `/recipes` — reached from the add-food flow.
    GoRoute(
      path: '/templates',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const MealTemplatesScreen(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          NourishlyShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/today',
              builder: (context, state) => const DashboardScreen(),
              routes: [
                // On the root navigator, so it covers the shell: the
                // prototype draws the report as a pushed screen with a
                // back arrow and no bottom nav, and a tab bar under a
                // detail screen invites tapping away mid-read.
                GoRoute(
                  path: 'report',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (context, state) => const DailyReportScreen(),
                ),
                // Design option C (chosen 2026-09-17): the day's entries in
                // the order they were logged, with edit and delete. Pushed
                // over the shell like `report`, for the same reason — a
                // tab bar under a screen you're editing invites tapping
                // away mid-edit.
                GoRoute(
                  path: 'log',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (context, state) => const DayLogScreen(),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/insights',
              builder: (context, state) => const ReportsScreen(),
              routes: [
                // Inside the branch, not over the shell: the prototype
                // keeps the bottom nav on 10A and 11A and only the daily
                // report (9C) covers it.
                GoRoute(
                  path: 'week',
                  builder: (context, state) => const WeeklyReportScreen(),
                  routes: [
                    GoRoute(
                      path: 'nutrient/:nutrientId',
                      builder: (context, state) => WeeklyNutrientScreen(
                        nutrientId: state.pathParameters['nutrientId']!,
                      ),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'month',
                  builder: (context, state) => const MonthlyReportScreen(),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/water',
              builder: (context, state) => const WaterScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const SettingsScreen(),
              routes: [
                // Both pushed over the shell, as above.
                GoRoute(
                  path: 'goals',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (context, state) => const GoalsScreen(),
                ),
                // Item 5 of the 2026-09-12 UX revision: the profile is
                // its own screen, reached from Settings. Settings keeps
                // what is genuinely a setting; who you are, what your body
                // is doing, how you eat and what you are aiming at belong
                // together on one screen of their own.
                GoRoute(
                  path: 'me',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (context, state) => const ProfileScreen(),
                ),
                // First-run setup only. Every later change to one of these
                // fields is edited in place on `/profile/me`, so nobody is
                // walked through six steps to correct their weight.
                GoRoute(
                  path: 'setup',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (context, state) => ProfileSetupScreen(
                    // `?from=welcome` means first run: finishing goes to the
                    // dashboard rather than back to whatever the welcome
                    // happened to replace.
                    fromWelcome: state.uri.queryParameters['from'] == 'welcome',
                  ),
                ),
                // §28.5's route table, completed by Phase 5. Both are
                // jobs you finish and come back from, so both cover the
                // shell like the other detail screens.
                GoRoute(
                  path: 'reminders',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (context, state) => const RemindersScreen(),
                ),
                GoRoute(
                  path: 'data',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (context, state) => const DataBackupScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);
