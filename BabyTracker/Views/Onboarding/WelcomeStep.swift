import SwiftUI

struct WelcomeStep: View {
    let onNext: () -> Void
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Hero
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(colors: [.indigo.opacity(0.2), .purple.opacity(0.15)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 140, height: 140)
                    Text("🌙")
                        .font(.system(size: 64))
                }
                .scaleEffect(appeared ? 1 : 0.6)
                .opacity(appeared ? 1 : 0)

                VStack(spacing: 10) {
                    Text("Baby Tracker")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text("Track every feed, sleep, and milestone.\nBuilt for the whole family.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)
            }

            Spacer()

            // Feature highlights
            VStack(spacing: 12) {
                FeatureRow(icon: "drop.fill",          color: .blue,   text: "Feed, sleep, and diaper logging")
                FeatureRow(icon: "chart.line.uptrend.xyaxis", color: .green, text: "Insights and growth charts")
                FeatureRow(icon: "person.2.fill",      color: .purple, text: "Share with your whole care team")
                FeatureRow(icon: "wifi.slash",          color: .orange, text: "Works offline — syncs automatically")
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)

            Spacer()

            // CTA
            VStack(spacing: 12) {
                Button(action: onNext) {
                    Text("Get Started")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)

                Text("Free to start — no account required")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                appeared = true
            }
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.system(size: 18))
                .frame(width: 32)
            Text(text)
                .font(.subheadline)
            Spacer()
        }
        .padding(.horizontal, 32)
    }
}
