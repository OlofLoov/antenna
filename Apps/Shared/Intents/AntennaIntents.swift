#if !os(tvOS)
    import AntennaCore
    import AppIntents
    import Foundation

    /// Plays a channel on Live (app-intents/tune-a-channel-by-voice-or-shortcut).
    struct TuneChannelIntent: AppIntent {
        static let title: LocalizedStringResource = "Tune Channel"
        static let description = IntentDescription("Opens Antenna on Live with the channel playing.")
        static let supportedModes: IntentModes = [.background, .foreground(.dynamic)]

        @Parameter(title: "Channel", requestValueDialog: "Which channel?")
        var channel: ChannelEntity

        init() {}

        init(channel: ChannelEntity) {
            self.channel = channel
        }

        @MainActor
        func perform() async throws -> some IntentResult {
            try await IntentActions.tune(channel, for: self)
            return .result()
        }
    }

    /// Resumes a movie or opens a series (app-intents/play-a-movie-or-series).
    struct PlayTitleIntent: AppIntent {
        static let title: LocalizedStringResource = "Play Title"
        static let description = IntentDescription("Opens Antenna and resumes the movie, or opens the series.")
        static let supportedModes: IntentModes = [.background, .foreground(.dynamic)]

        @Parameter(title: "Movie or Series", requestValueDialog: "Which movie or series?")
        var title: TitleEntity

        init() {}

        init(title: TitleEntity) {
            self.title = title
        }

        @MainActor
        func perform() async throws -> some IntentResult {
            try await IntentActions.play(title, for: self)
            return .result()
        }
    }

    /// Opens Search, with a query or without (app-intents/open-search).
    struct OpenSearchIntent: AppIntent {
        static let title: LocalizedStringResource = "Open Search"
        static let description = IntentDescription("Opens Antenna on Search.")
        static let supportedModes: IntentModes = [.background, .foreground(.dynamic)]

        @Parameter(title: "Search For")
        var query: String?

        init() {}

        init(query: String?) {
            self.query = query
        }

        @MainActor
        func perform() async throws -> some IntentResult {
            try await IntentActions.search(query, for: self)
            return .result()
        }
    }

    /// How Toggle Favorite changes the channel.
    enum FavoriteMode: String, AppEnum {
        case toggle, add, remove

        static let typeDisplayRepresentation: TypeDisplayRepresentation = "Change"
        static let caseDisplayRepresentations: [FavoriteMode: DisplayRepresentation] = [
            .toggle: "Toggle", .add: "Add", .remove: "Remove",
        ]
    }

    /// Adds, removes or toggles a favorite without bringing Antenna forward
    /// (app-intents/change-a-favorite-without-opening-the-app).
    struct ToggleFavoriteIntent: AppIntent {
        static let title: LocalizedStringResource = "Toggle Favorite"
        static let description = IntentDescription("Adds or removes the playing or named channel from Favorites.")
        static let supportedModes: IntentModes = .background

        @Parameter(title: "Channel")
        var channel: ChannelEntity?

        @Parameter(title: "Change", default: .toggle)
        var mode: FavoriteMode

        init() {}

        init(channel: ChannelEntity?, mode: FavoriteMode) {
            self.channel = channel
            self.mode = mode
        }

        @MainActor
        func perform() async throws -> some IntentResult & ReturnsValue<Bool> & ProvidesDialog {
            let outcome = try await IntentActions.favorite(channel, mode: mode)
            return .result(value: outcome.isFavorite, dialog: IntentDialog(stringLiteral: outcome.reply))
        }
    }

    /// "Add this channel to favorites in Antenna": Toggle Favorite set to
    /// add, for the playing channel. App Shortcuts need it visible, so it
    /// also lists in Shortcuts.
    struct AddFavoriteIntent: AppIntent {
        static let title: LocalizedStringResource = "Add to Favorites"
        static let description = IntentDescription("Adds the playing channel to Favorites.")
        static let supportedModes: IntentModes = .background

        @MainActor
        func perform() async throws -> some IntentResult & ReturnsValue<Bool> & ProvidesDialog {
            let outcome = try await IntentActions.favorite(nil, mode: .add)
            return .result(value: outcome.isFavorite, dialog: IntentDialog(stringLiteral: outcome.reply))
        }
    }

    /// "Remove this channel from favorites in Antenna": Toggle Favorite set to remove.
    struct RemoveFavoriteIntent: AppIntent {
        static let title: LocalizedStringResource = "Remove from Favorites"
        static let description = IntentDescription("Removes the playing channel from Favorites.")
        static let supportedModes: IntentModes = .background

        @MainActor
        func perform() async throws -> some IntentResult & ReturnsValue<Bool> & ProvidesDialog {
            let outcome = try await IntentActions.favorite(nil, mode: .remove)
            return .result(value: outcome.isFavorite, dialog: IntentDialog(stringLiteral: outcome.reply))
        }
    }

    /// What every action does, apart from the AppIntents types so tests
    /// call it with a provider over an in-memory store.
    @MainActor
    enum IntentActions {
        struct FavoriteOutcome: Equatable {
            var isFavorite: Bool
            var reply: String
        }

        /// Refuses before the unlock, without sources, or for a channel that
        /// cannot play; otherwise brings Antenna forward and asks Live to
        /// play the channel. Nothing is tuned when the system refuses.
        static func tune<Intent: AppIntent>(_ channel: ChannelEntity, for intent: Intent) async throws {
            let provider = try IntentContext.current()
            try provider.checkAccess()
            if let failure = channel.failure { throw failure }
            guard let key = LastChannelKey(parsing: channel.id) else { throw IntentFailure.channelSourceGone }
            try await provider.bringForward(intent)
            provider.open(.tune(key))
        }

        static func play<Intent: AppIntent>(_ title: TitleEntity, for intent: Intent) async throws {
            let provider = try IntentContext.current()
            try provider.checkAccess()
            if let failure = title.failure { throw failure }
            guard let reference = TitleReference(parsing: title.id) else { throw IntentFailure.titleSourceGone }
            try await provider.bringForward(intent)
            provider.open(.play(reference))
        }

        /// A query of only spaces counts as none.
        static func search<Intent: AppIntent>(_ query: String?, for intent: Intent) async throws {
            let provider = try IntentContext.current()
            try provider.checkAccess()
            try await provider.bringForward(intent)
            let text = query?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            provider.open(.search(text.isEmpty ? nil : text))
        }

        /// Changes the named channel, or the one playing, and says what it did.
        static func favorite(_ entity: ChannelEntity?, mode: FavoriteMode) async throws -> FavoriteOutcome {
            let provider = try IntentContext.current()
            try provider.checkAccess()
            guard provider.protectedDataAvailable else { throw IntentFailure.needsUnlock(provider.device) }
            let library: IntentChannels
            let channel: Channel
            if let entity {
                if let failure = entity.failure { throw failure }
                guard let key = LastChannelKey(parsing: entity.id) else { throw IntentFailure.channelSourceGone }
                library = await provider.channels(loading: [key.sourceID])
                channel = try IntentLookup.channel(key, in: library.catalogue, sources: library.sources).get()
            } else {
                guard let playing = provider.playing else { throw IntentFailure.nothingPlaying }
                library = await provider.channels(loading: [])
                channel = playing
            }
            let isFavorite = library.catalogue.isFavorite(channel)
            switch (mode, isFavorite) {
            case (.add, true):
                return FavoriteOutcome(isFavorite: true, reply: IntentFailure.alreadyFavorite(channel: channel.name).description)
            case (.remove, false):
                return FavoriteOutcome(isFavorite: false, reply: IntentFailure.notFavorite(channel: channel.name).description)
            case (.add, false), (.toggle, false):
                provider.setFavorite(channel, to: true, in: library.catalogue)
                return FavoriteOutcome(isFavorite: true, reply: IntentText.added(channel.name))
            case (.remove, true), (.toggle, true):
                provider.setFavorite(channel, to: false, in: library.catalogue)
                return FavoriteOutcome(isFavorite: false, reply: IntentText.removed(channel.name))
            }
        }
    }

    /// The Siri phrases on iPhone, iPad and Mac
    /// (app-intents/tune-a-channel-by-voice-or-shortcut).
    struct AntennaShortcuts: AppShortcutsProvider {
        static var appShortcuts: [AppShortcut] {
            AppShortcut(
                intent: TuneChannelIntent(),
                phrases: [
                    "Tune to \(\.$channel) in \(.applicationName)", "Watch \(\.$channel) in \(.applicationName)",
                    "Put on \(\.$channel) in \(.applicationName)", "Tune a channel in \(.applicationName)",
                ], shortTitle: "Tune Channel", systemImageName: "tv")
            AppShortcut(
                intent: PlayTitleIntent(),
                phrases: ["Play \(\.$title) in \(.applicationName)", "Play a movie in \(.applicationName)"],
                shortTitle: "Play Title", systemImageName: "film")
            AppShortcut(
                intent: OpenSearchIntent(), phrases: ["Search \(.applicationName)", "Find a channel in \(.applicationName)"],
                shortTitle: "Search", systemImageName: "magnifyingglass")
            AppShortcut(
                intent: AddFavoriteIntent(), phrases: ["Add this channel to favorites in \(.applicationName)"],
                shortTitle: "Add to Favorites", systemImageName: "star")
            AppShortcut(
                intent: RemoveFavoriteIntent(), phrases: ["Remove this channel from favorites in \(.applicationName)"],
                shortTitle: "Remove from Favorites", systemImageName: "star.slash")
        }
    }
#endif
