#if DEBUG
    import Foundation
    import SwiftData

    /// In-memory store for XCUITests, compiled into Debug builds only.
    ///
    /// `-ui-testing-favorites 2,0,1` starts the app on a store holding one
    /// `FavoriteRecord` per listed sort order, with channel id `channel-<n>`.
    /// An empty value starts it on an empty store. The store never reaches
    /// iCloud and is gone when the app quits.
    enum UITestingStore {
        static let favoritesArgument = "-ui-testing-favorites"

        /// The seeded container, or nil when the app was not launched for UI tests.
        static func container(arguments: [String] = ProcessInfo.processInfo.arguments) -> ModelContainer? {
            guard let index = arguments.firstIndex(of: favoritesArgument) else { return nil }
            let next = arguments.index(after: index)
            let value = next < arguments.endIndex ? arguments[next] : ""
            let sortOrders = value.split(separator: ",").map { token in
                guard let order = Int(token.trimmingCharacters(in: .whitespaces)) else {
                    fatalError("\(favoritesArgument) takes comma-separated integers, got \(token)")
                }
                return order
            }

            let schema = Schema([SourceRecord.self, FavoriteRecord.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            do {
                let container = try ModelContainer(for: schema, configurations: [config])
                let context = ModelContext(container)
                for order in sortOrders {
                    context.insert(FavoriteRecord(channelID: "channel-\(order)", sourceID: nil, sortOrder: order))
                }
                try context.save()
                return container
            } catch {
                fatalError("Could not create the UI testing store: \(error)")
            }
        }
    }
#endif
