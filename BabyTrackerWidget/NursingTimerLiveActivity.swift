import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Live Activity Widget

struct NursingTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NursingTimerAttributes.self) { context in
            // Lock Screen banner
            NursingTimerLockScreenView(attrs: context.attributes, state: context.state)
                .activityBackgroundTint(Color.indigo.opacity(0.12))
                .activitySystemActionForegroundColor(Color.indigo)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded (long-press)
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Label(context.attributes.babyName, systemImage: "moon.zzz.fill")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.indigo)
                        Text("Nursing")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(totalTimeLabel(context.state))
                            .font(.system(.callout, design: .monospaced, weight: .bold))
                            .foregroundStyle(.primary)
                        Text("total")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    NursingTimerExpandedView(attrs: context.attributes, state: context.state)
                }
            } compactLeading: {
                Image(systemName: "drop.fill")
                    .foregroundStyle(.blue)
                    .font(.caption)
            } compactTrailing: {
                Text(compactTimeLabel(context.state))
                    .font(.system(.caption, design: .monospaced, weight: .semibold))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "drop.fill")
                    .foregroundStyle(.blue)
            }
            .keylineTint(.indigo)
        }
    }
}

// MARK: - Lock Screen View

struct NursingTimerLockScreenView: View {
    let attrs: NursingTimerAttributes
    let state: NursingTimerAttributes.ContentState

    var body: some View {
        HStack(spacing: 16) {
            // Baby name + session start
            VStack(alignment: .leading, spacing: 4) {
                Label(attrs.babyName, systemImage: "moon.zzz.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.indigo)
                Text(attrs.startedAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Per-side timers
            VStack(alignment: .trailing, spacing: 6) {
                SideTimerBadge(
                    side: "L",
                    color: .pink,
                    seconds: state.leftSeconds + currentSideExtra(side: .left, state: state),
                    isActive: state.activeSide == .left && state.isRunning
                )
                SideTimerBadge(
                    side: "R",
                    color: .purple,
                    seconds: state.rightSeconds + currentSideExtra(side: .right, state: state),
                    isActive: state.activeSide == .right && state.isRunning
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Expanded Dynamic Island view

struct NursingTimerExpandedView: View {
    let attrs: NursingTimerAttributes
    let state: NursingTimerAttributes.ContentState

    var body: some View {
        HStack(spacing: 20) {
            SideTimerBadge(
                side: "Left",
                color: .pink,
                seconds: state.leftSeconds + currentSideExtra(side: .left, state: state),
                isActive: state.activeSide == .left && state.isRunning
            )
            Divider().frame(height: 28)
            SideTimerBadge(
                side: "Right",
                color: .purple,
                seconds: state.rightSeconds + currentSideExtra(side: .right, state: state),
                isActive: state.activeSide == .right && state.isRunning
            )
            Spacer()
            VStack(alignment: .trailing) {
                Text("Total")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(formatSeconds(
                    state.leftSeconds + state.rightSeconds
                    + currentSideExtra(side: state.activeSide == .left ? .left : .right, state: state)
                ))
                .font(.system(.callout, design: .monospaced, weight: .bold))
            }
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 4)
    }
}

// MARK: - Side timer badge

struct SideTimerBadge: View {
    let side: String
    let color: Color
    let seconds: Double
    let isActive: Bool

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isActive ? color : color.opacity(0.3))
                .frame(width: 6, height: 6)
                .symbolEffect(.pulse, isActive: isActive)
            VStack(alignment: .leading, spacing: 1) {
                Text(side)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(formatSeconds(seconds))
                    .font(.system(.caption, design: .monospaced, weight: .semibold))
                    .foregroundStyle(isActive ? color : .primary)
            }
        }
    }
}

// MARK: - Helpers

private func currentSideExtra(side: BreastSideLive, state: NursingTimerAttributes.ContentState) -> Double {
    guard state.isRunning, state.activeSide == side, let startedAt = state.sideStartedAt else { return 0 }
    return Date().timeIntervalSince(startedAt)
}

private func formatSeconds(_ s: Double) -> String {
    let total = Int(s)
    return String(format: "%d:%02d", total / 60, total % 60)
}

private func totalTimeLabel(_ state: NursingTimerAttributes.ContentState) -> String {
    let total = state.leftSeconds + state.rightSeconds
        + currentSideExtra(side: state.activeSide == .left ? .left : .right, state: state)
    return formatSeconds(total)
}

private func compactTimeLabel(_ state: NursingTimerAttributes.ContentState) -> String {
    let total = state.leftSeconds + state.rightSeconds
        + currentSideExtra(side: state.activeSide == .left ? .left : .right, state: state)
    let m = Int(total) / 60
    return "\(m)m"
}
