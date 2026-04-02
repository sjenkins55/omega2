import UIKit

/// Centralized haptic feedback. Use these instead of calling UIImpactFeedbackGenerator
/// directly so feedback style is consistent across the app.
enum HapticManager {

    // MARK: - Impact

    /// Light tap — list row selections, chip toggles
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// Medium — button presses, FAB expand
    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// Heavy — destructive confirms, timer start
    static func heavy() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    // MARK: - Notification

    /// Success — entry saved, milestone achieved
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Warning — alarm color stool, fever temperature
    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    /// Error — validation failure, network error
    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    // MARK: - Selection

    /// Subtle tick — picker value changes, side switch during nursing
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
