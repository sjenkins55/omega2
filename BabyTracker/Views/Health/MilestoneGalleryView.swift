import SwiftUI
import SwiftData
import PhotosUI

struct MilestoneGalleryView: View {

    let baby: Baby

    @Environment(\.modelContext) private var modelContext
    @Query private var allMilestones: [MilestoneEntry]
    @State private var showAdd = false
    @State private var viewMode: ViewMode = .gallery
    @State private var selectedMilestone: MilestoneEntry? = nil

    enum ViewMode { case gallery, timeline }

    private var achieved: [MilestoneEntry] {
        allMilestones.filter { $0.babyID == baby.id }.sorted { $0.achievedAt > $1.achievedAt }
    }

    private var achievedKeys: Set<String> { Set(achieved.compactMap(\.milestoneKey)) }

    private var upcoming: [MilestoneDefinition] {
        MilestoneDefinition.upcoming(for: baby.ageInMonths)
            .filter { !achievedKeys.contains($0.id) }
    }

    var body: some View {
        VStack(spacing: 0) {
            viewModePicker

            if viewMode == .gallery {
                galleryView
            } else {
                timelineView
            }
        }
        .navigationTitle("Milestones")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddMilestoneSheet(baby: baby)
        }
        .sheet(item: $selectedMilestone) { m in
            MilestoneDetailView(milestone: m, baby: baby)
        }
    }

    // MARK: - View mode picker

    private var viewModePicker: some View {
        Picker("View", selection: $viewMode) {
            Label("Gallery", systemImage: "square.grid.2x2.fill").tag(ViewMode.gallery)
            Label("Timeline", systemImage: "timeline.selection").tag(ViewMode.timeline)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Gallery

    private var galleryView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if !upcoming.isEmpty {
                    upcomingSection
                }
                if !achieved.isEmpty {
                    achievedGrid
                } else {
                    ContentUnavailableView(
                        "No milestones yet",
                        systemImage: "star.circle",
                        description: Text("Tap + to record \(baby.name)'s first milestone!")
                    )
                    .padding(.top, 40)
                }
            }
            .padding()
        }
    }

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Coming Up (\(baby.ageInMonths)–\(baby.ageInMonths + 3) months)")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(upcoming) { def in
                        UpcomingMilestoneCard(definition: def) {
                            quickAchieve(def)
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private var achievedGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Achieved (\(achieved.count))")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(achieved) { milestone in
                    MilestoneTile(milestone: milestone) {
                        selectedMilestone = milestone
                    }
                }
            }
        }
    }

    // MARK: - Timeline

    private var timelineView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(achievedByMonth.keys.sorted(by: >), id: \.self) { month in
                    timelineSection(month: month, milestones: achievedByMonth[month]!)
                }
            }
            .padding()
        }
    }

    private func timelineSection(month: Int, milestones: [MilestoneEntry]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Month header
            HStack {
                Circle().fill(Color.accentColor).frame(width: 10, height: 10)
                Text(monthLabel(month))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            // Entries
            VStack(alignment: .leading, spacing: 8) {
                ForEach(milestones) { m in
                    Button { selectedMilestone = m } label: {
                        HStack(spacing: 12) {
                            if let data = m.photoData, let ui = UIImage(data: data) {
                                Image(uiImage: ui)
                                    .resizable().scaledToFill()
                                    .frame(width: 48, height: 48)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.accentColor.opacity(0.12))
                                    .frame(width: 48, height: 48)
                                    .overlay(Image(systemName: "star.fill").foregroundStyle(.accentColor))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(m.displayTitle)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.primary)
                                Text(m.achievedAt, style: .date)
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(10)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.leading, 18)
        }
        .padding(.bottom, 16)
    }

    // MARK: - Helpers

    private var achievedByMonth: [Int: [MilestoneEntry]] {
        var dict: [Int: [MilestoneEntry]] = [:]
        for m in achieved {
            let ref = baby.dueDate ?? baby.dateOfBirth
            let months = max(0, Int(m.achievedAt.timeIntervalSince(ref) / (30.44 * 86400)))
            dict[months, default: []].append(m)
        }
        return dict
    }

    private func monthLabel(_ months: Int) -> String {
        if months < 1 { return "Newborn" }
        if months < 24 { return "\(months) months" }
        return "\(months / 12) years \(months % 12 > 0 ? "\(months % 12)m" : "")"
    }

    private func quickAchieve(_ def: MilestoneDefinition) {
        let entry = MilestoneEntry(babyID: baby.id, caregiverID: UUID(), achievedAt: Date(), milestoneKey: def.id)
        modelContext.insert(entry)
        try? modelContext.save()
    }
}

// MARK: - Upcoming Milestone Card

struct UpcomingMilestoneCard: View {
    let definition: MilestoneDefinition
    let onAchieve: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: definition.category.icon)
                    .foregroundStyle(categoryColor)
                    .font(.system(size: 18))
                Spacer()
                Button(action: onAchieve) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.title3)
                }
            }
            Text(definition.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
            Text("\(definition.ageMonthsMin)–\(definition.ageMonthsMax) mo")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(width: 140)
        .background(categoryColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(categoryColor.opacity(0.2)))
    }

    private var categoryColor: Color {
        switch definition.category {
        case .motor:    return .green
        case .language: return .blue
        case .social:   return .pink
        case .cognitive: return .orange
        }
    }
}

// MARK: - Milestone Tile

struct MilestoneTile: View {
    let milestone: MilestoneEntry
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                if let data = milestone.photoData, let ui = UIImage(data: data) {
                    Image(uiImage: ui)
                        .resizable().scaledToFill()
                        .frame(height: 140)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.1))
                        .frame(height: 140)
                        .overlay(
                            Image(systemName: "star.circle.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(Color.accentColor.opacity(0.5))
                        )
                }

                // Label overlay
                LinearGradient(colors: [.clear, .black.opacity(0.6)],
                               startPoint: .top, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 2) {
                    Text(milestone.displayTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text(milestone.achievedAt, style: .date)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(8)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Milestone Detail View

struct MilestoneDetailView: View {

    let milestone: MilestoneEntry
    let baby: Baby

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let data = milestone.photoData, let ui = UIImage(data: data) {
                        Image(uiImage: ui)
                            .resizable().scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    VStack(spacing: 8) {
                        Text(milestone.displayTitle)
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                        Text("\(baby.name) · \(milestone.achievedAt.formatted(date: .long, time: .omitted))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if let notes = milestone.notes {
                        Text(notes)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                    }

                    // Share button
                    ShareLink(
                        item: milestone.displayTitle,
                        message: Text("\(baby.name) reached a milestone: \(milestone.displayTitle)! 🎉")
                    ) {
                        Label("Share Milestone", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - Add Milestone Sheet

struct AddMilestoneSheet: View {

    let baby: Baby

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var isCustom = false
    @State private var selectedKey: String = MilestoneDefinition.all.first?.id ?? ""
    @State private var customTitle = ""
    @State private var achievedAt = Date()
    @State private var notes = ""
    @State private var photoItem: PhotosPickerItem? = nil
    @State private var photoData: Data? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Custom milestone", isOn: $isCustom)
                    if isCustom {
                        TextField("Milestone title", text: $customTitle)
                    } else {
                        Picker("Milestone", selection: $selectedKey) {
                            ForEach(MilestoneDefinition.all) { def in
                                Text(def.title).tag(def.id)
                            }
                        }
                    }
                    DatePicker("Date achieved", selection: $achievedAt, displayedComponents: .date)
                }

                Section("Photo (optional)") {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        if let data = photoData, let ui = UIImage(data: data) {
                            Image(uiImage: ui).resizable().scaledToFit().frame(height: 120).clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            Label("Add Photo", systemImage: "camera.fill")
                        }
                    }
                }

                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical).lineLimit(2...4)
                }
            }
            .navigationTitle("Add Milestone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(isCustom && customTitle.isEmpty)
                }
            }
        }
        .presentationDetents([.large])
        .onChange(of: photoItem) {
            Task {
                if let data = try? await photoItem?.loadTransferable(type: Data.self) {
                    await MainActor.run { photoData = data }
                }
            }
        }
    }

    private func save() {
        let entry = MilestoneEntry(
            babyID: baby.id, caregiverID: UUID(), achievedAt: achievedAt,
            milestoneKey: isCustom ? nil : selectedKey,
            customTitle: isCustom ? customTitle : nil
        )
        entry.notes = notes.isEmpty ? nil : notes
        entry.photoData = photoData
        modelContext.insert(entry)
        try? modelContext.save()
        dismiss()
    }
}
