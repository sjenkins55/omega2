import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme.dart';
import 'providers/providers.dart';
import 'views/shell/app_shell.dart';
import 'views/home/home_screen.dart';
import 'views/history/history_screen.dart';
import 'views/insights/insights_screen.dart';
import 'views/profile/profile_screen.dart';
import 'views/onboarding/onboarding_screen.dart';
import 'views/health/growth_screen.dart';
import 'views/health/vaccine_screen.dart';
import 'views/health/milestone_screen.dart';
import 'views/health/medication_screen.dart';
import 'views/health/illness_screen.dart';
import 'views/health/appointment_screen.dart';
import 'database/app_database.dart';

// ── Router ────────────────────────────────────────────────────────────────────

final _routerProvider = Provider<GoRouter>((ref) {
  final hasOnboarded = ref.watch(hasCompletedOnboardingProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      if (!hasOnboarded && state.matchedLocation != '/onboarding') {
        return '/onboarding';
      }
      if (hasOnboarded && state.matchedLocation == '/onboarding') {
        return '/';
      }
      return null;
    },
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: HomeScreen()),
          ),
          GoRoute(
            path: '/history',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: HistoryScreen()),
          ),
          GoRoute(
            path: '/insights',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: InsightsScreen()),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ProfileScreen()),
          ),
        ],
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/health/growth',
        builder: (context, state) =>
            GrowthScreen(baby: state.extra as BabiesData?),
      ),
      GoRoute(
        path: '/health/vaccines',
        builder: (context, state) =>
            VaccineScreen(baby: state.extra as BabiesData?),
      ),
      GoRoute(
        path: '/health/milestones',
        builder: (context, state) =>
            MilestoneScreen(baby: state.extra as BabiesData?),
      ),
      GoRoute(
        path: '/health/medications',
        builder: (context, state) =>
            MedicationScreen(baby: state.extra as BabiesData?),
      ),
      GoRoute(
        path: '/health/illness',
        builder: (context, state) =>
            IllnessScreen(baby: state.extra as BabiesData?),
      ),
      GoRoute(
        path: '/health/appointments',
        builder: (context, state) =>
            AppointmentScreen(baby: state.extra as BabiesData?),
      ),
    ],
  );
});

// ── App root ──────────────────────────────────────────────────────────────────

class BabyTrackerApp extends ConsumerWidget {
  const BabyTrackerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(_routerProvider);

    return MaterialApp.router(
      title: 'Baby Tracker',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
