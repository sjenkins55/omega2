import Foundation
import Observation

/// Manages subscription state and premium feature access via RevenueCat.
///
/// SPM setup: https://github.com/RevenueCat/purchases-ios
/// After adding the package:
///   1. Import RevenueCat at the top of this file
///   2. Uncomment the SDK calls below
///   3. Replace REVENUECAT_API_KEY in Config.xcconfig

// import RevenueCat  ← uncomment after adding SPM package

@MainActor
@Observable
final class SubscriptionService {

    // MARK: - State

    private(set) var tier: SubscriptionTier = .free
    private(set) var isLoading = false
    private(set) var offerings: [SubscriptionOffering] = SubscriptionOffering.defaultOfferings

    // MARK: - Init

    init() {
        Task { await configure() }
    }

    // MARK: - Configure RevenueCat

    private func configure() async {
        // Purchases.configure(withAPIKey: SubscriptionConfig.revenueCatKey)
        // Purchases.shared.delegate = self (if using delegate pattern)
        await fetchCustomerInfo()
    }

    // MARK: - Fetch current entitlements

    func fetchCustomerInfo() async {
        isLoading = true
        defer { isLoading = false }

        // RevenueCat SDK call:
        // do {
        //     let info = try await Purchases.shared.customerInfo()
        //     tier = info.entitlements["premium"]?.isActive == true ? .premium : .free
        // } catch {
        //     print("[Sub] Failed to fetch customer info: \(error)")
        // }

        // Stub: check local cache
        tier = UserDefaults.standard.bool(forKey: "isPremium") ? .premium : .free
    }

    // MARK: - Purchase

    func purchase(_ offering: SubscriptionOffering) async throws {
        isLoading = true
        defer { isLoading = false }

        // RevenueCat SDK call:
        // guard let package = try await Purchases.shared.offerings().current?.availablePackages
        //     .first(where: { $0.identifier == offering.packageID }) else { return }
        // let result = try await Purchases.shared.purchase(package: package)
        // tier = result.customerInfo.entitlements["premium"]?.isActive == true ? .premium : .free

        // Stub for testing:
        try await Task.sleep(nanoseconds: 1_000_000_000)
        tier = .premium
        UserDefaults.standard.set(true, forKey: "isPremium")
    }

    // MARK: - Restore

    func restorePurchases() async throws {
        isLoading = true
        defer { isLoading = false }

        // RevenueCat: let info = try await Purchases.shared.restorePurchases()
        // tier = info.entitlements["premium"]?.isActive == true ? .premium : .free
        await fetchCustomerInfo()
    }

    // MARK: - Permission checks

    func canAddBaby(currentCount: Int) -> Bool {
        tier == .premium || currentCount < 1
    }

    func canAddCaregiver(currentCount: Int) -> Bool {
        tier == .premium || currentCount < 1
    }

    var canViewFullInsights: Bool { tier == .premium }
    var canExportData: Bool { tier == .premium }
    var canUseWidgets: Bool { tier == .premium }
    var canUseWatchApp: Bool { tier == .premium }
}

// MARK: - Tier

enum SubscriptionTier {
    case free, premium

    var displayName: String { self == .premium ? "Premium" : "Free" }
    var isPremium: Bool { self == .premium }
}

// MARK: - Offerings

struct SubscriptionOffering: Identifiable {
    let id: String
    let packageID: String
    let title: String
    let price: String
    let period: String
    let savingsLabel: String?
    let isPopular: Bool

    static let defaultOfferings: [SubscriptionOffering] = [
        SubscriptionOffering(
            id: "monthly",
            packageID: "$rc_monthly",
            title: "Monthly",
            price: "$4.99",
            period: "per month",
            savingsLabel: nil,
            isPopular: false
        ),
        SubscriptionOffering(
            id: "annual",
            packageID: "$rc_annual",
            title: "Annual",
            price: "$34.99",
            period: "per year",
            savingsLabel: "Save 42%",
            isPopular: true
        ),
    ]
}

// MARK: - Config

enum SubscriptionConfig {
    static var revenueCatKey: String {
        Bundle.main.object(forInfoDictionaryKey: "REVENUECAT_API_KEY") as? String ?? ""
    }
}
