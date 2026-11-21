import Foundation

extension GuideSourcesText {
    /// What the channel detail shows above the picker: a title and body lines.
    public struct Card: Sendable, Equatable {
        public var title: Line
        public var body: [String]

        public init(title: Line, body: [String]) {
            self.title = title
            self.body = body
        }
    }

    /// What a card needs to know besides the reason.
    public struct CardContext: Sendable {
        public var channel: Channel
        public var source: String
        public var kind: SourceKind
        public var status: GuideSourceStatus
        public var index: GuideIndex
        public var now: Date
        /// Each guide's name, as its row's first line shows it.
        public var guideName: @Sendable (GuideReference) -> String

        public init(
            channel: Channel, source: String, kind: SourceKind, status: GuideSourceStatus, index: GuideIndex, now: Date,
            guideName: @escaping @Sendable (GuideReference) -> String
        ) {
            self.channel = channel
            self.source = source
            self.kind = kind
            self.status = status
            self.index = index
            self.now = now
            self.guideName = guideName
        }
    }

    /// The card for `reason`, with the suffix lines about failed and
    /// downloading guides where they apply.
    public func card(_ reason: GuideReason, _ context: CardContext) -> Card {
        var card = main(reason, context)
        switch reason {
        case .everyGuideFailed, .offline, .waitingForLogin: break
        default: card.body += suffix(context.status)
        }
        return card
    }

    private func main(_ reason: GuideReason, _ context: CardContext) -> Card {
        switch reason {
        case .playlistLoading:
            return Card(
                title: Line(words("Waiting for the playlist")),
                body: [words("Antenna reads the guide links from the playlist when it finishes loading.")]
            )
        case .noGuide:
            return Card(
                title: Line(words("This source has no guide")),
                body: [words("Add a guide URL to get programme information for \(words.source(context.source)).")])
        case .waitingForLogin where television:
            return Card(
                title: Line(words("Sign in on this Apple TV"), .muted),
                body: [words("The provider guide needs this source's login. Sign in from Sources & Settings.")])
        case .waitingForLogin:
            return Card(
                title: Line(words("Waiting for the login to sync"), .muted),
                body: [words("The provider guide needs this source's login, which has not reached this device from iCloud yet.")])
        case .notDownloaded(let bytes):
            let body = bytes.map(setup.downloading(bytes:)) ?? words("Antenna downloads the guide when the source finishes loading.")
            return Card(title: Line(words("The guide has not been downloaded yet")), body: [body])
        case .offline:
            return Card(title: Line(words("You're offline"), .muted), body: [words("The guide downloads when you're back online.")])
        case .everyGuideFailed:
            let lines = context.status.rows.filter(\.enabled).map { row in
                [context.guideName(row.reference), status(row, coverage: nil, channels: 0, source: context.source).text].joinedAsDetail(
                    words.locale)
            }
            return Card(title: Line(words("The guide could not be downloaded"), .error), body: lines)
        default:
            return idCard(reason, context)
        }
    }

    /// The cards for a channel whose guide id is missing, unmatched or empty.
    private func idCard(_ reason: GuideReason, _ context: CardContext) -> Card {
        let channel = context.channel.name
        let finished = context.index.sources[context.channel.sourceID ?? UUID()]?.layers ?? []
        switch reason {
        case .matchNotFound(let id):
            return Card(
                title: Line(words("The mapped entry “\(id)” has no programmes")),
                body: [words("Pick another entry below, or remove the mapping to go back to the playlist's id.")])
        case .noGuideID:
            let opening =
                context.kind == .xtream
                ? words("The provider sends no epg_channel_id for \(words.source(channel))")
                : words("The playlist has no tvg-id for \(words.source(channel))")
            return Card(
                title: Line(words("The source gives this channel no guide id")),
                body: [words("\(opening), and no guide entry has exactly its name. Pick an entry below.")])
        case .idNotFound(let id):
            if finished.count > 1 {
                return Card(
                    title: Line(words("Guide id “\(id)” is not in any of the \(finished.count) guides")),
                    body: [
                        words(
                            """
                            None of the \(finished.count) guides for \(words.source(context.source)) \
                            lists “\(id)”. Pick an entry below.
                            """)
                    ])
            }
            let guide = finished.first.map { context.guideName($0.reference) } ?? words("The guide")
            return Card(
                title: Line(words("Guide id “\(id)” is not in the guide")),
                body: [words("“\(guide)” does not list “\(id)”. Pick an entry below.")])
        case .noProgrammes(let id):
            let lister = finished.first { $0.guide.lists(id) }
            let guide = lister.map { context.guideName($0.reference) } ?? words("The guide")
            return Card(
                title: Line(words("The guide lists “\(id)” but has no programmes for it")),
                body: [
                    words(
                        """
                        \(guide) knows the channel but carries no programmes for it. Pick another \
                        entry below, or wait for the provider to fill it.
                        """
                    )
                ])
        case .guideEnded(let id):
            return Card(
                title: Line(words("The guide for “\(id)” has run out")),
                body: [
                    words(
                        """
                        \(winner(id, context)) lists programmes for this channel but none after \
                        now. Wait for the next guide refresh or pick another entry below.
                        """
                    )
                ])
        case .hasGuide(let id):
            let layer = finished.first { $0.guide.slots(for: id) != nil }
            let name = layer?.guide.name(for: id) ?? context.channel.name
            let days = layer.map { setup.days($0.guide.days(from: context.now)) } ?? setup.days(0)
            let how =
                switch context.index.match(for: context.channel)?.origin {
                case .user: words("Mapped by you")
                case .name: words("Matched by name")
                case nil: words("Matched by tvg-id")
                }
            return Card(title: Line(words("Guide from \(winner(id, context))")), body: ["“\(name)” (\(id)) · \(days) · \(how)"])
        case .playlistLoading, .noGuide, .waitingForLogin, .notDownloaded, .offline, .everyGuideFailed:
            return main(reason, context)
        }
    }

    private func winner(_ id: String, _ context: CardContext) -> String {
        let layers = context.index.sources[context.channel.sourceID ?? UUID()]?.layers ?? []
        return layers.first { $0.guide.slots(for: id) != nil }.map { context.guideName($0.reference) } ?? words("The guide")
    }

    /// "1 of 3 guides could not be downloaded." and "1 guide is still downloading."
    public func suffix(_ status: GuideSourceStatus) -> [String] {
        let total = status.rows.count(where: \.enabled)
        let counts = GuideDiagnosis.pending(status)
        var lines: [String] = []
        if counts.failed > 0 {
            lines.append(words("\(counts.failed) of \(total) guides could not be downloaded."))
        }
        if counts.downloading > 0 {
            lines.append(words("\(counts.downloading) guides are still downloading."))
        }
        return lines
    }
}
