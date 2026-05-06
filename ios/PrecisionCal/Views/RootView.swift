import SwiftUI
import SwiftData

struct RootView: View {
    @AppStorage("hasOnboarded") private var hasOnboarded: Bool = false
    @Query private var profiles: [UserProfile]

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
        .onAppear { syncFlag() }
        .onChange(of: profiles.count) { _, _ in syncFlag() }
    }

    private func syncFlag() {
        // Self-heal: if a profile exists but the flag was lost, restore it
        // so the user is never sent back through onboarding.
        if profiles.first != nil, !hasOnboarded {
            hasOnboarded = true
        }
    }
}
