import SwiftUI

struct WakeWindowBar: View {
    let vm: HomeViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: iconName)
                    .foregroundStyle(barColor)
                    .font(.subheadline.weight(.semibold))
                Text(vm.wakeWindowLabel)
                    .font(.subheadline.weight(.medium))
                Spacer()
                if vm.ongoingSleep == nil && vm.minutesAwake > 0 {
                    Text(nextNapLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemFill))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: barGradient,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * vm.wakeWindowProgress, height: 8)
                        .animation(.linear(duration: 1), value: vm.wakeWindowProgress)
                }
            }
            .frame(height: 8)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var iconName: String {
        switch vm.wakeWindowColor {
        case .sleeping: return "moon.zzz.fill"
        case .early: return "sun.min.fill"
        case .ready: return "sun.max.fill"
        case .overdue: return "exclamationmark.circle.fill"
        }
    }

    private var barColor: Color {
        switch vm.wakeWindowColor {
        case .sleeping: return .indigo
        case .early: return .green
        case .ready: return .yellow
        case .overdue: return .red
        }
    }

    private var barGradient: [Color] {
        switch vm.wakeWindowColor {
        case .sleeping: return [.indigo.opacity(0.6), .indigo]
        case .early: return [.green, .yellow]
        case .ready: return [.green, .yellow, .orange]
        case .overdue: return [.green, .yellow, .orange, .red]
        }
    }

    private var nextNapLabel: String {
        let remaining = vm.wakeWindowGoalMinutes - vm.minutesAwake
        if remaining <= 0 { return "Nap time!" }
        let m = Int(remaining)
        if m < 60 { return "Nap in \(m)m" }
        return "Nap in \(m / 60)h \(m % 60)m"
    }
}
