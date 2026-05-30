import SwiftUI
import SwiftData

struct RootView: View {
    @AppStorage("hasOnboarded") private var hasOnboarded: Bool = false
    @Environment(StoreViewModel.self) private var store
    @Query private var profiles: [UserProfile]

    private var isOnboarded: Bool {
        hasOnboarded || profiles.first != nil
    }

    /// The paywall is mandatory: every feature is unlocked during the 3-day
    /// free trial, but once the trial elapses the app is unusable until the
    /// user holds an active subscription. The owner override bypasses this for
    /// the app owner during testing/review.
    private var mustShowPaywall: Bool {
        isOnboarded && store.hasResolvedStatus && !store.hasAccess
    }

    var body: some View {
        ZStack {
            MeshBackground()
            if isOnboarded {
                MainTabView()
                    .transition(.opacity)
            } else {
                OnboardingFlow()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: isOnboarded)
        .onAppear(perform: syncFlag)
        .onChange(of: profiles.count) { _, _ in syncFlag() }
        .onChange(of: isOnboarded) { _, onboarded in
            if onboarded { store.startTrialIfNeeded() }
        }
        .fullScreenCover(isPresented: .constant(mustShowPaywall)) {
            PaywallView(store: store, isMandatory: true)
                .interactiveDismissDisabled(true)
        }
    }

    private func syncFlag() {
        // Self-heal: if a profile exists but the flag was lost, restore it
        // so the user is never sent back through onboarding.
        if profiles.first != nil, !hasOnboarded {
            hasOnboarded = true
        }
        // The free trial clock starts the moment the user finishes onboarding
        // and reaches the app for the first time.
        if isOnboarded {
            store.startTrialIfNeeded()
        }
    }
}
