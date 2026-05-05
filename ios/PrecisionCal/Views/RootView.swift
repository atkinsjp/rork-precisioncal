import SwiftUI
import SwiftData

struct RootView: View {
    @AppStorage("hasOnboarded") private var hasOnboarded: Bool = false
    @Query private var profiles: [UserProfile]

    var body: some View {
        ZStack {
            MeshBackground()
            if hasOnboarded, profiles.first != nil {
                MainTabView()
                    .transition(.opacity)
            } else {
                OnboardingFlow()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: hasOnboarded)
    }
}
