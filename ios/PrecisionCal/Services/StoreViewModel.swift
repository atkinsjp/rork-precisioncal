import Foundation
import Observation
import RevenueCat

@Observable
@MainActor
final class StoreViewModel {
    static let entitlementID = "PrecisionCal Pro"
    private static let ownerOverrideKey = "ownerModeUnlocked"

    var offerings: Offerings?
    var isEntitled: Bool = false
    var ownerOverride: Bool = UserDefaults.standard.bool(forKey: StoreViewModel.ownerOverrideKey)
    var isLoading: Bool = false
    var isPurchasing: Bool = false
    var error: String?

    /// True once the initial subscription status has been resolved, so the UI
    /// can avoid flashing the mandatory paywall for users who are already
    /// subscribed on a cold launch.
    var hasResolvedStatus: Bool = false

    /// Effective premium status — true if the user has the entitlement OR the
    /// owner/tester override is enabled. The override is intended only for the
    /// app owner during testing and review.
    var isPremium: Bool { isEntitled || ownerOverride }

    /// Whether the user may use the app's features. The free trial is handled
    /// natively by StoreKit (the App Store introductory offer): the user taps
    /// Subscribe at the mandatory paywall, gets their 3 free days, and is then
    /// charged automatically unless they cancel. Access therefore requires an
    /// active subscription (or the owner/tester override).
    var hasAccess: Bool { isPremium }

    func setOwnerOverride(_ enabled: Bool) {
        ownerOverride = enabled
        UserDefaults.standard.set(enabled, forKey: Self.ownerOverrideKey)
    }

    init() {
        Task { await listenForUpdates() }
        Task { await fetchOfferings() }
        Task { await checkStatus() }
    }

    private func listenForUpdates() async {
        for await info in Purchases.shared.customerInfoStream {
            self.isEntitled = info.entitlements[Self.entitlementID]?.isActive == true
        }
    }

    func fetchOfferings() async {
        isLoading = true
        do {
            offerings = try await Purchases.shared.offerings()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func purchase(package: Package) async {
        isPurchasing = true
        do {
            let result = try await Purchases.shared.purchase(package: package)
            if !result.userCancelled {
                isEntitled = result.customerInfo.entitlements[Self.entitlementID]?.isActive == true
            }
        } catch ErrorCode.purchaseCancelledError {
            // user cancellation — ignore
        } catch ErrorCode.paymentPendingError {
            // awaiting parental approval — ignore
        } catch {
            self.error = error.localizedDescription
        }
        isPurchasing = false
    }

    func restore() async {
        isPurchasing = true
        do {
            let info = try await Purchases.shared.restorePurchases()
            isEntitled = info.entitlements[Self.entitlementID]?.isActive == true
            if !isPremium {
                self.error = "No active subscription found to restore."
            }
        } catch {
            self.error = error.localizedDescription
        }
        isPurchasing = false
    }

    func checkStatus() async {
        do {
            let info = try await Purchases.shared.customerInfo()
            isEntitled = info.entitlements[Self.entitlementID]?.isActive == true
        } catch {
            self.error = error.localizedDescription
        }
        hasResolvedStatus = true
    }
}
