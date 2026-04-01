import SwiftUI
import SwiftData

struct SleepLogSheet: View {

    let babyID: UUID
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(SyncManager.self) private var syncManager

    enum LogMode { case timer, manual }

    @State private var mode: LogMode = .timer
    @State private var sleepType: SleepType = .nap
    @State private var location: SleepLocation = .crib
    @State private var qualityRating: Int = 0   // 0 = not set
    @State private var notes: String = ""

    // Timer mode
    @State private var timerRunning: Bool = false
    @State private var timerStart: Date? = nil
    @State private var elapsed: TimeInterval = 0
    @State private var timerTask: Task<Void, Never>? = nil

    // Manual mode
    @State private var manualStart: Date = Calendar.current.date(byAdding: .hour, value: -1, to: Date())!
    @State private var manualEnd: Date = Date()

    var body: some View {
        NavigationStack {
            Form {
                modePicker
                typeAndLocation
                switch mode {
                case .timer:  timerSection
                case .manual: manualSection
                }
                qualitySection
                notesSection
            }
            .navigationTitle("Log Sleep")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        stopTimer()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(mode == .timer && !timerRunning && elapsed == 0)
                }
            }
        }
        .presentationDetents([.large])
        .onDisappear { stopTimer() }
    }

    // MARK: - Sections

    private var modePicker: some View {
        Section {
            Picker("Mode", selection: $mode) {
                Label("Timer", systemImage: "timer").tag(LogMode.timer)
                Label("Manual", systemImage: "calendar.badge.clock").tag(LogMode.manual)
            }
            .pickerStyle(.segmented)
            .onChange(of: mode) { stopTimer() }
        }
        .listRowBackground(Color.clear)
        .listRowInsets(.init(top: 8, leading: 0, bottom: 8, trailing: 0))
    }

    private var typeAndLocation: some View {
        Section {
            Picker("Type", selection: $sleepType) {
                ForEach(SleepType.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            Picker("Location", selection: $location) {
                ForEach(SleepLocation.allCases, id: \.self) {
                    Label($0.rawValue, systemImage: locationIcon($0)).tag($0)
                }
            }
        }
    }

    private var timerSection: some View {
        Section {
            VStack(spacing: 24) {
                // Big elapsed display
                Text(formatElapsed(elapsed))
                    .font(.system(size: 56, weight: .bold, design: .monospaced))
                    .foregroundStyle(timerRunning ? .primary : .secondary)
                    .contentTransition(.numericText())
                    .frame(maxWidth: .infinity)

                // Start / Stop button
                Button {
                    timerRunning ? stopTimer() : startTimer()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: timerRunning ? "stop.fill" : "play.fill")
                        Text(timerRunning ? "Stop Sleep" : (elapsed > 0 ? "Resume" : "Start Sleep"))
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(timerRunning ? Color.red : Color.indigo, in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)

                if elapsed > 0 && !timerRunning {
                    Text("Started \(timerStart.map { startedLabel($0) } ?? "")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 8)
        }
        .listRowBackground(Color.clear)
    }

    private var manualSection: some View {
        Section("Time") {
            DatePicker("Started", selection: $manualStart, displayedComponents: [.date, .hourAndMinute])
            DatePicker("Ended", selection: $manualEnd, in: manualStart..., displayedComponents: [.date, .hourAndMinute])
            HStack {
                Text("Duration")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formatElapsed(manualEnd.timeIntervalSince(manualStart)))
                    .fontWeight(.medium)
            }
        }
    }

    private var qualitySection: some View {
        Section("Quality (optional)") {
            HStack(spacing: 12) {
                ForEach(1...5, id: \.self) { star in
                    Image(systemName: star <= qualityRating ? "star.fill" : "star")
                        .foregroundStyle(star <= qualityRating ? .yellow : .secondary)
                        .font(.title2)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.2)) {
                                qualityRating = qualityRating == star ? 0 : star
                            }
                        }
                }
                if qualityRating > 0 {
                    Text(qualityLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var notesSection: some View {
        Section("Notes") {
            TextField("Optional notes", text: $notes, axis: .vertical)
                .lineLimit(3...6)
        }
    }

    // MARK: - Timer logic

    private func startTimer() {
        if timerStart == nil { timerStart = Date() }
        timerRunning = true
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000)
                await MainActor.run {
                    if let start = timerStart {
                        elapsed = Date().timeIntervalSince(start)
                    }
                }
            }
        }
    }

    private func stopTimer() {
        timerRunning = false
        timerTask?.cancel()
        timerTask = nil
        if let start = timerStart {
            elapsed = Date().timeIntervalSince(start)
        }
    }

    // MARK: - Save

    private func save() {
        stopTimer()

        let caregiverID = UUID() // placeholder
        let entry = SleepEntry(babyID: babyID, caregiverID: caregiverID, sleepType: sleepType)
        entry.location = location
        entry.qualityRating = qualityRating > 0 ? qualityRating : nil
        entry.notes = notes.isEmpty ? nil : notes

        switch mode {
        case .timer:
            entry.startTime = timerStart ?? Date().addingTimeInterval(-elapsed)
            entry.endTime = Date()
            entry.timestamp = entry.startTime
        case .manual:
            entry.startTime = manualStart
            entry.endTime = manualEnd
            entry.timestamp = manualStart
        }

        modelContext.insert(entry)
        try? modelContext.save()
        onSave()
        dismiss()
    }

    // MARK: - Helpers

    private func formatElapsed(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }

    private func startedLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func locationIcon(_ loc: SleepLocation) -> String {
        switch loc {
        case .crib:       return "bed.double.fill"
        case .bassinet:   return "moon.stars.fill"
        case .contactNap: return "figure.and.child.holdinghands"
        case .stroller:   return "figure.walk"
        case .carSeat:    return "car.fill"
        case .bed:        return "bed.double"
        case .other:      return "questionmark.circle"
        }
    }

    private var qualityLabel: String {
        ["", "Poor", "Fair", "Good", "Great", "Perfect"][qualityRating]
    }
}
