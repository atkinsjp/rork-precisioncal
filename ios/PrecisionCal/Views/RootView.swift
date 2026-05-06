import SwiftUI
import SwiftData

struct RootView: View {
    @AppStorage("hasOnboarded") private var hasOnboarded: Bool = false
    @AppStorage("hasSeenInitialPaywall") private var hasSeenInitialPaywall: Bool = false
    @Environment(StoreViewModel.self) private var store
    @Query private var profiles: [UserProfile]
    @State private var showPaywall: Bool = false

    private var isOnboarded: Bool {
        hasOnboarded || profiles.first != nil
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
        .onAppear {
            syncFlag()
            maybePresentPaywall()
        }
        .onChange(of: profiles.count) { _, _ in
            syncFlag()
            maybePresentPaywall()
        }
        .onChange(of: isOnboarded) { _, _ in maybePresentPaywall() }
        .onChange(of: store.isPremium) { _, premium in
            if premium { showPaywall = false }
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView(store: store)
                .onDisappear { hasSeenInitialPaywall = true }
        }
    }

    private func maybePresentPaywall() {
        guard isOnboarded, !hasSeenInitialPaywall, !store.isPremium else { return }
        // Delay slightly so the tab transition feels intentional
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            if isOnboarded, !hasSeenInitialPaywall, !store.isPremium {
                showPaywall = true
            }
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
