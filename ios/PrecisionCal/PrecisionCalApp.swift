import SwiftUI
import SwiftData
import RevenueCat

@main
struct PrecisionCalApp: App {
    @AppStorage("hasOnboarded") private var hasOnboarded: Bool = false
    @State private var store = StoreViewModel()

    init() {
        #if DEBUG
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: Config.EXPO_PUBLIC_REVENUECAT_TEST_API_KEY)
        #else
        Purchases.configure(withAPIKey: Config.EXPO_PUBLIC_REVENUECAT_IOS_API_KEY)
        #endif
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Meal.self,
            MealItem.self,
            WaterEntry.self,
            UserProfile.self,
            ScannedProduct.self,
            Calibration.self,
            SanctuaryPost.self,
            SanctuaryComment.self,
            RoadmapInsight.self,
            BodyWeightEntry.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.light)
                .tint(PrecisionCalTheme.terracotta)
                .environment(store)
        }
        .modelContainer(sharedModelContainer)
    }
}
