import AuthenticationServices
import Foundation
import Observation
import UIKit

/// Verifies the device is signed in with the app owner's Apple ID via
/// Sign in with Apple. On first verification we capture the email from the
/// Apple credential (Apple only returns it on first auth) and persist the
/// stable Apple user identifier. On every launch we silently call
/// `getCredentialState` against that identifier — if Apple still reports it
/// as `.authorized`, we keep owner mode unlocked automatically.
@MainActor
@Observable
final class OwnerAuthService: NSObject {
    /// Owner email allow-list. Only Apple IDs whose primary email matches
    /// are auto-promoted to owner status on first sign-in.
    static let ownerEmails: Set<String> = [
        "atkinsdigitalbiz@gmail.com"
    ]

    private static let appleUserIDKey = "ownerAppleUserID"
    private static let appleUserEmailKey = "ownerAppleUserEmail"

    var isVerifying: Bool = false
    var lastError: String?

    private let store: StoreViewModel
    private var continuation: CheckedContinuation<Void, Error>?

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

    /// Begin the Sign in with Apple flow. On success, if the email matches the
    /// owner allow-list, owner override is enabled automatically.
    func verifyOwner() async {
        guard !isVerifying else { return }
        isVerifying = true
        lastError = nil
        defer { isVerifying = false }

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.email, .fullName]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self

        do {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                self.continuation = cont
                controller.performRequests()
            }
        } catch {
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                lastError = error.localizedDescription
            }
        }
    }
}

extension OwnerAuthService: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(controller: ASAuthorizationController,
                                             didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            Task { @MainActor in
                self.lastError = "Unexpected credential type."
                self.continuation?.resume()
                self.continuation = nil
            }
            return
        }
        let userID = credential.user
        // Apple returns email only on the very first sign-in. After that we
        // rely on the email saved in UserDefaults from the first auth.
        let returnedEmail = credential.email?.lowercased()

        Task { @MainActor in
            let stored = self.savedAppleUserEmail?.lowercased()
            let effectiveEmail = returnedEmail ?? (self.savedAppleUserID == userID ? stored : nil)

            UserDefaults.standard.set(userID, forKey: Self.appleUserIDKey)
            if let returnedEmail {
                UserDefaults.standard.set(returnedEmail, forKey: Self.appleUserEmailKey)
            }

            if let email = effectiveEmail, Self.ownerEmails.contains(email) {
                self.store.setOwnerOverride(true)
                self.lastError = nil
            } else if returnedEmail == nil && stored == nil {
                self.lastError = "Apple didn't return an email this time. Please remove this app from your Apple ID's signed-in apps (Settings > Apple ID > Sign in with Apple) and try again."
            } else {
                self.lastError = "This Apple ID isn't on the owner list."
            }

            self.continuation?.resume()
            self.continuation = nil
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController,
                                             didCompleteWithError error: Error) {
        Task { @MainActor in
            self.continuation?.resume(throwing: error)
            self.continuation = nil
        }
    }
}

extension OwnerAuthService: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow } ?? ASPresentationAnchor()
        }
    }
}
