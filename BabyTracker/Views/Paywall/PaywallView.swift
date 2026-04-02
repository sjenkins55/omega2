import SwiftUI

/// Presented whenever a user tries to use a premium feature on the free tier.
/// Pass a `trigger` to show context-specific copy ("Unlock multiple babies", etc.)
struct PaywallView: View {

    var trigger: PaywallTrigger = .generic
    var onDismiss: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(SubscriptionService.self) private var sub

    @State private var selectedOfferingID = "annual"
    @State private var isPurchasing = false
    @State private var errorMessage: String? = nil
    @State private var showRestoreConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    heroSection
                    featuresSection
                    pricingSection
                    footerSection
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") {
                        onDismiss?()
                        dismiss()
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .overlay {
                if isPurchasing {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    ProgressView("Processing…")
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
        .presentationDetents([.large])
        .alert("Something went wrong", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.indigo.opacity(0.2), .purple.opacity(0.15)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 100, height: 100)
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom)
                    )
            }
            .padding(.top, 8)

            VStack(spacing: 8) {
                Text("Baby Tracker Premium")
                    .font(.title2.bold())
                Text(trigger.headline)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .padding(.bottom, 24)
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(spacing: 10) {
            ForEach(PremiumFeature.allCases, id: \.self) { feature in
                HStack(spacing: 14) {
                    Image(systemName: feature.icon)
                        .foregroundStyle(feature.color)
                        .font(.system(size: 20))
                        .frame(width: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(feature.title)
                            .font(.subheadline.weight(.semibold))
                        Text(feature.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.system(size: 18))
                }
                .padding(.horizontal, 24)
            }
        }
        .padding(.bottom, 28)
    }

    // MARK: - Pricing

    private var pricingSection: some View {
        VStack(spacing: 12) {
            ForEach(sub.offerings) { offering in
                OfferingRow(
                    offering: offering,
                    isSelected: selectedOfferingID == offering.id
                ) {
                    selectedOfferingID = offering.id
                }
            }
            .padding(.horizontal, 20)

            // Purchase CTA
            Button {
                purchase()
            } label: {
                Text(ctaLabel)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(colors: [.indigo, .purple],
                                       startPoint: .leading, endPoint: .trailing),
                        in: RoundedRectangle(cornerRadius: 16)
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.top, 4)

            Text("Cancel anytime. Prices in USD.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.bottom, 16)
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack(spacing: 20) {
            Button("Restore") {
                Task { try? await sub.restorePurchases()
                    showRestoreConfirmation = true }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Text("·").foregroundStyle(.secondary)

            Link("Privacy Policy", destination: URL(string: "https://yourapp.com/privacy")!)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("·").foregroundStyle(.secondary)

            Link("Terms", destination: URL(string: "https://yourapp.com/terms")!)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 32)
        .alert("Purchases restored", isPresented: $showRestoreConfirmation) {
            Button("OK") {}
        }
    }

    // MARK: - Purchase

    private func purchase() {
        guard let offering = sub.offerings.first(where: { $0.id == selectedOfferingID }) else { return }
        isPurchasing = true
        Task {
            do {
                try await sub.purchase(offering)
                isPurchasing = false
                onDismiss?()
                dismiss()
            } catch {
                isPurchasing = false
                errorMessage = error.localizedDescription
            }
        }
    }

    private var ctaLabel: String {
        guard let offering = sub.offerings.first(where: { $0.id == selectedOfferingID }) else {
            return "Subscribe"
        }
        return "Start Premium — \(offering.price)/\(offering.period == "per month" ? "mo" : "yr")"
    }
}

// MARK: - Offering Row

private struct OfferingRow: View {
    let offering: SubscriptionOffering
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .accentColor : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(offering.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(offering.period)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(offering.price)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                    if let savings = offering.savingsLabel {
                        Text(savings)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green, in: Capsule())
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor.opacity(0.08)
                          : Color(.secondarySystemGroupedBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(isSelected ? Color.accentColor.opacity(0.4) : .clear,
                                          lineWidth: 1.5)
                    )
            )
            .overlay(alignment: .topTrailing) {
                if offering.isPopular {
                    Text("Most Popular")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.accentColor, in: Capsule())
                        .offset(x: -8, y: -10)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Feature list

enum PremiumFeature: CaseIterable {
    case multipleBabies, multipleCaregiver, fullInsights, export, widgets, watchApp

    var title: String {
        switch self {
        case .multipleBabies:    return "Unlimited babies"
        case .multipleCaregiver: return "Up to 6 caregivers"
        case .fullInsights:      return "Full history & trends"
        case .export:            return "Export CSV & PDF reports"
        case .widgets:           return "Home screen & Lock Screen widgets"
        case .watchApp:          return "Apple Watch companion"
        }
    }
    var detail: String {
        switch self {
        case .multipleBabies:    return "Track twins, siblings, and more"
        case .multipleCaregiver: return "Real-time sync with your whole care team"
        case .fullInsights:      return "90-day trends, charts, and correlations"
        case .export:            return "Share reports with your pediatrician"
        case .widgets:           return "See last feed and diaper without opening the app"
        case .watchApp:          return "Quick log right from your wrist"
        }
    }
    var icon: String {
        switch self {
        case .multipleBabies:    return "person.3.fill"
        case .multipleCaregiver: return "person.2.circle.fill"
        case .fullInsights:      return "chart.line.uptrend.xyaxis"
        case .export:            return "square.and.arrow.up.fill"
        case .widgets:           return "apps.iphone"
        case .watchApp:          return "applewatch"
        }
    }
    var color: Color {
        switch self {
        case .multipleBabies:    return .pink
        case .multipleCaregiver: return .purple
        case .fullInsights:      return .blue
        case .export:            return .green
        case .widgets:           return .indigo
        case .watchApp:          return .orange
        }
    }
}

// MARK: - Trigger context

enum PaywallTrigger {
    case generic, addBaby, addCaregiver, insights, export, widgets

    var headline: String {
        switch self {
        case .generic:        return "Unlock everything Baby Tracker has to offer."
        case .addBaby:        return "Upgrade to track multiple babies and siblings."
        case .addCaregiver:   return "Upgrade to share with your partner and care team."
        case .insights:       return "Upgrade to see full history and trend charts."
        case .export:         return "Upgrade to export reports for your pediatrician."
        case .widgets:        return "Upgrade to add Baby Tracker to your Home Screen."
        }
    }
}

// MARK: - Premium gate modifier

struct PremiumGate: ViewModifier {
    let trigger: PaywallTrigger
    let isAllowed: Bool
    @State private var showPaywall = false

    func body(content: Content) -> some View {
        content
            .disabled(!isAllowed)
            .overlay {
                if !isAllowed {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { showPaywall = true }
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(trigger: trigger)
            }
    }
}

extension View {
    func premiumGated(_ trigger: PaywallTrigger, isAllowed: Bool) -> some View {
        modifier(PremiumGate(trigger: trigger, isAllowed: isAllowed))
    }
}
