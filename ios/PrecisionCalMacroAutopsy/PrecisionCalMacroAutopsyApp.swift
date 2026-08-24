import SwiftUI
import SwiftData
import RevenueCat

@main
struct PrecisionCalMacroAutopsyApp: App {
    @AppStorage("hasOnboarded") private var hasOnboarded: Bool = false
    @State private var store: StoreViewModel
    @State private var ownerAuth: OwnerAuthService

    init() {
        #if DEBUG
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: Config.EXPO_PUBLIC_REVENUECAT_TEST_API_KEY)
        #else
        Purchases.configure(withAPIKey: Config.EXPO_PUBLIC_REVENUECAT_IOS_API_KEY)
        #endif
        let store = StoreViewModel()
        _store = State(initialValue: store)
        _ownerAuth = State(initialValue: OwnerAuthService(store: store))
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
            ShoppingItem.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // A store that fails to open (e.g. an unmigratable schema from an older build)
            // must not crash-loop the app forever. Quarantine it and start fresh.
            print("ModelContainer failed to open, quarantining store for recovery: \(error.localizedDescription)")
            quarantineDefaultStore()
            do {
                return try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()

    /// Moves the unreadable default store (and its WAL/SHM sidecars) aside with a timestamped
    /// suffix instead of deleting it, so the data remains on-device for potential recovery.
    private static func quarantineDefaultStore() {
        let fm = FileManager.default
        let storeURL = URL.applicationSupportDirectory.appending(path: "default.store", directoryHint: .notDirectory)
        do {
            try fm.createDirectory(at: URL.applicationSupportDirectory, withIntermediateDirectories: true)
        } catch {
            return
        }
        let stamp = Int(Date.now.timeIntervalSince1970)
        for suffix in ["", "-wal", "-shm"] {
            let url = URL(fileURLWithPath: storeURL.path + suffix)
            guard fm.fileExists(atPath: url.path) else { continue }
            try? fm.moveItem(at: url, to: URL(fileURLWithPath: url.path + ".broken-\(stamp)"))
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.light)
                .tint(PrecisionCalMacroAutopsyTheme.terracotta)
                .environment(store)
                .environment(ownerAuth)
                .task { await ownerAuth.refreshSilently() }
        }
        .modelContainer(sharedModelContainer)
    }
}
