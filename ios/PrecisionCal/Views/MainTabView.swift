import SwiftUI

struct MainTabView: View {
    @State private var selection: Int = 0

    var body: some View {
        TabView(selection: $selection) {
            DashboardView()
                .tabItem {
                    Label("Today", systemImage: "circle.hexagongrid.fill")
                }
                .tag(0)

            MealLogView()
                .tabItem {
                    Label("Meals", systemImage: "fork.knife")
                }
                .tag(1)

            FrostedScannerView()
                .tabItem {
                    Label("Scan", systemImage: "barcode.viewfinder")
                }
                .tag(4)

            SanctuaryView()
                .tabItem {
                    Label("Sanctuary", systemImage: "leaf.fill")
                }
                .tag(5)

            WaterView()
                .tabItem {
                    Label("Water", systemImage: "drop.fill")
                }
                .tag(2)

            AnalyticsView()
                .tabItem {
                    Label("Trends", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(6)

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle.fill")
                }
                .tag(3)
        }
        .tint(PrecisionCalTheme.terracotta)
        .onAppear {
            let appearance = UITabBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.backgroundEffect = UIBlurEffect(style: .systemThinMaterial)
            appearance.backgroundColor = UIColor(PrecisionCalTheme.bgTop.opacity(0.5))
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}
