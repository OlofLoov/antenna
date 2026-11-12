#if !os(tvOS)
    import AntennaCore
    import AppIntents
    import Foundation
    import Observation
    import SwiftData

    /// The loaded channels as the actions see them (app-intents capability).
    struct IntentChannels {
        var catalogue: Catalogue<PersistentIdentifier>
        var sources: [IntentSource]
        var matcher: ChannelMatcher

        /// The source's name, "your source" when unknown.
        func sourceName(_ id: UUID?) -> String {
            sources.first { $0.id == id }?.name ?? "your source"
        }
    }

    /// The loaded movies and series, with the current profile's progress and My list.
    struct IntentTitles {
        var titles: [ShelfTitle]
        var sources: [IntentSource]
        var progress: [WatchProgress] = []
        var myList: [ActivityKey] = []

        func sourceName(_ id: UUID) -> String {
            sources.first { $0.id == id }?.name ?? "your source"
        }
    }

    /// What an action asks the open app to do once it is forward.
    enum IntentRequest: Equatable, Sendable {
        case tune(LastChannelKey)
        case play(TitleReference)
        /// Search, with the query to run or nil for an empty field.
        case search(String?)
    }

    /// Everything the actions read and change, behind one seam so tests
    /// run them against an in-memory store (app-intents capability).
    @MainActor
    protocol IntentCatalogueProvider: AnyObject {
        /// Throws `notUnlocked` or `noSources`, read from what this device
        /// already knows, never waiting on the App Store.
        func checkAccess() throws(IntentFailure)
        /// False before the first unlock after a restart, when the Keychain
        /// cannot be read.
        var protectedDataAvailable: Bool { get }
        /// The device the unlock reply names.
        var device: IntentFailure.Device { get }
        /// The channels, after loading the sources named, or every source
        /// for nil, for at most the background deadline. An empty set loads nothing.
        func channels(loading sources: Set<UUID>?) async -> IntentChannels
        /// The titles, loaded like `channels(loading:)`.
        func titles(loading sources: Set<UUID>?) async -> IntentTitles
        /// The channel playing in this process, if any.
        var playing: Channel? { get }
        /// Adds or removes `channel` from the current profile's favorites.
        func setFavorite(_ channel: Channel, to favorite: Bool, in catalogue: Catalogue<PersistentIdentifier>)
        /// Hands `request` to the app's screens.
        func open(_ request: IntentRequest)
        /// Brings Antenna forward for `intent`; throws when the system refuses.
        func bringForward<Intent: AppIntent>(_ intent: Intent) async throws
    }

    /// Where the actions find their provider. The app sets it at launch;
    /// tests set a provider over an in-memory store.
    @MainActor
    enum IntentContext {
        static var provider: (any IntentCatalogueProvider)?

        /// The provider, or `notUnlocked` before the app set one up.
        static func current() throws(IntentFailure) -> any IntentCatalogueProvider {
            guard let provider else { throw .notUnlocked }
            return provider
        }
    }

    /// Requests from Siri and Shortcuts wait here, outside every gate,
    /// until the window's screens take them.
    @MainActor @Observable
    final class IntentInbox {
        private(set) var pending: IntentRequest?

        func receive(_ request: IntentRequest) {
            pending = request
        }

        func take() {
            pending = nil
        }
    }

    extension IntentFailure: @retroactive CustomLocalizedStringResourceConvertible {
        /// What Siri and Shortcuts say when an action fails.
        public var localizedStringResource: LocalizedStringResource {
            LocalizedStringResource(stringLiteral: description)
        }
    }
#endif
