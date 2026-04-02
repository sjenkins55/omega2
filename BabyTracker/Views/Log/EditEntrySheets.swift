import SwiftUI
import SwiftData

// MARK: - Edit Feed Entry

struct EditFeedSheet: View {

    @Bindable var entry: FeedEntry
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(SyncManager.self) private var syncManager

    var body: some View {
        NavigationStack {
            Form {
                Section("Type") {
                    Picker("Feed type", selection: $entry.feedType) {
                        ForEach(FeedType.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Time") {
                    DatePicker("Time", selection: $entry.timestamp, displayedComponents: [.date, .hourAndMinute])
                }

                switch entry.feedType {
                case .breast:
                    Section("Duration") {
                        DurationField(label: "Left side", seconds: Binding(
                            get: { entry.leftDurationSeconds ?? 0 },
                            set: { entry.leftDurationSeconds = $0 > 0 ? $0 : nil }
                        ))
                        DurationField(label: "Right side", seconds: Binding(
                            get: { entry.rightDurationSeconds ?? 0 },
                            set: { entry.rightDurationSeconds = $0 > 0 ? $0 : nil }
                        ))
                    }

                case .bottle:
                    Section("Volume") {
                        HStack {
                            Text("Volume (ml)")
                            Spacer()
                            TextField("ml", value: Binding(
                                get: { entry.volumeMl ?? 0 },
                                set: { entry.volumeMl = $0 > 0 ? $0 : nil }
                            ), format: .number)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                            .frame(width: 80)
                        }
                        if let milkType = entry.milkType {
                            Picker("Milk type", selection: Binding(
                                get: { milkType },
                                set: { entry.milkType = $0 }
                            )) {
                                ForEach(MilkType.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                            }
                        }
                    }

                case .solids:
                    Section("Food") {
                        TextField("Food name", text: Binding(
                            get: { entry.foodName ?? "" },
                            set: { entry.foodName = $0.isEmpty ? nil : $0 }
                        ))
                        Toggle("Had reaction", isOn: Binding(
                            get: { entry.hadReaction ?? false },
                            set: { entry.hadReaction = $0 }
                        )).tint(.red)
                    }

                case .pump:
                    Section("Volume") {
                        HStack {
                            Label("Left", systemImage: "arrow.left")
                            Spacer()
                            TextField("ml", value: Binding(
                                get: { entry.pumpLeftMl ?? 0 },
                                set: { entry.pumpLeftMl = $0 > 0 ? $0 : nil }
                            ), format: .number)
                            .multilineTextAlignment(.trailing).keyboardType(.decimalPad).frame(width: 70)
                            Text("ml").foregroundStyle(.secondary)
                        }
                        HStack {
                            Label("Right", systemImage: "arrow.right")
                            Spacer()
                            TextField("ml", value: Binding(
                                get: { entry.pumpRightMl ?? 0 },
                                set: { entry.pumpRightMl = $0 > 0 ? $0 : nil }
                            ), format: .number)
                            .multilineTextAlignment(.trailing).keyboardType(.decimalPad).frame(width: 70)
                            Text("ml").foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Notes") {
                    TextField("Notes", text: Binding(
                        get: { entry.notes ?? "" },
                        set: { entry.notes = $0.isEmpty ? nil : $0 }
                    ), axis: .vertical).lineLimit(2...4)
                }
            }
            .navigationTitle("Edit Feeding")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        entry.updatedAt = Date()
                        entry.syncStatus = .pending
                        try? modelContext.save()
                        syncManager.enqueue(SyncOperation(
                            modelType: "FeedEntry", modelID: entry.id, operation: .update, payload: Data()
                        ))
                        HapticManager.success()
                        onSave()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - Edit Sleep Entry

struct EditSleepSheet: View {

    @Bindable var entry: SleepEntry
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(SyncManager.self) private var syncManager

    var body: some View {
        NavigationStack {
            Form {
                Section("Type & Location") {
                    Picker("Type", selection: $entry.sleepType) {
                        ForEach(SleepType.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    Picker("Location", selection: $entry.location) {
                        ForEach(SleepLocation.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                }
                Section("Time") {
                    DatePicker("Start", selection: $entry.startTime, displayedComponents: [.date, .hourAndMinute])
                    if entry.endTime != nil {
                        DatePicker("End", selection: Binding(
                            get: { entry.endTime ?? Date() },
                            set: { entry.endTime = $0 }
                        ), in: entry.startTime..., displayedComponents: [.date, .hourAndMinute])
                        if let dur = entry.durationSeconds {
                            let m = Int(dur / 60)
                            HStack {
                                Text("Duration").foregroundStyle(.secondary)
                                Spacer()
                                Text("\(m / 60)h \(m % 60)m").fontWeight(.medium)
                            }
                        }
                    }
                }
                Section("Quality") {
                    HStack(spacing: 12) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= (entry.qualityRating ?? 0) ? "star.fill" : "star")
                                .foregroundStyle(star <= (entry.qualityRating ?? 0) ? .yellow : .secondary)
                                .font(.title2)
                                .onTapGesture {
                                    entry.qualityRating = entry.qualityRating == star ? nil : star
                                }
                        }
                    }
                }
                Section("Notes") {
                    TextField("Notes", text: Binding(
                        get: { entry.notes ?? "" },
                        set: { entry.notes = $0.isEmpty ? nil : $0 }
                    ), axis: .vertical).lineLimit(2...4)
                }
            }
            .navigationTitle("Edit Sleep")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        entry.updatedAt = Date()
                        entry.syncStatus = .pending
                        try? modelContext.save()
                        syncManager.enqueue(SyncOperation(
                            modelType: "SleepEntry", modelID: entry.id, operation: .update, payload: Data()
                        ))
                        HapticManager.success()
                        onSave()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - Edit Diaper Entry

struct EditDiaperSheet: View {

    @Bindable var entry: DiaperEntry
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(SyncManager.self) private var syncManager

    var body: some View {
        NavigationStack {
            Form {
                Section("Type") {
                    Picker("Diaper type", selection: $entry.diaperType) {
                        ForEach(DiaperType.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                Section("Time") {
                    DatePicker("Time", selection: $entry.timestamp, displayedComponents: [.date, .hourAndMinute])
                }
                if entry.diaperType == .dirty || entry.diaperType == .both {
                    Section("Stool") {
                        Picker("Color", selection: Binding(
                            get: { entry.stoolColor ?? .yellow },
                            set: { entry.stoolColor = $0 }
                        )) {
                            ForEach(StoolColor.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        Picker("Consistency", selection: Binding(
                            get: { entry.stoolConsistency ?? .loose },
                            set: { entry.stoolConsistency = $0 }
                        )) {
                            ForEach(StoolConsistency.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                    }
                }
                Section("Notes") {
                    TextField("Notes", text: Binding(
                        get: { entry.notes ?? "" },
                        set: { entry.notes = $0.isEmpty ? nil : $0 }
                    ), axis: .vertical).lineLimit(2...4)
                }
            }
            .navigationTitle("Edit Diaper")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        entry.updatedAt = Date()
                        entry.syncStatus = .pending
                        try? modelContext.save()
                        syncManager.enqueue(SyncOperation(
                            modelType: "DiaperEntry", modelID: entry.id, operation: .update, payload: Data()
                        ))
                        HapticManager.success()
                        onSave()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - Duration field helper

struct DurationField: View {
    let label: String
    @Binding var seconds: Double

    private var minutes: Double {
        get { (seconds / 60).rounded() }
    }

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", value: Binding(
                get: { Int(seconds / 60) },
                set: { seconds = Double($0) * 60 }
            ), format: .number)
            .multilineTextAlignment(.trailing)
            .keyboardType(.numberPad)
            .frame(width: 50)
            Text("min").foregroundStyle(.secondary)
        }
    }
}
