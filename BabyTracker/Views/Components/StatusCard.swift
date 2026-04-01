import SwiftUI

struct StatusCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let primary: String
    let secondary: String
    var isHighlighted: Bool = false
    var action: (() -> Void)?

    var body: some View {
        Button {
            action?()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .foregroundStyle(iconColor)
                        .font(.system(size: 15, weight: .semibold))
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                Text(primary)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(isHighlighted ? iconColor : .primary)
                    .contentTransition(.numericText())
                Text(secondary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isHighlighted ? iconColor.opacity(0.1) : Color(.secondarySystemGroupedBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(isHighlighted ? iconColor.opacity(0.3) : .clear, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
}

// MARK: - Baby Chip

struct BabyChip: View {
    let baby: Baby
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                BabyAvatar(baby: baby, size: 24)
                Text(baby.name)
                    .font(.subheadline.weight(isActive ? .semibold : .regular))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(isActive ? Color.accentColor : Color(.secondarySystemGroupedBackground))
            )
            .foregroundStyle(isActive ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Baby Avatar

struct BabyAvatar: View {
    let baby: Baby
    let size: CGFloat

    var body: some View {
        Group {
            if let data = baby.photoData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Circle()
                    .fill(avatarColor(for: baby.name))
                    .overlay(
                        Text(baby.name.prefix(1).uppercased())
                            .font(.system(size: size * 0.45, weight: .bold))
                            .foregroundStyle(.white)
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private func avatarColor(for name: String) -> Color {
        let colors: [Color] = [.pink, .purple, .indigo, .blue, .teal, .green, .orange]
        let index = abs(name.hashValue) % colors.count
        return colors[index]
    }
}

// MARK: - Summary Row

struct SummaryRow: View {
    let icon: String
    let color: Color
    let label: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 20)
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
}

// MARK: - Sync Status Indicator

struct SyncStatusIndicator: View {
    let syncManager: SyncManager

    var body: some View {
        HStack(spacing: 4) {
            switch syncManager.state {
            case .syncing:
                ProgressView()
                    .scaleEffect(0.7)
            case .idle:
                if syncManager.networkState == .offline {
                    Image(systemName: "wifi.slash")
                        .foregroundStyle(.orange)
                        .font(.caption)
                } else if syncManager.pendingOperationsCount > 0 {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundStyle(.blue)
                        .font(.caption)
                }
            case .paused:
                Image(systemName: "pause.circle")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .animation(.easeInOut, value: syncManager.networkState)
    }
}
