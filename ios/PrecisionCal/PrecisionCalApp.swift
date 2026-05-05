import SwiftUI
import SwiftData

@main
struct PrecisionCalApp: App {
    @AppStorage("hasOnboarded") private var hasOnboarded: Bool = false

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
        }
        .modelContainer(sharedModelContainer)
    }
}
