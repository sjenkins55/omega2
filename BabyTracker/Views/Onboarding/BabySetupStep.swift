import SwiftUI
import PhotosUI

struct BabySetupStep: View {
    @Binding var name: String
    @Binding var dob: Date
    @Binding var sex: BabySex
    @Binding var photoItem: PhotosPickerItem?
    @Binding var photoData: Data?
    @Binding var isDueDate: Bool
    let onBack: () -> Void
    let onNext: () -> Void

    @State private var showDatePicker = false
    @FocusState private var nameFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header

                // Photo picker
                photoPicker
                    .frame(maxWidth: .infinity)

                // Name
                VStack(alignment: .leading, spacing: 8) {
                    label("Baby's name")
                    TextField("e.g. Emma", text: $name)
                        .focused($nameFocused)
                        .font(.title3)
                        .padding(14)
                        .background(Color(.secondarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: 12))
                }

                // Sex
                VStack(alignment: .leading, spacing: 8) {
                    label("Sex")
                    HStack(spacing: 10) {
                        ForEach(BabySex.allCases, id: \.self) { s in
                            SexChip(sex: s, isSelected: sex == s) { sex = s }
                        }
                    }
                }

                // Date
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(isOn: $isDueDate) {
                        label("Due date (not born yet)")
                    }
                    .tint(.accentColor)

                    DatePicker(isDueDate ? "Due date" : "Date of birth",
                               selection: $dob,
                               in: ...Date(),
                               displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .padding(14)
                        .background(Color(.secondarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(24)
        }

        navButtons(
            canContinue: !name.trimmingCharacters(in: .whitespaces).isEmpty,
            onBack: onBack, onNext: onNext
        )
        .onChange(of: photoItem) { loadPhoto() }
        .onAppear { nameFocused = true }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Add your baby")
                .font(.title.bold())
            Text("You can always edit this later.")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Photo picker

    private var photoPicker: some View {
        PhotosPicker(selection: $photoItem, matching: .images) {
            ZStack {
                if let data = photoData, let ui = UIImage(data: data) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color(.secondarySystemGroupedBackground))
                        .frame(width: 100, height: 100)
                        .overlay(
                            VStack(spacing: 4) {
                                Image(systemName: "camera.fill")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                                Text("Add photo")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        )
                }
            }
            .overlay(
                Circle()
                    .strokeBorder(Color(.separator), lineWidth: 1)
            )
        }
    }

    // MARK: - Helpers

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
    }

    private func loadPhoto() {
        Task {
            if let data = try? await photoItem?.loadTransferable(type: Data.self) {
                await MainActor.run { photoData = data }
            }
        }
    }
}

private struct SexChip: View {
    let sex: BabySex
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(label)
            }
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule().fill(isSelected ? chipColor.opacity(0.15) : Color(.secondarySystemGroupedBackground))
            )
            .overlay(Capsule().strokeBorder(isSelected ? chipColor : .clear, lineWidth: 1.5))
            .foregroundStyle(isSelected ? chipColor : .primary)
        }
        .buttonStyle(.plain)
    }

    private var icon: String {
        switch sex {
        case .male: return "mars.circle.fill"
        case .female: return "venus.circle.fill"
        case .unspecified: return "circle.fill"
        }
    }
    private var label: String {
        switch sex {
        case .male: return "Boy"
        case .female: return "Girl"
        case .unspecified: return "Prefer not to say"
        }
    }
    private var chipColor: Color {
        switch sex {
        case .male: return .blue
        case .female: return .pink
        case .unspecified: return .purple
        }
    }
}

// MARK: - Shared nav button row

func navButtons(canContinue: Bool, onBack: () -> Void, onNext: () -> Void) -> some View {
    HStack(spacing: 12) {
        Button(action: onBack) {
            Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 52, height: 52)
                .background(Color(.secondarySystemGroupedBackground), in: Circle())
        }
        .buttonStyle(.plain)

        Button(action: onNext) {
            Text("Continue")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(canContinue ? Color.accentColor : Color(.systemFill))
                )
        }
        .buttonStyle(.plain)
        .disabled(!canContinue)
    }
    .padding(.horizontal, 24)
    .padding(.bottom, 32)
    .padding(.top, 8)
    .background(Color(.systemGroupedBackground))
}
