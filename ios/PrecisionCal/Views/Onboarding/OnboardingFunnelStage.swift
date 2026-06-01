import Foundation

/// The value-first entry funnel. After the questionnaire + protocol preview, the
/// user runs a mandatory first 6-pass scan, hits the paywall right after Pass 6
/// (before the breakdown renders), locks in their account with Sign in with Apple,
/// and finally has their results revealed. The stage is persisted so a force-close
/// always returns the user to exactly where they left off.
enum OnboardingFunnelStage: String {
    /// Disclaimer → vision → calibration → … → protocol note.
    case questionnaire
    /// Mandatory first-time camera/photo scan interface.
    case firstScan
    /// Live 6-pass `analyzeChain` execution the user watches resolve.
    case analyzing
    /// Paywall presented exactly after Pass 6, before results render.
    case paywall
    /// Sign in with Apple to lock in the (otherwise anonymous) account.
    case signin
    /// Reveal the full Nutritional Autopsy results.
    case reveal
    /// Funnel complete — the main app is unlocked.
    case done

    /// AppStorage key shared across the funnel views.
    static let storageKey = "onboardingFunnelStage"
}
