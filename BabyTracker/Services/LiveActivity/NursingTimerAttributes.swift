import ActivityKit
import Foundation

/// ActivityKit attributes for the nursing timer Live Activity.
/// Shows on the Lock Screen and in the Dynamic Island while a breast feed is in progress.
///
/// Xcode setup:
///   1. Add "Supports Live Activities" key = YES to Info.plist
///   2. Add NSSupportsLiveActivities = YES to Info.plist
///   3. The Live Activity UI is rendered in BabyTrackerWidgetBundle
///      (add a new ActivityConfiguration to the widget bundle)

struct NursingTimerAttributes: ActivityAttributes {

    // Static data — set when the activity starts, never changes
    struct ContentState: Codable, Hashable {
        var activeSide: BreastSideLive
        var leftSeconds: Double
        var rightSeconds: Double
        var sideStartedAt: Date?       // nil if paused
        var isRunning: Bool
    }

    var babyName: String
    var startedAt: Date
}

enum BreastSideLive: String, Codable, Hashable {
    case left, right, none_
}
