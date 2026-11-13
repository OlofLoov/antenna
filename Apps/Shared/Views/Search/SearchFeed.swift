import AntennaCore
import SwiftUI

/// What picking a result or a recent search does. Each platform's screen
/// fills it in (search/pick-a-channel-or-title-to-watch, search/pick-a-programme).
struct SearchPicks {
    var channel: @MainActor (Channel) -> Void
    var programme: @MainActor (SearchResults.ProgrammeHit, Channel) -> Void
    var title: @MainActor (ShelfTitle) -> Void
}

/// What the result rows read, provided once by the Search screen.
struct SearchFeed {
    let model: SearchModel
    /// The loaded channel behind a result, nil once its source is gone.
    let channel: @MainActor (RowKey) -> Channel?
    /// The title of what is on a channel now, for its row's second line.
    let onNow: @MainActor (Channel, Date) -> String?
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

/// A channel result with its logo, highlight and what is on now.
struct SearchChannelResult: View {
    let hit: SearchResults.ChannelHit
    let index: Int
    @Environment(\.searchFeed) private var feed

    var body: some View {
        if let feed {
            let query = feed.model.results.query
            let channel = feed.channel(hit.id)
            let detail = SearchText.channelLine(hit, now: channel.flatMap { feed.onNow($0, feed.model.searchedAt) })
            SearchRow.Channel(
                name: hit.channel.name, nameRanges: query.highlights(in: hit.channel.name), detail: detail,
                detailRanges: hit.match == .group ? query.highlights(in: detail) : [], initials: Channel.initials(for: hit.channel.name),
                logo: channel?.logoURL
            ) {
                feed.pick(hit)
            }
            .environment(\.searchCursor, feed.model.cursor == .channel(hit.id))
            .accessibilityValue(feed.model.cursor == .channel(hit.id) ? "Keyboard focus" : "")
            .accessibilityIdentifier("search.result.channel.\(index)")
            .id(SearchItem.channel(hit.id))
        }
    }
}

/// A programme result: NOW or its start, title and channel line.
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
            SearchRow.Programme(
                lead: feed.text.lead(hit, now: feed.model.searchedAt), title: title,
                ranges: feed.model.results.query.highlights(in: title), detail: feed.text.detail(hit, now: feed.model.searchedAt),
                hasCatchup: hit.hasCatchup
            ) {
                feed.pick(hit)
            }
            .environment(\.searchCursor, feed.model.cursor == .programme(hit.id))
            .accessibilityValue(feed.model.cursor == .programme(hit.id) ? "Keyboard focus" : "")
            .accessibilityIdentifier("search.result.programme.\(index)")
            .id(SearchItem.programme(hit.id))
        }
    }
}

/// A movie or series result with its poster.
struct SearchTitleResult: View {
    let hit: SearchResults.TitleHit
    let index: Int
    @Environment(\.searchFeed) private var feed

    var body: some View {
        if let feed {
            SearchRow.Title(
                name: hit.title.name, ranges: feed.model.results.query.highlights(in: hit.title.name), isSeries: hit.title.kind == .series
            ) {
                feed.pick(hit)
            } poster: {
                ShelfView.PosterArt(name: hit.title.name, url: hit.title.posterURL)
            }
            .environment(\.searchCursor, feed.model.cursor == .title(hit.id))
            .accessibilityValue(feed.model.cursor == .title(hit.id) ? "Keyboard focus" : "")
            .accessibilityIdentifier("search.result.title.\(index)")
            .id(SearchItem.title(hit.id))
        }
    }
}

/// What shows under the field when there are no rows: nothing for one
/// letter, "Channels are still loading", or no results with the hint
/// (search/nothing-found). Nil when there are rows to show.
@MainActor
func searchMessage(_ model: SearchModel) -> (title: String, lines: [String])? {
    let results = model.results
    guard results.query.isSearchable, results.isEmpty, results.query.text == SearchQuery(model.query).text else { return nil }
    if model.sources == .loading { return (SearchText.channelsLoading, []) }
    let lines = [SearchText.hint] + (model.sources == .partial ? [SearchText.someStillLoading] : [])
    return (SearchText.noResults(results.query), lines)
}
