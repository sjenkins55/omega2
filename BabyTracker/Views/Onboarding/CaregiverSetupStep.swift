import SwiftUI

struct CaregiverSetupStep: View {
    @Binding var name: String
    let onBack: () -> Void
    let onNext: () -> Void

    @FocusState private var focused: Bool

    private let suggestions = ["Mom", "Dad", "Nana", "Papa", "Guardian"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Who are you?")
                        .font(.title.bold())
                    Text("This is how your entries will be labeled.")
                        .foregroundStyle(.secondary)
                }

                // Name field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your name or role")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    TextField("e.g. Mom, Dad, Nana…", text: $name)
                        .focused($focused)
                        .font(.title3)
                        .padding(14)
                        .background(Color(.secondarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: 12))
                }

                // Quick-pick chips
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quick pick")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    FlowLayout(spacing: 8) {
                        ForEach(suggestions, id: \.self) { s in
                            Button(s) {
                                name = s
                                focused = false
                            }
                            .buttonStyle(.bordered)
                            .tint(name == s ? .accentColor : .secondary)
                        }
                    }
                }

                // Account callout
                accountCallout
            }
            .padding(24)
        }

        navButtons(
            canContinue: !name.trimmingCharacters(in: .whitespaces).isEmpty,
            onBack: onBack, onNext: onNext
        )
        .onAppear { focused = true }
    }

    private var accountCallout: some View {
        HStack(spacing: 12) {
            Image(systemName: "icloud.fill")
                .foregroundStyle(.blue)
                .font(.title2)
            VStack(alignment: .leading, spacing: 3) {
                Text("Sync across devices")
                    .font(.subheadline.weight(.semibold))
                Text("Sign in with Apple after setup to sync with your partner and other caregivers.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.blue.opacity(0.2), lineWidth: 1))
    }
}

// MARK: - Simple flow layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var height: CGFloat = 0
        var x: CGFloat = 0
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                height += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        height += rowHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
