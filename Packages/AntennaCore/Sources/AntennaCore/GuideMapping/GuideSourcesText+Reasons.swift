import Foundation

extension GuideSourcesText {
    /// What the channel detail shows above the picker: a title and body lines.
    public struct Card: Sendable, Equatable {
        public var title: Line
        public var body: [String]
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
        let channel = context.channel.name
        let finished = context.index.sources[context.channel.sourceID ?? UUID()]?.layers ?? []
        switch reason {
        case .playlistLoading:
            return Card(
                title: Line("Waiting for the playlist"), body: ["Antenna reads the guide links from the playlist when it finishes loading."]
            )
        case .noGuide:
            return Card(
                title: Line("This source has no guide"), body: ["Add a guide URL to get programme information for \(context.source)."])
        case .waitingForLogin where television:
            return Card(
                title: Line("Sign in on this Apple TV", .muted),
                body: ["The provider guide needs this source's login. Sign in from Sources & Settings."])
        case .waitingForLogin:
            return Card(
                title: Line("Waiting for the login to sync", .muted),
                body: ["The provider guide needs this source's login, which has not reached this device from iCloud yet."])
        case .notDownloaded(let bytes):
            let body = bytes.map(setup.downloading(bytes:)) ?? "Antenna downloads the guide when the source finishes loading."
            return Card(title: Line("The guide has not been downloaded yet"), body: [body])
        case .offline:
            return Card(title: Line("You're offline", .muted), body: ["The guide downloads when you're back online."])
        case .everyGuideFailed:
            let lines = context.status.rows.filter(\.enabled).map { row in
                "\(context.guideName(row.reference)) · \(status(row, coverage: nil, channels: 0, source: context.source).text)"
            }
            return Card(title: Line("The guide could not be downloaded", .error), body: lines)
        case .matchNotFound(let id):
            return Card(
                title: Line("The mapped entry “\(id)” has no programmes"),
                body: ["Pick another entry below, or remove the mapping to go back to the playlist's id."])
        case .noGuideID:
            let opening =
                context.kind == .xtream
                ? "The provider sends no epg_channel_id for \(channel)" : "The playlist has no tvg-id for \(channel)"
            return Card(
                title: Line("The source gives this channel no guide id"),
                body: ["\(opening), and no guide entry has exactly its name. Pick an entry below."])
        case .idNotFound(let id):
            if finished.count > 1 {
                return Card(
                    title: Line("Guide id “\(id)” is not in any of the \(setup.count(finished.count)) guides"),
                    body: ["None of the \(setup.count(finished.count)) guides for \(context.source) lists “\(id)”. Pick an entry below."])
            }
            let guide = finished.first.map { context.guideName($0.reference) } ?? "The guide"
            return Card(
                title: Line("Guide id “\(id)” is not in the guide"), body: ["“\(guide)” does not list “\(id)”. Pick an entry below."])
        case .noProgrammes(let id):
            let lister = finished.first { $0.guide.names[id] != nil || $0.guide.schedules[id] != nil }
            let guide = lister.map { context.guideName($0.reference) } ?? "The guide"
            return Card(
                title: Line("The guide lists “\(id)” but has no programmes for it"),
                body: [
                    "\(guide) knows the channel but carries no programmes for it. "
                        + "Pick another entry below, or wait for the provider to fill it."
                ])
        case .guideEnded(let id):
            return Card(
                title: Line("The guide for “\(id)” has run out"),
                body: [
                    "\(winner(id, context)) lists programmes for this channel but none after now. "
                        + "Wait for the next guide refresh or pick another entry below."
                ])
        case .hasGuide(let id):
            let layer = finished.first { $0.guide.schedules[id]?.isEmpty == false }
            let name = layer?.guide.names[id] ?? context.channel.name
            let days = layer.map { setup.days($0.guide.days(from: context.now)) } ?? setup.days(0)
            let how =
                switch context.index.match(for: context.channel)?.origin {
                case .user: "Mapped by you"
                case .name: "Matched by name"
                case nil: "Matched by tvg-id"
                }
            return Card(title: Line("Guide from \(winner(id, context))"), body: ["“\(name)” (\(id)) · \(days) · \(how)"])
        }
    }

    private func winner(_ id: String, _ context: CardContext) -> String {
        let layers = context.index.sources[context.channel.sourceID ?? UUID()]?.layers ?? []
        return layers.first { $0.guide.schedules[id]?.isEmpty == false }.map { context.guideName($0.reference) } ?? "The guide"
    }

    /// "1 of 3 guides could not be downloaded." and "1 guide is still downloading."
    public func suffix(_ status: GuideSourceStatus) -> [String] {
        let total = status.rows.count(where: \.enabled)
        let counts = GuideDiagnosis.pending(status)
        var lines: [String] = []
        if counts.failed > 0 {
            lines.append("\(setup.count(counts.failed)) of \(setup.count(total)) guides could not be downloaded.")
        }
        if counts.downloading == 1 {
            lines.append("1 guide is still downloading.")
        } else if counts.downloading > 1 {
            lines.append("\(setup.count(counts.downloading)) guides are still downloading.")
        }
        return lines
    }
}
