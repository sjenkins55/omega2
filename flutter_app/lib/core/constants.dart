class AppConstants {
  // Replace with your actual Supabase project values
  static const supabaseUrl = 'https://YOUR_PROJECT.supabase.co';
  static const supabaseAnonKey = 'YOUR_ANON_KEY';

  // App Group (Android: shared SharedPreferences key prefix)
  static const appGroupId = 'group.com.babytracker';
  static const widgetPrefsKey = 'baby_tracker_widget';

  // Subscription
  static const revenueCatApiKey = 'YOUR_REVENUECAT_KEY';
  static const premiumEntitlement = 'premium';

  // Limits (free tier)
  static const freeBabyLimit = 1;
  static const freeCaregiverLimit = 0;

  // Sync
  static const maxSyncRetries = 5;
  static const syncBackoffCapSeconds = 30;

  // Invite
  static const inviteCodeLength = 8;
  static const inviteExpiryDays = 7;
}
