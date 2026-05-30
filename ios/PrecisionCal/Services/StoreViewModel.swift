import Foundation
import Observation
import RevenueCat

@Observable
@MainActor
final class StoreViewModel {
    static let entitlementID = "PrecisionCal Pro"
    private static let ownerOverrideKey = "ownerModeUnlocked"
    private static let trialStartKey = "trialStartDate"

    /// Length of the free trial in which the full app is unlocked without a
    /// subscription. After it elapses, the mandatory paywall is enforced.
    static let trialLengthDays = 3

    var offerings: Offerings?
    var isEntitled: Bool = false
    var ownerOverride: Bool = UserDefaults.standard.bool(forKey: StoreViewModel.ownerOverrideKey)
    var isLoading: Bool = false
    var isPurchasing: Bool = false
    var error: String?

    /// Timestamp when the free trial began (set the first time the user reaches
    /// the app after onboarding). Nil until the trial has started.
    var trialStartDate: Date? = {
        let stored = UserDefaults.standard.double(forKey: StoreViewModel.trialStartKey)
        return stored > 0 ? Date(timeIntervalSince1970: stored) : nil
    }()

    /// True once the initial subscription status has been resolved, so the UI
    /// can avoid flashing the mandatory paywall for users who are already
    /// subscribed on a cold launch.
    var hasResolvedStatus: Bool = false

    /// Effective premium status — true if the user has the entitlement OR the
    /// owner/tester override is enabled. The override is intended only for the
    /// app owner during testing and review. This reflects an *actual paid*
    /// subscription (it is NOT true merely because the trial is active).
    var isPremium: Bool { isEntitled || ownerOverride }

    /// The moment the trial expires, if a trial has been started.
    var trialEndDate: Date? {
        guard let start = trialStartDate else { return nil }
        return Calendar.current.date(byAdding: .day, value: Self.trialLengthDays, to: start)
    }

    /// True while the free trial is still running.
    var isInTrial: Bool {
        guard let end = trialEndDate else { return false }
        return Date() < end
    }

    /// Whole days remaining in the trial (0 once expired).
    var trialDaysRemaining: Int {
        guard let end = trialEndDate else { return 0 }
        let seconds = end.timeIntervalSinceNow
        guard seconds > 0 else { return 0 }
        return max(1, Int(ceil(seconds / 86_400)))
    }

    /// Whether the user may use the app's features right now: an active paid
    /// subscription, the owner override, OR an unexpired free trial. Once the
    /// trial ends without a subscription this becomes false and the mandatory
    /// paywall takes over the entire app.
    var hasAccess: Bool { isPremium || isInTrial }

    /// Begins the free trial if it hasn't started yet. Safe to call repeatedly.
    func startTrialIfNeeded() {
        guard trialStartDate == nil else { return }
        let now = Date()
        trialStartDate = now
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: Self.trialStartKey)
    }

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
