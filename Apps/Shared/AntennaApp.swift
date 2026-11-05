import SwiftUI
import SwiftData

@main
struct AntennaApp: App {
    /// One container, CloudKit-backed. The iCloud container id comes from the
    /// entitlements, so `.automatic` resolves to `iCloud.se.codecrave.antenna`.
    /// On tvOS with the "Runs as Current User" entitlement this becomes
    /// per-profile automatically. A Debug build launched by a UI test gets
    /// the in-memory `UITestingStore` instead.
    private let container: ModelContainer
    /// Downloads and answers guide data for every screen (spec 0014).
    @State private var guideStore: AppGuideStore

    init() {
        let container = Self.makeContainer()
        self.container = container
        _guideStore = State(initialValue: AppGuideStore.live(container: container))
    }

    private static func makeContainer() -> ModelContainer {
        #if DEBUG
            if let seeded = UITestingStore.container() { return seeded }
        #endif
        let schema = Schema([SourceRecord.self, FavoriteRecord.self])
        let config = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.guideStore, guideStore)
        }
        .modelContainer(container)
    }
}
