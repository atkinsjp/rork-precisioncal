import AuthenticationServices
import Foundation
import Observation
import RevenueCat

/// Verifies the device is signed in with the app owner's Apple ID via
/// Sign in with Apple. On first verification we capture the email from the
/// Apple credential (Apple only returns it on first auth) and persist the
/// stable Apple user identifier. On every launch we silently call
/// `getCredentialState` against that identifier — if Apple still reports it
/// as `.authorized`, we keep owner mode unlocked automatically.
///
/// Sign-in is driven by SwiftUI's `SignInWithAppleButton` (same as the
/// onboarding funnel) — a manual `ASAuthorizationController` presentation
/// proved unreliable on TestFlight builds (AuthorizationError 1000).
@MainActor
@Observable
final class OwnerAuthService: NSObject {
    /// Owner email allow-list. Only Apple IDs whose primary email matches
    /// are auto-promoted to owner status on first sign-in.
    static let ownerEmails: Set<String> = [
        "atkinsdigitalbiz@gmail.com"
    ]

    /// Shared keys — the onboarding funnel (FirstScanFunnelView) writes the
    /// same keys, so both sign-in paths produce one session that sign-out
    /// fully clears.
    private static let appleUserIDKey = "appleUserID"
    private static let appleUserEmailKey = "appleUserEmail"

    var lastError: String?

    private let store: StoreViewModel

    init(store: StoreViewModel) {
        self.store = store
        super.init()
    }

    /// Clear the saved Apple ID session and disable owner override.
    func signOut() {
        UserDefaults.standard.removeObject(forKey: Self.appleUserIDKey)
        UserDefaults.standard.removeObject(forKey: Self.appleUserEmailKey)
        store.setOwnerOverride(false)
        lastError = nil
        // Detach the RevenueCat identity that was linked at sign-in so the
        // session truly ends on this device.
        Task { _ = try? await Purchases.shared.logOut() }
    }

    var savedAppleUserID: String? {
        UserDefaults.standard.string(forKey: Self.appleUserIDKey)
    }

    var savedAppleUserEmail: String? {
        UserDefaults.standard.string(forKey: Self.appleUserEmailKey)
    }

    /// Silently verify the saved Apple ID is still authorized on this device.
    /// If it is, keep owner override on. If it has been revoked, turn it off
    /// (unless the user manually toggled it). Safe to call on every launch.
    func refreshSilently() async {
        guard let userID = savedAppleUserID else { return }
        let provider = ASAuthorizationAppleIDProvider()
        do {
            let state = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<ASAuthorizationAppleIDProvider.CredentialState, Error>) in
                provider.getCredentialState(forUserID: userID) { state, error in
                    if let error { cont.resume(throwing: error) } else { cont.resume(returning: state) }
                }
            }
            switch state {
            case .authorized:
                if !store.ownerOverride { store.setOwnerOverride(true) }
            case .revoked, .notFound:
                UserDefaults.standard.removeObject(forKey: Self.appleUserIDKey)
                UserDefaults.standard.removeObject(forKey: Self.appleUserEmailKey)
            default:
                break
            }
        } catch {
            // Network/transient — leave existing state untouched.
        }
    }

    /// Shared completion handler for `SignInWithAppleButton`. On success, if
    /// the email matches the owner allow-list, owner override is enabled.
    func handleAuthorization(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else {
                lastError = "Unexpected credential type."
                return
            }
            let userID = credential.user
            // Apple returns email only on the very first sign-in. After that we
            // rely on the email saved in UserDefaults from the first auth.
            let returnedEmail = credential.email?.lowercased()
            let stored = savedAppleUserEmail?.lowercased()
            let effectiveEmail = returnedEmail ?? (savedAppleUserID == userID ? stored : nil)

            UserDefaults.standard.set(userID, forKey: Self.appleUserIDKey)
            if let returnedEmail {
                UserDefaults.standard.set(returnedEmail, forKey: Self.appleUserEmailKey)
            }

            if let email = effectiveEmail, Self.ownerEmails.contains(email) {
                store.setOwnerOverride(true)
                lastError = nil
            } else if returnedEmail == nil && stored == nil {
                lastError = "Apple didn't return an email this time. Please remove this app from your Apple ID's signed-in apps (Settings > Apple ID > Sign in with Apple) and try again."
            } else {
                lastError = "This Apple ID isn't on the owner list."
            }

        case .failure(let error):
            let nsError = error as NSError
            guard nsError.code != ASAuthorizationError.canceled.rawValue else { return }
            if nsError.code == ASAuthorizationError.unknown.rawValue {
                lastError = "Apple sign-in couldn't start. Make sure you're signed in to iCloud (Settings > your name > iCloud) and try again."
            } else {
                lastError = error.localizedDescription
            }
        }
    }
}
