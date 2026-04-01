import SwiftUI

struct QuickLogFAB: View {
    @Binding var sheet: HomeSheet?
    @State private var isExpanded = false

    private let actions: [(label: String, icon: String, color: Color, sheet: HomeSheet)] = [
        ("Feed",   "drop.fill",          .blue,   .feed),
        ("Sleep",  "moon.fill",          .indigo, .sleep),
        ("Diaper", "drop.triangle.fill", .orange, .diaper),
        ("More",   "ellipsis",           .gray,   .other),
    ]

    var body: some View {
        VStack(alignment: .trailing, spacing: 12) {
            if isExpanded {
                ForEach(actions.reversed(), id: \.label) { action in
                    HStack(spacing: 10) {
                        Text(action.label)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.regularMaterial, in: Capsule())
                            .shadow(radius: 2)

                        Button {
                            sheet = action.sheet
                            withAnimation(.spring(response: 0.3)) { isExpanded = false }
                        } label: {
                            Image(systemName: action.icon)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 48, height: 48)
                                .background(action.color, in: Circle())
                                .shadow(color: action.color.opacity(0.4), radius: 6, y: 3)
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
                }
            }

            // Main FAB
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            } label: {
                Image(systemName: isExpanded ? "xmark" : "plus")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .background(
                        Circle()
                            .fill(isExpanded ? Color(.systemGray) : Color.accentColor)
                            .shadow(color: Color.accentColor.opacity(isExpanded ? 0 : 0.4), radius: 8, y: 4)
                    )
                    .rotationEffect(.degrees(isExpanded ? 45 : 0))
            }
        }
        // Dismiss on tap outside
        .background(
            Group {
                if isExpanded {
                    Color.clear
                        .contentShape(Rectangle())
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3)) { isExpanded = false }
                        }
                }
            }
        )
    }
}
