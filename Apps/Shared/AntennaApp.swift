import SwiftUI
import SwiftData

@main
struct AntennaApp: App {
    /// One container, CloudKit-backed. The iCloud container id comes from the
    /// entitlements, so `.automatic` resolves to `iCloud.se.codecrave.antenna`.
    /// On tvOS with the "Runs as Current User" entitlement this becomes
    /// per-profile automatically.
    private let container: ModelContainer = {
        let schema = Schema([SourceRecord.self, FavoriteRecord.self])
        let config = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
