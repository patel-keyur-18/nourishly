import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../features/food_logging/presentation/screens/custom_food_screen.dart';
import '../features/food_logging/presentation/screens/food_logging_screen.dart';
import '../features/food_logging/presentation/screens/food_portion_screen.dart';
import '../features/goals/presentation/screens/goals_screen.dart';
import '../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../features/profile/presentation/screens/profile_setup_screen.dart';
import '../features/reports/presentation/screens/daily_report_screen.dart';
import '../features/reports/presentation/screens/monthly_report_screen.dart';
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
  initialLocation: '/today',
  routes: [
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/log',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) => const MaterialPage(
        fullscreenDialog: true,
        child: FoodLoggingScreen(),
      ),
      routes: [
        GoRoute(
          path: 'food/:foodId',
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) =>
              FoodPortionScreen(foodId: state.pathParameters['foodId']!),
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
          builder: (context, state) => const RecipeBuilderScreen(),
        ),
        GoRoute(
          path: ':foodId',
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) =>
              RecipeBuilderScreen(foodId: state.pathParameters['foodId']!),
        ),
      ],
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
                GoRoute(
                  path: 'setup',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (context, state) => const ProfileSetupScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);
