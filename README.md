# BabyTracker

iOS app for tracking feeding, sleep, diapers, growth, milestones, and health for one or more babies. Supports multiple caregivers with role-based access.

## Tech Stack

- **SwiftUI** (iOS 17+)
- **SwiftData** — local offline-first persistence
- **Supabase** — backend (PostgreSQL + Auth + Realtime + Storage)
- **RevenueCat** — freemium subscription management

## Project Structure

```
BabyTracker/
├── App/
│   ├── BabyTrackerApp.swift     # Entry point, ModelContainer, Environment setup
│   └── Config.xcconfig          # Build config template (copy → Config.local.xcconfig)
├── Models/
│   ├── Baby.swift               # Baby profile + age helpers
│   ├── Entries.swift            # FeedEntry, SleepEntry, DiaperEntry, TemperatureEntry
│   ├── Health.swift             # Measurement, Milestone, Vaccine, Appointment, Medication, Illness
│   ├── Caregiver.swift          # Caregiver, BabyAccess, HandoffNote, CaregiverInvite
│   └── SyncTypes.swift          # SyncStatus, SyncOperation, NetworkState
├── Repositories/
│   ├── EntryRepository.swift    # CRUD for all log entries (enforces permissions)
│   └── BabyRepository.swift     # Baby + caregiver management
├── Services/
│   ├── Sync/
│   │   ├── SyncManager.swift    # Offline queue, drain, real-time inbound merge
│   │   └── SupabaseService.swift # Supabase SDK wrapper (auth, upsert, delete, realtime)
│   └── Auth/
│       └── AuthService.swift    # Sign in with Apple, anonymous mode, account linking
├── ViewModels/                  # @Observable ViewModels (to be built)
├── Views/                       # SwiftUI views (to be built)
│   ├── Onboarding/
│   ├── Home/
│   ├── Log/
│   ├── History/
│   ├── Insights/
│   └── Profile/
└── Utils/

supabase/
└── schema.sql                   # Full DB schema with RLS policies
```

## Offline-First Sync Architecture

```
Write:  View → ViewModel → Repository → SwiftData (instant)
                                      → SyncManager.enqueue()
                                           ↓ (when online)
                                      Supabase upsert

Read:   Supabase Realtime → SyncManager → Repository.merge() → SwiftData
```

**Conflict resolution**: last-write-wins based on `updated_at`. Since two caregivers
logging simultaneously is the common case (not editing the same entry), this is safe.

## Caregiver Roles

| Role | Add/Edit Entries | Delete Entries | Manage Babies | Manage Caregivers |
|---|---|---|---|---|
| Admin | ✅ | ✅ | ✅ | ✅ |
| Caregiver | ✅ | ❌ | ❌ | ❌ |
| Viewer | ❌ | ❌ | ❌ | ❌ |

Roles are enforced in two places: app-layer (`CaregiverRole` permission helpers) and database-layer (Supabase RLS policies in `schema.sql`).

## Setup

1. Create a Supabase project at supabase.com
2. Run `supabase/schema.sql` in the SQL editor
3. Enable Realtime for `feed_entries`, `sleep_entries`, `diaper_entries`, `temperature_entries`, `handoff_notes`
4. Copy `Config.xcconfig` → `Config.local.xcconfig` and fill in your keys
5. Add Swift Package dependencies in Xcode:
   - `https://github.com/supabase/supabase-swift`
   - `https://github.com/RevenueCat/purchases-ios`
   - `https://github.com/getsentry/sentry-cocoa`
6. Open the project in Xcode and run on a simulator (iOS 17+)
