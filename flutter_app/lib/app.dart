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

// ── Placeholder health screens ─────────────────────────────────────────────────
// Replace these with real implementations when ready.
class _PlaceholderScreen extends StatelessWidget {
  final String title;
  const _PlaceholderScreen(this.title);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
      );
}

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const _PlaceholderScreen('Onboarding');
}

class GrowthScreen extends StatelessWidget {
  final BabiesData? baby;
  const GrowthScreen({super.key, this.baby});

  @override
  Widget build(BuildContext context) => const _PlaceholderScreen('Growth Charts');
}

class VaccineScreen extends StatelessWidget {
  final BabiesData? baby;
  const VaccineScreen({super.key, this.baby});

  @override
  Widget build(BuildContext context) => const _PlaceholderScreen('Vaccines');
}

class MilestoneScreen extends StatelessWidget {
  final BabiesData? baby;
  const MilestoneScreen({super.key, this.baby});

  @override
  Widget build(BuildContext context) => const _PlaceholderScreen('Milestones');
}

class MedicationScreen extends StatelessWidget {
  final BabiesData? baby;
  const MedicationScreen({super.key, this.baby});

  @override
  Widget build(BuildContext context) => const _PlaceholderScreen('Medications');
}

class IllnessScreen extends StatelessWidget {
  final BabiesData? baby;
  const IllnessScreen({super.key, this.baby});

  @override
  Widget build(BuildContext context) => const _PlaceholderScreen('Illness Log');
}

class AppointmentScreen extends StatelessWidget {
  final BabiesData? baby;
  const AppointmentScreen({super.key, this.baby});

  @override
  Widget build(BuildContext context) => const _PlaceholderScreen('Appointments');
}

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
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HomeScreen(),
            ),
          ),
          GoRoute(
            path: '/history',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HistoryScreen(),
            ),
          ),
          GoRoute(
            path: '/insights',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: InsightsScreen(),
            ),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ProfileScreen(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/health/growth',
        builder: (context, state) {
          final baby = state.extra as BabiesData?;
          return GrowthScreen(baby: baby);
        },
      ),
      GoRoute(
        path: '/health/vaccines',
        builder: (context, state) {
          final baby = state.extra as BabiesData?;
          return VaccineScreen(baby: baby);
        },
      ),
      GoRoute(
        path: '/health/milestones',
        builder: (context, state) {
          final baby = state.extra as BabiesData?;
          return MilestoneScreen(baby: baby);
        },
      ),
      GoRoute(
        path: '/health/medications',
        builder: (context, state) {
          final baby = state.extra as BabiesData?;
          return MedicationScreen(baby: baby);
        },
      ),
      GoRoute(
        path: '/health/illness',
        builder: (context, state) {
          final baby = state.extra as BabiesData?;
          return IllnessScreen(baby: baby);
        },
      ),
      GoRoute(
        path: '/health/appointments',
        builder: (context, state) {
          final baby = state.extra as BabiesData?;
          return AppointmentScreen(baby: baby);
        },
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
