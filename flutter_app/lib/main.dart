import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz;

import 'app.dart';
import 'core/constants.dart';
import 'providers/providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Timezone data for local notifications ──────────────────────────────
  tz.initializeTimeZones();

  // ── Shared preferences ─────────────────────────────────────────────────
  final prefs = await SharedPreferences.getInstance();
  final hasCompletedOnboarding = prefs.getBool('has_completed_onboarding') ?? false;

  // ── Supabase initialisation (non-fatal) ────────────────────────────────
  try {
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      anonKey: AppConstants.supabaseAnonKey,
    );
  } catch (e) {
    // App works fully offline; Supabase is optional at startup.
    debugPrint('Supabase init skipped: $e');
  }

  runApp(
    ProviderScope(
      overrides: [
        hasCompletedOnboardingProvider.overrideWith(
          (ref) => hasCompletedOnboarding,
        ),
      ],
      child: const BabyTrackerApp(),
    ),
  );
}
