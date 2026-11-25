import AntennaCore
import SwiftUI

/// What picking a result or a recent search does. Each platform's screen
/// fills it in (search/pick-a-channel-or-title-to-watch, search/pick-a-programme).
struct SearchPicks {
    var channel: @MainActor (Channel) -> Void
    var programme: @MainActor (SearchResults.ProgrammeHit, Channel) -> Void
    var title: @MainActor (ShelfTitle) -> Void
    /// Opens the person's page over Search (browse-by-person/find-a-person-in-search).
    var person: @MainActor (PersonName) -> Void
}

/// What the result rows read, provided once by the Search screen.
struct SearchFeed {
    let model: SearchModel
    /// The loaded channel behind a result, nil once its source is gone.
    let channel: @MainActor (RowKey) -> Channel?
    /// What the Live list says is on a channel at a time, for its row.
    let line: @MainActor (Channel, Date) -> GuideLine
    let picks: SearchPicks
    /// Records the query as a recent search before a pick acts.
    let remember: @MainActor (String) -> Void
    let text: SearchText

    /// Remembers the query, then plays or opens the channel.
    @MainActor func pick(_ hit: SearchResults.ChannelHit) {
        guard let channel = channel(hit.id) else { return }
        remember(model.query)
        model.cursor = .channel(hit.id)
        picks.channel(channel)
    }

    @MainActor func pick(_ hit: SearchResults.ProgrammeHit) {
        guard let channel = channel(hit.channel.key) else { return }
        remember(model.query)
        model.cursor = .programme(hit.id)
        picks.programme(hit, channel)
    }

    @MainActor func pick(_ hit: SearchResults.TitleHit) {
        remember(model.query)
        model.cursor = .title(hit.id)
        picks.title(hit.title)
    }

    @MainActor func pick(_ person: PeopleIndex.Person) {
        remember(model.query)
        model.cursor = .person(person.key)
        picks.person(PersonName(key: person.key, display: person.name))
    }

    /// Picks the row the cursor is on (search/search-with-a-keyboard).
    @MainActor func pickCursor() {
        let results = model.results
        switch model.cursor {
        case .channel(let key):
            if let hit = results.channels.first(where: { $0.id == key }) { pick(hit) }
        case .programme(let id):
            if let hit = results.programmes.first(where: { $0.id == id }) { pick(hit) }
        case .title(let id):
            if let hit = results.titles.first(where: { $0.id == id }) { pick(hit) }
        case .person(let key):
            if let person = model.people.first(where: { $0.key == key }) { pick(person) }
        case nil:
            break
        }
    }
}

extension EnvironmentValues {
    @Entry var searchFeed: SearchFeed?
    /// Opens Search set to a kind with text carried over; nil where the
    /// sections offer no way into Search, as on Apple TV.
    @Entry var openSearch: SearchOpener?
}

/// What the Movies and Series sections call to open Search
/// (movies-and-series-browsing/search-from-the-section).
struct SearchOpener {
    let open: @MainActor (ShelfTitle.Kind, String) -> Void
}

/// A channel result as the channel list draws it: the Live list's row on
/// iPhone, iPad and Mac, the channel list's row on Apple TV, with the
/// highlight, the number after the name, what is on now and its progress
/// (search/results-grouped-best-first, design-system/channel-rows-share-one-anatomy).
struct SearchChannelResult: View {
    let hit: SearchResults.ChannelHit
    let index: Int
    @Environment(\.searchFeed) private var feed
    @Environment(\.locale) private var locale

    var body: some View {
        if let feed {
            let query = feed.model.results.query
            let channel = feed.channel(hit.id)
            let line = channel.map { feed.line($0, feed.model.searchedAt) }
            let detail = SearchText.channelRowLine(hit, line: line?.text ?? GuideLine.noProgramme(locale), locale: locale)
            let cursor = feed.model.cursor == .channel(hit.id)
            row(
                channel: channel, detail: detail, detailRanges: hit.match == .group ? query.highlights(in: detail) : [],
                progress: hit.match == .group ? nil : line?.progress, nameRanges: query.highlights(in: hit.channel.name)
            ) {
                feed.pick(hit)
            }
            .environment(\.searchCursor, cursor)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                "Channels, \(hit.channel.name), \(SearchText.channelLine(hit, now: line?.programmeTitle, locale: locale))"
            )
            .accessibilityAddTraits(.isButton)
            .accessibilityValue(cursor ? "Keyboard focus" : "")
            .accessibilityIdentifier("search.result.channel.\(index)")
            .id(SearchItem.channel(hit.id))
            .modifier(SearchReturnFocus(item: .channel(hit.id)))
        }
    }

    private var number: ChannelNumber? {
        hit.channel.number.map { ChannelNumber(major: $0, minor: hit.channel.minorNumber) }
    }

    private func row(
        channel: Channel?, detail: String, detailRanges: [Range<String.Index>], progress: Double?,
        nameRanges: [Range<String.Index>], select: @escaping () -> Void
    ) -> some View {
        let initials = Channel.initials(for: hit.channel.name)
        #if os(tvOS)
            return ChannelOverlay.ChannelRow(
                number: number, name: hit.channel.name, detail: detail, progress: progress,
                hasCatchUp: channel?.catchUpBadge != nil, identifier: "search.result.channel.\(index)", nameRanges: nameRanges,
                detailRanges: detailRanges, select: select
            ) {
                LogoImage(url: channel?.logoURL) { ChannelOverlay.Initials(text: initials) }
            }
        #else
            return Browse.ChannelRow(
                number: number, name: hit.channel.name, detail: detail, progress: progress,
                hasCatchUp: channel?.catchUpBadge != nil, isPlaying: false, nameRanges: nameRanges, detailRanges: detailRanges,
                select: select
            ) {
                Browse.Logo(url: channel?.logoURL, initials: initials, isSelected: false)
            }
            .modifier(SearchRow.CursorRing(shape: cornerShape(.medium)))
        #endif
    }
}

extension GuideLine {
    /// The bar's fraction while a programme is on, nil for a message.
    fileprivate var progress: Double? {
        if case .programme(_, let fraction, _) = self { return fraction }
        return nil
    }

    /// The programme's title, nil for a message.
    fileprivate var programmeTitle: String? {
        if case .programme(let title, _, _) = self { return title }
        return nil
    }
}

/// A programme result as the guide draws one: NOW or its start, title,
/// channel line and, on now, its progress.
struct SearchProgrammeResult: View {
    let hit: SearchResults.ProgrammeHit
    let index: Int
    @Environment(\.searchFeed) private var feed
    @Environment(\.reminders) private var reminders

    var body: some View {
        HStack(spacing: 0) {
            row
            bell
        }
    }

    /// The bell on a later programme, its own focus stop after the row on
    /// Apple TV (programme-reminders/remind-me-appears-only-before-a-programme-starts).
    @ViewBuilder private var bell: some View {
        if let reminders, let channel = offered(reminders) {
            SearchRow.Bell(isSet: reminders.isSet(hit.programme, on: channel)) {
                reminders.toggle(hit.programme, on: channel)
            }
            .accessibilityIdentifier("search.result.programme.\(index).remind")
        }
    }

    /// The programme's channel when it offers Remind me.
    private func offered(_ reminders: ReminderCenter) -> Channel? {
        guard let feed, let channel = feed.channel(hit.channel.key) else { return nil }
        return reminders.offers(hit.programme, on: channel, now: feed.model.searchedAt) ? channel : nil
    }

    @ViewBuilder private var row: some View {
        if let feed {
            let title = SearchText.programmeTitle(hit.programme)
            let now = feed.model.searchedAt
            SearchRow.Programme(
                lead: feed.text.lead(hit, now: now), title: title, ranges: feed.model.results.query.highlights(in: title),
                detail: feed.text.detail(hit, now: now), hasCatchup: hit.hasCatchup,
                progress: hit.isOnNow ? ProgrammeProgress.fraction(start: hit.programme.start, end: hit.programme.stop, now: now) : nil
            ) {
                feed.pick(hit)
            }
            .environment(\.searchCursor, feed.model.cursor == .programme(hit.id))
            .accessibilityValue(feed.model.cursor == .programme(hit.id) ? "Keyboard focus" : "")
            .accessibilityIdentifier("search.result.programme.\(index)")
            .id(SearchItem.programme(hit.id))
            .modifier(SearchReturnFocus(item: .programme(hit.id)))
        }
    }
}

/// A movie or series result: the Movies tab's poster card with its My list
/// menu, SERIES on a series, and the name with its highlight under it, as
/// under a Continue watching card. Selecting it opens the title's page
/// (search/pick-a-channel-or-title-to-watch).
struct SearchTitleResult: View {
    let hit: SearchResults.TitleHit
    let index: Int
    @Environment(\.searchFeed) private var feed
    @Environment(\.shelfMetrics) private var metrics
    @Environment(ShelfLibrary.self) private var library
    @Environment(ShelfActivity.self) private var activity

    var body: some View {
        if let feed {
            let title = hit.title
            let cursor = feed.model.cursor == .title(hit.id)
            VStack(alignment: .leading, spacing: metrics.headerSpacing * 0.6) {
                ShelfView.PosterCard(
                    title: title, label: spoken, badged: [.series], identifier: "search.result.title.\(index)"
                ) {
                    feed.pick(hit)
                }
                .contextMenu {
                    ShelfView.MyListMenuItem(isOnMyList: activity.isOnMyList(title)) { activity.toggleMyList(title) }
                }
                .environment(\.searchCursor, cursor)
                .modifier(SearchRow.PosterCursor())
                .accessibilityValue(cursor ? "Keyboard focus" : "")
                .modifier(SearchReturnFocus(item: .title(hit.id)))
                SearchRow.Highlighted(text: title.name, ranges: feed.model.results.query.highlights(in: title.name))
                    .font(.boardStyle(metrics.caption))
                    .foregroundStyle(Browse.textSecondary)
                    .lineLimit(1)
                    .frame(width: metrics.poster.width, alignment: .leading)
                    .accessibilityHidden(true)
            }
            .environment(\.shelfPrefix, "search")
            .id(SearchItem.title(hit.id))
        }
    }

    private var spoken: String {
        let name = hit.title.name
        return hit.title.kind == .series
            ? String(localized: "Movies & series, \(name), series") : String(localized: "Movies & series, \(name)")
    }
}

/// A person as a name in a title's cast: the title page's chip with the
/// highlight and "Acting · 9 in your sources" muted inside it.
struct SearchPersonResult: View {
    let person: PeopleIndex.Person
    let index: Int
    @Environment(\.searchFeed) private var feed
    @Environment(\.searchMetrics) private var metrics
    @Environment(\.locale) private var locale

    var body: some View {
        if let feed {
            let detail = person.page.countLine(locale: locale)
            let cursor = feed.model.cursor == .person(person.key)
            TitlePage.Chip(
                type: metrics.chips, name: person.name, nameRanges: feed.model.results.query.highlights(in: person.name)
            ) {
                feed.pick(person)
            } trailing: {
                Text(verbatim: detail)
            }
            .environment(\.searchCursor, cursor)
            .modifier(SearchRow.CursorRing(shape: Capsule()))
            .accessibilityLabel("People, \(person.name), \(detail)")
            .accessibilityValue(cursor ? "Keyboard focus" : "")
            .accessibilityIdentifier("search.person.\(index)")
            .id(SearchItem.person(person.key))
            .modifier(SearchReturnFocus(item: .person(person.key)))
        }
    }
}

/// Takes focus back on Apple TV when the user comes back to the row they
/// picked (search/pick-a-channel-or-title-to-watch). Elsewhere Search stays
/// under the page with its scroll position, so the row is still in view.
struct SearchReturnFocus: ViewModifier {
    let item: SearchItem
    @Environment(\.searchFeed) private var feed
    @FocusState private var focused: Bool

    func body(content: Content) -> some View {
        #if os(tvOS)
            content
                .focused($focused)
                .task(id: feed?.model.returning) {
                    guard let model = feed?.model, model.returning == item else { return }
                    await Task.yield()
                    focused = true
                    model.returned()
                }
        #else
            content
        #endif
    }
}

/// What shows under the field when there are no rows: nothing for one
/// letter, "Channels are still loading", or no results with the hint
/// (search/nothing-found). Nil when there are rows to show.
@MainActor
func searchMessage(_ model: SearchModel) -> SearchMessage? {
    let results = model.results
    guard results.query.isSearchable, model.foundNothing, results.query.text == SearchQuery(model.query).text else { return nil }
    if model.sources == .loading { return SearchMessage(symbol: "hourglass", title: SearchText.channelsLoading(), lines: []) }
    let lines = [SearchText.hint()] + (model.sources == .partial ? [SearchText.someStillLoading()] : [])
    return SearchMessage(
        symbol: "magnifyingglass", title: SearchText.noResults(results.query), lines: lines
    )
}

/// The symbol, title and lines of the status Search shows in place of rows,
/// already in the user's language.
struct SearchMessage: Equatable {
    var symbol: String
    var title: String
    var lines: [String]
}
