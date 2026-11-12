#if !os(tvOS)
    import AntennaCore
    import AppIntents
    import Foundation

    /// A channel as Siri and Shortcuts show and store it. The id is the
    /// channel reference, `"<source id>/<channel id>"`, which holds no link
    /// or login (app-intents/shortcuts-never-hold-a-password).
    struct ChannelEntity: AppEntity {
        static let typeDisplayRepresentation: TypeDisplayRepresentation = "Channel"
        static let defaultQuery = ChannelQuery()

        let id: String
        var name: String
        /// "201 · Sport · Cabin".
        var subtitle: String
        /// The logo, only from an `https` link.
        var logo: URL?
        /// Why the channel cannot play now; the action says it before doing anything.
        var failure: IntentFailure?

        var displayRepresentation: DisplayRepresentation {
            DisplayRepresentation(
                title: "\(name)", subtitle: subtitle.isEmpty ? nil : "\(subtitle)", image: logo.map { DisplayRepresentation.Image(url: $0) }
            )
        }

        /// A loaded channel.
        init(_ channel: Channel, in library: IntentChannels) {
            let key = LastChannelKey(channel)
            id = key?.string ?? ""
            name = IntentText.channel(channel.name)
            let number = RowKey(channel).flatMap(library.catalogue.channelNumber(for:))
            subtitle = IntentText.channelSubtitle(number: number, group: channel.group, source: library.sourceName(channel.sourceID))
            logo = channel.logoURL.flatMap { $0.scheme?.lowercased() == "https" ? $0 : nil }
        }

        /// A saved reference that cannot play now, or that resolves only once Antenna is forward.
        init(id: String, failure: IntentFailure?) {
            self.id = id
            name = "Channel"
            subtitle = failure?.description ?? ""
            self.failure = failure
        }
    }

    /// A movie or series as Siri and Shortcuts show and store it. The id is
    /// the title reference, `"<source id>/<title id>"`.
    struct TitleEntity: AppEntity {
        static let typeDisplayRepresentation: TypeDisplayRepresentation = "Movie or Series"
        static let defaultQuery = TitleQuery()

        let id: String
        var name: String
        /// "Movie · Cabin" or "Series · Cabin".
        var subtitle: String
        var poster: URL?
        var failure: IntentFailure?

        var displayRepresentation: DisplayRepresentation {
            DisplayRepresentation(
                title: "\(name)", subtitle: subtitle.isEmpty ? nil : "\(subtitle)",
                image: poster.map { DisplayRepresentation.Image(url: $0) })
        }

        init(_ title: ShelfTitle, in library: IntentTitles) {
            id = TitleReference(title).string
            name = IntentText.title(title.name)
            subtitle = IntentText.titleSubtitle(title.kind, source: library.sourceName(title.sourceID))
            poster = title.posterURL.flatMap { $0.scheme?.lowercased() == "https" ? $0 : nil }
        }

        init(id: String, failure: IntentFailure?) {
            self.id = id
            name = "Title"
            subtitle = failure?.description ?? ""
            self.failure = failure
        }
    }

    /// Finds channels for Siri and Shortcuts: saved references, a typed
    /// name or number, and the suggested list.
    struct ChannelQuery: EntityStringQuery {
        func entities(for identifiers: [String]) async throws -> [ChannelEntity] {
            await IntentQueries.channels(identifiers)
        }

        func entities(matching string: String) async throws -> [ChannelEntity] {
            await IntentQueries.channels(matching: string)
        }

        func suggestedEntities() async throws -> [ChannelEntity] {
            await IntentQueries.suggestedChannels()
        }
    }

    /// Finds movies and series for Siri and Shortcuts.
    struct TitleQuery: EntityStringQuery {
        func entities(for identifiers: [String]) async throws -> [TitleEntity] {
            await IntentQueries.titles(identifiers)
        }

        func entities(matching string: String) async throws -> [TitleEntity] {
            await IntentQueries.titles(matching: string)
        }

        func suggestedEntities() async throws -> [TitleEntity] {
            await IntentQueries.suggestedTitles()
        }
    }

    /// The queries' work, on the main actor with the app's provider.
    @MainActor
    enum IntentQueries {
        /// One entity per parseable id, in order; an id that does not parse
        /// is left out, and one that cannot play carries its reason. Never throws
        /// (app-intents/a-clear-reply-when-a-channel-or-title-cannot-play).
        static func channels(_ identifiers: [String]) async -> [ChannelEntity] {
            let keys = identifiers.compactMap { id in LastChannelKey(parsing: id).map { (id, $0) } }
            guard !keys.isEmpty else { return [] }
            guard let provider = IntentContext.provider else { return keys.map { ChannelEntity(id: $0.0, failure: .notUnlocked) } }
            do throws(IntentFailure) {
                try provider.checkAccess()
            } catch {
                return keys.map { ChannelEntity(id: $0.0, failure: error) }
            }
            // Before the first unlock the Keychain is closed; the app resolves it once forward.
            guard provider.protectedDataAvailable else { return keys.map { ChannelEntity(id: $0.0, failure: nil) } }
            let library = await provider.channels(loading: Set(keys.map(\.1.sourceID)))
            return keys.map { id, key in
                switch IntentLookup.channel(key, in: library.catalogue, sources: library.sources) {
                case .success(let channel): ChannelEntity(channel, in: library)
                case .failure(let failure): ChannelEntity(id: id, failure: failure)
                }
            }
        }

        /// The channels a typed name or number finds
        /// (app-intents/ask-for-a-channel-by-name-or-number).
        static func channels(matching string: String) async -> [ChannelEntity] {
            guard let provider = ready() else { return [] }
            let library = await provider.channels(loading: nil)
            return library.matcher.matches(string, limit: IntentLookup.matches).compactMap { row in
                library.catalogue.channel(for: row).map { ChannelEntity($0, in: library) }
            }
        }

        /// Favorites, then the other channels (app-intents/shortcuts-suggests-what-you-watch).
        static func suggestedChannels() async -> [ChannelEntity] {
            guard let provider = ready() else { return [] }
            let library = await provider.channels(loading: nil)
            return IntentLookup.suggestedChannels(in: library.catalogue).compactMap { row in
                library.catalogue.channel(for: row).map { ChannelEntity($0, in: library) }
            }
        }

        static func titles(_ identifiers: [String]) async -> [TitleEntity] {
            let references = identifiers.compactMap { id in TitleReference(parsing: id).map { (id, $0) } }
            guard !references.isEmpty else { return [] }
            guard let provider = IntentContext.provider else { return references.map { TitleEntity(id: $0.0, failure: .notUnlocked) } }
            do throws(IntentFailure) {
                try provider.checkAccess()
            } catch {
                return references.map { TitleEntity(id: $0.0, failure: error) }
            }
            guard provider.protectedDataAvailable else { return references.map { TitleEntity(id: $0.0, failure: nil) } }
            let library = await provider.titles(loading: Set(references.map(\.1.sourceID)))
            return references.map { id, reference in
                switch IntentLookup.title(reference, in: library.titles, sources: library.sources) {
                case .success(let title): TitleEntity(title, in: library)
                case .failure(let failure): TitleEntity(id: id, failure: failure)
                }
            }
        }

        /// Titles whose name holds every typed word, as Search finds them.
        static func titles(matching string: String) async -> [TitleEntity] {
            guard let provider = ready() else { return [] }
            let library = await provider.titles(loading: nil)
            let found = SearchIndex(channels: [], guide: GuideIndex(), titles: library.titles, now: .distantPast)
                .results(for: SearchQuery(string), now: .distantPast).titles
            return found.prefix(IntentLookup.matches).map { TitleEntity($0.title, in: library) }
        }

        /// In progress, then My list (app-intents/shortcuts-suggests-what-you-watch).
        static func suggestedTitles() async -> [TitleEntity] {
            guard let provider = ready() else { return [] }
            let library = await provider.titles(loading: nil)
            return IntentLookup.suggestedTitles(progress: library.progress, myList: library.myList, titles: library.titles)
                .map { TitleEntity($0, in: library) }
        }

        /// The provider when it is unlocked, has sources and can read the Keychain.
        private static func ready() -> (any IntentCatalogueProvider)? {
            guard let provider = IntentContext.provider, (try? provider.checkAccess()) != nil, provider.protectedDataAvailable else {
                return nil
            }
            return provider
        }
    }
#endif
