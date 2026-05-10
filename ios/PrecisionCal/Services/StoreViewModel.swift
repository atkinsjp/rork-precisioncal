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

    /// Effective premium status — true if the user has the entitlement OR the
    /// owner/tester override is enabled. The override is intended only for the
    /// app owner during testing and review.
    var isPremium: Bool { isEntitled || ownerOverride }

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
    }
}
