import SwiftUI
import SwiftData
import ActivityKit

struct FeedLogSheet: View {

    let babyID: UUID
    var babyName: String = "Baby"
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(SyncManager.self) private var syncManager
    @Environment(\.currentCaregiver) private var currentCaregiver

    // Form state
    @State private var feedType: FeedType = .breast
    @State private var entryTime: Date = Date()
    @State private var notes: String = ""

    // Breast
    @State private var leftSeconds: Double = 0
    @State private var rightSeconds: Double = 0
    @State private var activeSide: BreastSide? = nil  // currently running side
    @State private var sideStartTime: Date? = nil
    @State private var lastFinishedSide: BreastSide = .left
    @State private var timerTick: Date = Date()
    @State private var timerTask: Task<Void, Never>? = nil

    // Bottle
    @State private var bottleVolume: Double = 120
    @State private var volumeUnit: VolumeDisplayUnit = .ml
    @State private var milkType: MilkType = .breast
    @State private var formulaBrand: String = ""

    // Solids
    @State private var foodName: String = ""
    @State private var hadReaction: Bool = false
    @State private var textureStage: TextureStage = .puree

    // Pump
    @State private var pumpLeft: Double = 0
    @State private var pumpRight: Double = 0
    @State private var pumpStorage: PumpStorage = .fridge

    var body: some View {
        NavigationStack {
            Form {
                typePicker
                timeSection
                switch feedType {
                case .breast:  breastSection
                case .bottle:  bottleSection
                case .solids:  solidsSection
                case .pump:    pumpSection
                }
                notesSection
            }
            .navigationTitle("Log Feeding")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        stopAllTimers()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.large])
        .onDisappear { stopAllTimers() }
    }

    // MARK: - Sections

    private var typePicker: some View {
        Section {
            Picker("Type", selection: $feedType) {
                Label("Breast", systemImage: "drop.fill").tag(FeedType.breast)
                Label("Bottle", systemImage: "waterbottle.fill").tag(FeedType.bottle)
                Label("Solids", systemImage: "fork.knife").tag(FeedType.solids)
                Label("Pump",   systemImage: "arrow.up.arrow.down.circle.fill").tag(FeedType.pump)
            }
            .pickerStyle(.segmented)
            .onChange(of: feedType) { stopAllTimers() }
        }
        .listRowBackground(Color.clear)
        .listRowInsets(.init(top: 8, leading: 0, bottom: 8, trailing: 0))
    }

    private var timeSection: some View {
        Section("Time") {
            DatePicker("Started", selection: $entryTime, displayedComponents: [.date, .hourAndMinute])
        }
    }

    // MARK: Breast

    private var breastSection: some View {
        Section {
            // Left side
            SideTimerRow(
                side: .left,
                color: .pink,
                seconds: leftSeconds + (activeSide == .left ? timerTick.timeIntervalSince(sideStartTime ?? timerTick) : 0),
                isRunning: activeSide == .left,
                onToggle: { toggleSide(.left) }
            )
            // Right side
            SideTimerRow(
                side: .right,
                color: .purple,
                seconds: rightSeconds + (activeSide == .right ? timerTick.timeIntervalSince(sideStartTime ?? timerTick) : 0),
                isRunning: activeSide == .right,
                onToggle: { toggleSide(.right) }
            )

            if leftSeconds > 0 || rightSeconds > 0 || activeSide != nil {
                let total = totalBreastSeconds
                HStack {
                    Text("Total")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formatSeconds(total))
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                }
            }
        } header: {
            Text("Breast Feeding")
        }
    }

    // MARK: Bottle

    private var bottleSection: some View {
        Section("Bottle") {
            HStack {
                Text("Volume")
                Spacer()
                TextField("Amount", value: $bottleVolume, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 70)
                Picker("", selection: $volumeUnit) {
                    Text("ml").tag(VolumeDisplayUnit.ml)
                    Text("oz").tag(VolumeDisplayUnit.oz)
                }
                .pickerStyle(.segmented)
                .frame(width: 80)
            }
            Picker("Milk type", selection: $milkType) {
                ForEach(MilkType.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            if milkType == .formula || milkType == .mixed {
                TextField("Formula brand (optional)", text: $formulaBrand)
            }
        }
    }

    // MARK: Solids

    private var solidsSection: some View {
        Section("Solids") {
            TextField("Food name", text: $foodName)
            Picker("Texture stage", selection: $textureStage) {
                ForEach(TextureStage.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            Toggle("Allergic reaction?", isOn: $hadReaction)
                .tint(.red)
        }
    }

    // MARK: Pump

    private var pumpSection: some View {
        Section("Pumping") {
            HStack {
                Label("Left", systemImage: "arrow.left")
                Spacer()
                TextField("ml", value: $pumpLeft, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)
                Text("ml").foregroundStyle(.secondary)
            }
            HStack {
                Label("Right", systemImage: "arrow.right")
                Spacer()
                TextField("ml", value: $pumpRight, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)
                Text("ml").foregroundStyle(.secondary)
            }
            if pumpLeft + pumpRight > 0 {
                HStack {
                    Text("Total")
                    Spacer()
                    Text("\(Int(pumpLeft + pumpRight))ml")
                        .fontWeight(.semibold)
                }
            }
            Picker("Storage", selection: $pumpStorage) {
                ForEach(PumpStorage.allCases, id: \.self) { Text($0.rawValue).tag($0) }
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

    private func toggleSide(_ side: BreastSide) {
        HapticManager.selection()
        let now = Date()

        if activeSide == side {
            // Stop this side — accumulate time
            let elapsed = now.timeIntervalSince(sideStartTime ?? now)
            if side == .left { leftSeconds += elapsed }
            else { rightSeconds += elapsed }
            activeSide = nil
            sideStartTime = nil
            lastFinishedSide = side
            stopTimerTask()
            Task { await LiveActivityService.shared.update(
                side: .none_, leftSeconds: leftSeconds,
                rightSeconds: rightSeconds, sideStartedAt: nil, isRunning: false
            )}
        } else {
            // Stop the other side first
            if let running = activeSide {
                let elapsed = now.timeIntervalSince(sideStartTime ?? now)
                if running == .left { leftSeconds += elapsed }
                else { rightSeconds += elapsed }
                lastFinishedSide = running
            }
            // Start new side
            activeSide = side
            sideStartTime = now
            startTimerTask()

            // Start or update Live Activity
            let liveSide: BreastSideLive = side == .left ? .left : .right
            Task {
                if LiveActivityService.shared.isActive {
                    await LiveActivityService.shared.update(
                        side: liveSide, leftSeconds: leftSeconds,
                        rightSeconds: rightSeconds, sideStartedAt: now, isRunning: true
                    )
                } else {
                    await LiveActivityService.shared.start(babyName: babyName, side: liveSide)
                }
            }
        }
    }

    private func startTimerTask() {
        stopTimerTask()
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                await MainActor.run { timerTick = Date() }
            }
        }
    }

    private func stopTimerTask() {
        timerTask?.cancel()
        timerTask = nil
    }

    private func stopAllTimers() {
        if let running = activeSide {
            let elapsed = Date().timeIntervalSince(sideStartTime ?? Date())
            if running == .left { leftSeconds += elapsed }
            else { rightSeconds += elapsed }
            activeSide = nil
        }
        stopTimerTask()
        Task { await LiveActivityService.shared.stop() }
    }

    private var totalBreastSeconds: Double {
        var total = leftSeconds + rightSeconds
        if let side = activeSide, let start = sideStartTime {
            total += timerTick.timeIntervalSince(start)
        }
        return total
    }

    // MARK: - Save

    private func save() {
        stopAllTimers()

        let caregiverID = currentCaregiver?.id ?? UUID()
        let entry = FeedEntry(babyID: babyID, caregiverID: caregiverID, feedType: feedType, timestamp: entryTime)
        entry.notes = notes.isEmpty ? nil : notes

        switch feedType {
        case .breast:
            entry.leftDurationSeconds = leftSeconds > 0 ? leftSeconds : nil
            entry.rightDurationSeconds = rightSeconds > 0 ? rightSeconds : nil
            entry.lastSide = lastFinishedSide
        case .bottle:
            let ml = volumeUnit == .ml ? bottleVolume : bottleVolume * 29.5735
            entry.volumeMl = ml
            entry.milkType = milkType
            entry.formulaBrand = milkType == .breast ? nil : (formulaBrand.isEmpty ? nil : formulaBrand)
        case .solids:
            entry.foodName = foodName.isEmpty ? nil : foodName
            entry.hadReaction = hadReaction
            entry.textureStage = textureStage
        case .pump:
            entry.pumpLeftMl = pumpLeft > 0 ? pumpLeft : nil
            entry.pumpRightMl = pumpRight > 0 ? pumpRight : nil
            entry.pumpStorage = pumpStorage
        }

        modelContext.insert(entry)
        try? modelContext.save()
        HapticManager.success()

        // Reschedule feed reminder (default 3-hour interval)
        Task {
            await NotificationService.shared.scheduleFeedReminder(
                babyID: babyID,
                babyName: babyName,
                lastFeedAt: entryTime,
                intervalMinutes: 180
            )
        }

        onSave()
        dismiss()
    }

    // MARK: - Helpers

    func formatSeconds(_ s: Double) -> String {
        let total = Int(s)
        let m = total / 60; let sec = total % 60
        if m >= 60 { return String(format: "%d:%02d:%02d", m / 60, m % 60, sec) }
        return String(format: "%d:%02d", m, sec)
    }
}

// MARK: - Side Timer Row

struct SideTimerRow: View {
    let side: BreastSide
    let color: Color
    let seconds: Double
    let isRunning: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(side == .left ? "Left" : "Right")
                    .font(.subheadline.weight(.medium))
                Text(formatTime(seconds))
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundStyle(isRunning ? color : .primary)
                    .contentTransition(.numericText())
            }
            Spacer()
            Button(action: onToggle) {
                Image(systemName: isRunning ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(color)
                    .symbolEffect(.pulse, isActive: isRunning)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    private func formatTime(_ s: Double) -> String {
        let total = Int(s)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

// MARK: - Volume display unit

enum VolumeDisplayUnit { case ml, oz }
