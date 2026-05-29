import SwiftUI
import SwiftData

struct RootView: View {
    @AppStorage("hasOnboarded") private var hasOnboarded: Bool = false
    @Environment(StoreViewModel.self) private var store
    @Query private var profiles: [UserProfile]

    private var isOnboarded: Bool {
        hasOnboarded || profiles.first != nil
    }

    /// The paywall is mandatory: once onboarding is complete, the app is
    /// unusable until the user holds an active subscription (the 3-day free
    /// trial is provided by the subscription's introductory offer). The owner
    /// override bypasses this for the app owner during testing/review.
    private var mustShowPaywall: Bool {
        isOnboarded && store.hasResolvedStatus && !store.isPremium
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
    }
}
