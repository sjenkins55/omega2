# Xcode Project Setup Guide

## 1. Create the Xcode Project

1. Open Xcode → **File → New → Project**
2. Choose **iOS → App**
3. Settings:
   - Product Name: `BabyTracker`
   - Bundle ID: `com.yourcompany.babytracker`
   - Interface: SwiftUI
   - Language: Swift
   - Storage: None (we use SwiftData manually)
4. Save to this repo root (alongside the `BabyTracker/` folder)

---

## 2. Add Source Files

Drag the entire `BabyTracker/` folder into the Xcode project navigator.
Make sure **"Copy items if needed"** is **unchecked** (files already exist).

---

## 3. Add Widget Extension Target

1. **File → New → Target → Widget Extension**
2. Name: `BabyTrackerWidget`
3. Uncheck "Include Configuration Intent"
4. Drag `BabyTrackerWidget/` files into the new target

---

## 4. Configure App Groups (Widget + Live Activity data sharing)

For **both** the `BabyTracker` and `BabyTrackerWidget` targets:
1. Select target → **Signing & Capabilities → + Capability → App Groups**
2. Add group: `group.com.yourcompany.babytracker`
3. Update `AppGroupStore.groupID` in `AppGroupStore.swift` to match

---

## 5. Enable Live Activities

In `BabyTracker/Info.plist`, add:
```xml
<key>NSSupportsLiveActivities</key>
<true/>
```

Add `NursingTimerLiveActivity` to `BabyTrackerWidgetBundle` in `BabyTrackerWidget.swift`.

---

## 6. Add Swift Package Dependencies

**File → Add Package Dependencies…**

| Package | URL | Used for |
|---|---|---|
| Supabase Swift | `https://github.com/supabase/supabase-swift` | Backend sync + auth |
| RevenueCat | `https://github.com/RevenueCat/purchases-ios` | Subscriptions |
| Sentry | `https://github.com/getsentry/sentry-cocoa` | Crash reporting |

After adding Supabase, uncomment the import and SDK calls in `SupabaseService.swift`.
After adding RevenueCat, uncomment the import and SDK calls in `SubscriptionService.swift`.

---

## 7. Configure Build Settings

1. Duplicate `Config.xcconfig` → `Config.local.xcconfig`
2. Fill in your real values:
```
SUPABASE_URL = https://your-project.supabase.co
SUPABASE_ANON_KEY = eyJ...
REVENUECAT_API_KEY = appl_...
SENTRY_DSN = https://...@sentry.io/...
```
3. In **Project → Info → Configurations**, set `Config.local.xcconfig` for Debug and Release
4. In `BabyTracker/Info.plist`, ensure these keys are present:
```xml
<key>SUPABASE_URL</key>
<string>$(SUPABASE_URL)</string>
<key>SUPABASE_ANON_KEY</key>
<string>$(SUPABASE_ANON_KEY)</string>
<key>REVENUECAT_API_KEY</key>
<string>$(REVENUECAT_API_KEY)</string>
```

---

## 8. Supabase Setup

1. Create a project at [supabase.com](https://supabase.com)
2. Run `supabase/schema.sql` in the **SQL Editor**
3. Enable Realtime for these tables in **Database → Replication**:
   - `feed_entries`, `sleep_entries`, `diaper_entries`, `temperature_entries`, `handoff_notes`
4. In **Authentication → Providers**, enable **Sign in with Apple**
5. Set your app's Bundle ID in the Apple provider config

---

## 9. Run on Simulator

Select **iPhone 15 Pro** simulator with **iOS 17.0+** and press **Run**.

The app will start in anonymous mode (no sign-in required to test locally).
Onboarding fires on first launch (`hasCompletedOnboarding = false`).

---

## 10. Demo via Appetize.io

1. Archive the app: **Product → Archive**
2. Export as **Ad Hoc** or **Development** IPA
3. Upload to [appetize.io](https://appetize.io)
4. Share the generated URL — anyone can tap it in any browser

No TestFlight invite required for quick stakeholder demos.
