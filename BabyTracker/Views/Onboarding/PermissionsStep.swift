import SwiftUI
import UserNotifications

struct PermissionsStep: View {
    @Binding var notificationsGranted: Bool
    let onFinish: () -> Void

    @State private var notificationsRequested = false
    @State private var loading = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Stay in the loop")
                            .font(.title.bold())
                        Text("These permissions make the app more useful. You can change them anytime in Settings.")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)

                    VStack(spacing: 12) {
                        PermissionRow(
                            icon: "bell.badge.fill",
                            color: .red,
                            title: "Notifications",
                            description: "Feed reminders, medication alerts, and vaccine due dates.",
                            isGranted: notificationsGranted,
                            buttonLabel: notificationsRequested ? "Requested" : "Allow",
                            action: requestNotifications
                        )
                        PermissionRow(
                            icon: "camera.fill",
                            color: .indigo,
                            title: "Camera & Photos",
                            description: "Add photos to milestones and baby profiles.",
                            isGranted: false,
                            buttonLabel: "Allow when used",
                            action: nil  // iOS requests this at point-of-use
                        )
                    }
                }
                .padding(24)
            }

            Spacer(minLength: 0)

            // Finish
            VStack(spacing: 12) {
                Button {
                    loading = true
                    onFinish()
                } label: {
                    HStack {
                        if loading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Start Tracking")
                                .font(.headline)
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .disabled(loading)

                Text("You can set up syncing and more caregivers in Profile.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            .background(Color(.systemGroupedBackground))
        }
    }

    private func requestNotifications() {
        notificationsRequested = true
        Task {
            let granted = (try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])) ?? false
            await MainActor.run { notificationsGranted = granted }
        }
    }
}

private struct PermissionRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String
    let isGranted: Bool
    let buttonLabel: String
    let action: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title2)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title3)
            } else if let action {
                Button(buttonLabel, action: action)
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.borderedProminent)
                    .tint(color)
                    .controlSize(.small)
            } else {
                Text(buttonLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}
