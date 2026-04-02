import SwiftUI

struct EntryRow: View {
    let entry: any HistoryEntry

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: iconName)
                    .foregroundStyle(iconColor)
                    .font(.system(size: 16, weight: .semibold))
            }

            // Detail
            VStack(alignment: .leading, spacing: 3) {
                Text(primaryLabel)
                    .font(.subheadline.weight(.medium))
                if let secondary = secondaryLabel {
                    Text(secondary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Time
            Text(entry.timestamp.timeString)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Per-type presentation

    private var iconName: String {
        switch entry {
        case let f as FeedEntry:
            switch f.feedType {
            case .breast: return "drop.fill"
            case .bottle: return "waterbottle.fill"
            case .solids: return "fork.knife"
            case .pump:   return "arrow.up.arrow.down.circle.fill"
            }
        case is SleepEntry: return "moon.fill"
        case is DiaperEntry: return "drop.triangle.fill"
        case is TemperatureEntry: return "thermometer.medium"
        default: return "circle.fill"
        }
    }

    private var iconColor: Color {
        switch entry {
        case let f as FeedEntry:
            switch f.feedType {
            case .breast, .bottle, .pump: return .blue
            case .solids: return .green
            }
        case is SleepEntry: return .indigo
        case is DiaperEntry: return .orange
        case is TemperatureEntry: return .red
        default: return .gray
        }
    }

    private var primaryLabel: String {
        switch entry {
        case let f as FeedEntry:
            switch f.feedType {
            case .breast:
                let mins = Int(f.totalDurationSeconds / 60)
                return mins > 0 ? "Breastfed · \(mins)m" : "Breastfed"
            case .bottle:
                return f.volumeMl.map { "Bottle · \(Int($0))ml" } ?? "Bottle"
            case .solids:
                return f.foodName.map { "Solids · \($0)" } ?? "Solids"
            case .pump:
                let total = (f.pumpLeftMl ?? 0) + (f.pumpRightMl ?? 0)
                return total > 0 ? "Pumped · \(Int(total))ml" : "Pump session"
            }
        case let s as SleepEntry:
            if let dur = s.durationSeconds {
                let m = Int(dur / 60)
                return "\(s.sleepType.rawValue) · \(m / 60)h \(m % 60)m"
            }
            return s.isOngoing ? "\(s.sleepType.rawValue) (in progress)" : s.sleepType.rawValue
        case let d as DiaperEntry:
            return "Diaper · \(d.diaperType.rawValue)"
        case let t as TemperatureEntry:
            let f = String(format: "%.1f", t.valueFahrenheit)
            return "\(f)°F · \(t.method.rawValue)"
        default:
            return "Entry"
        }
    }

    private var secondaryLabel: String? {
        switch entry {
        case let f as FeedEntry:
            if f.feedType == .breast, let side = f.lastSide {
                return "Last side: \(side.rawValue.capitalized)"
            }
            if f.feedType == .bottle, let type = f.milkType { return type.rawValue }
            if let notes = f.notes, !notes.isEmpty { return notes }
            return nil
        case let s as SleepEntry:
            var parts: [String] = [s.location.rawValue]
            if let q = s.qualityRating { parts.append(String(repeating: "★", count: q)) }
            return parts.joined(separator: " · ")
        case let d as DiaperEntry:
            var parts: [String] = []
            if let c = d.stoolColor { parts.append(c.rawValue) }
            if let cons = d.stoolConsistency { parts.append(cons.rawValue) }
            return parts.isEmpty ? nil : parts.joined(separator: " · ")
        case let t as TemperatureEntry:
            return t.isFever ? "⚠️ Fever" : "Normal"
        default:
            return nil
        }
    }
}

extension Date {
    var timeString: String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: self)
    }
}
