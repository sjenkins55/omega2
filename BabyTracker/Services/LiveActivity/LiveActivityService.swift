import ActivityKit
import Foundation

/// Manages the nursing timer Live Activity lifecycle.
///
/// The Live Activity shows on the Lock Screen and in the Dynamic Island
/// while a breast feeding session is in progress.
///
/// Usage:
///   - FeedLogSheet calls start() when the first side timer starts
///   - FeedLogSheet calls update() every time a side is toggled
///   - FeedLogSheet calls stop() when the user saves the entry

@MainActor
final class LiveActivityService {

    static let shared = LiveActivityService()
    private init() {}

    private var currentActivity: Activity<NursingTimerAttributes>?

    // MARK: - Start

    func start(babyName: String, side: BreastSideLive) async {
        // Only one nursing Live Activity at a time
        guard currentActivity == nil else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = NursingTimerAttributes(babyName: babyName, startedAt: Date())
        let state = NursingTimerAttributes.ContentState(
            activeSide: side,
            leftSeconds: 0,
            rightSeconds: 0,
            sideStartedAt: Date(),
            isRunning: true
        )

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil),
                pushType: nil  // local only — no push token needed
            )
        } catch {
            print("[LiveActivity] Failed to start: \(error)")
        }
    }

    // MARK: - Update

    func update(side: BreastSideLive, leftSeconds: Double, rightSeconds: Double,
                sideStartedAt: Date?, isRunning: Bool) async {
        guard let activity = currentActivity else { return }

        let state = NursingTimerAttributes.ContentState(
            activeSide: side,
            leftSeconds: leftSeconds,
            rightSeconds: rightSeconds,
            sideStartedAt: sideStartedAt,
            isRunning: isRunning
        )
        await activity.update(.init(state: state, staleDate: nil))
    }

    // MARK: - Stop

    func stop() async {
        guard let activity = currentActivity else { return }
        await activity.end(nil, dismissalPolicy: .immediate)
        currentActivity = nil
    }

    var isActive: Bool { currentActivity != nil }
}

// MARK: - Lock Screen / Dynamic Island UI
// This view is rendered inside the Widget extension target.
// Add it to BabyTrackerWidget.swift under a new ActivityConfiguration block.
//
// Example (add to BabyTrackerWidgetBundle):
//
//   struct NursingTimerLiveActivity: Widget {
//       var body: some WidgetConfiguration {
//           ActivityConfiguration(for: NursingTimerAttributes.self) { context in
//               NursingTimerLockScreenView(context: context)
//                   .activityBackgroundTint(Color.indigo.opacity(0.15))
//           } dynamicIsland: { context in
//               DynamicIsland {
//                   DynamicIslandExpandedRegion(.leading) {
//                       Label(context.attributes.babyName, systemImage: "moon.fill")
//                           .foregroundStyle(.indigo)
//                   }
//                   DynamicIslandExpandedRegion(.trailing) {
//                       NursingTimerCompactView(state: context.state)
//                   }
//                   DynamicIslandExpandedRegion(.bottom) {
//                       NursingTimerExpandedView(attrs: context.attributes, state: context.state)
//                   }
//               } compactLeading: {
//                   Image(systemName: "drop.fill").foregroundStyle(.blue)
//               } compactTrailing: {
//                   NursingTimerCompactView(state: context.state)
//               } minimal: {
//                   Image(systemName: "drop.fill").foregroundStyle(.blue)
//               }
//           }
//       }
//   }
