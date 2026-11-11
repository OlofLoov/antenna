import SwiftUI
import SwiftData

@main
struct AntennaApp: App {
    /// One container, CloudKit-backed. The iCloud container id comes from the
    /// entitlements, so `.automatic` resolves to `iCloud.se.codecrave.antenna`.
    /// Profiles live inside it (profiles capability). A Debug build launched by a UI test gets
    /// the in-memory `UITestingStore`, `UITestingShell`, `UITestingScreenshots`
    /// or `UITestingLive` instead.
    private let container: ModelContainer
    /// Downloads and answers guide data for every screen (guide-data capability).
    @State private var guideStore: AppGuideStore

    init() {
        let container = Self.makeContainer()
        self.container = container
        // A profile deleted on another device leaves its per-device values here.
        let profiles = (try? container.mainContext.fetch(FetchDescriptor<ProfileRecord>())) ?? []
        ProfileKeys.prune(.standard, keeping: ProfileStore.list(profiles).profiles.map(\.id))
        ActivityStore.carryOverSearches(from: .standard, into: container.mainContext)
        _guideStore = State(initialValue: AppGuideStore.live(container: container))
    }

    private static func makeContainer() -> ModelContainer {
        #if DEBUG
            if let seeded = UITestingStore.container() { return seeded }
            if let seeded = UITestingShell.container() { return seeded }
            if let seeded = UITestingScreenshots.container() { return seeded }
            if let seeded = UITestingLive.container() { return seeded }
        #endif
        let schema = Schema(AntennaSchema.models)
        let config = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            PlatformRoot()
                .environment(\.guideStore, guideStore)
        }
        .modelContainer(container)
    }
}
