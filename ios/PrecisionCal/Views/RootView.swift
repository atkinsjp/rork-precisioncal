import SwiftUI
import SwiftData

struct RootView: View {
    @AppStorage("hasOnboarded") private var hasOnboarded: Bool = false
    @AppStorage(OnboardingFunnelStage.storageKey) private var stageRaw: String = ""
    @Environment(StoreViewModel.self) private var store
    @Query private var profiles: [UserProfile]

    /// Resolve the current funnel stage. Users who onboarded before the value-first
    /// funnel existed have no stored stage — migrate them straight to `.done` so
    /// they're never bounced back into the funnel.
    private var stage: OnboardingFunnelStage {
        if let s = OnboardingFunnelStage(rawValue: stageRaw), !stageRaw.isEmpty {
            return s
        }
        return (hasOnboarded || profiles.first != nil) ? .done : .questionnaire
    }

    /// The blanket paywall only gates returning users (funnel already complete)
    /// whose subscription has lapsed. First-time users meet the paywall inside the
    /// funnel, right after their first 6-pass analysis. The owner override bypasses it.
    private var mustShowPaywall: Bool {
        stage == .done && store.hasResolvedStatus && !store.hasAccess
    }

    var body: some View {
        ZStack {
            MeshBackground()
            switch stage {
            case .questionnaire:
                OnboardingFlow()
                    .transition(.opacity)
            case .done:
                MainTabView()
                    .transition(.opacity)
            default:
                FirstScanFunnelView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: stage)
        .onAppear(perform: syncFlag)
        .onChange(of: profiles.count) { _, _ in syncFlag() }
        .fullScreenCover(isPresented: .constant(mustShowPaywall)) {
            PaywallView(store: store, isMandatory: true)
                .interactiveDismissDisabled(true)
        }
    }

    private func syncFlag() {
        // Self-heal: if a profile exists but the flag was lost, restore it.
        if profiles.first != nil, !hasOnboarded {
            hasOnboarded = true
        }
    }
}
