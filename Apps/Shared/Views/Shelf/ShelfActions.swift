import AntennaCore
import SwiftUI

/// What a poster or the banner does, given by the screen that hosts the section.
/// Two sets made for one section from the same objects are equal, so a
/// screen that makes them again on a redraw does not redraw the rows and
/// the banner that take them (movies-and-series-browsing/browsing-stays-responsive).
struct ShelfActions: Equatable {
    /// Plays the title, from the banner or from the poster in a row or grid.
    var play: @MainActor (ShelfTitle, TitleRoute.Origin) -> Void
    /// Opens the title's page (title-detail-and-episode-picker).
    var open: @MainActor (ShelfTitle, TitleRoute.Origin) -> Void
    var toggleMyList: @MainActor (ShelfTitle) -> Void
    var isOnMyList: @MainActor (ShelfTitle) -> Bool
    /// The section and the objects the closures act on.
    private var source: [ObjectIdentifier]
    private var kind: ShelfTitle.Kind

    /// The section `kind`'s actions: playing through `playback`, pages
    /// through `library` and My list through `activity`.
    @MainActor static func section(
        _ kind: ShelfTitle.Kind, library: ShelfLibrary, activity: ShelfActivity, playback: ShelfPlayback
    ) -> ShelfActions {
        ShelfActions(
            play: { title, origin in
                if case .poster = origin { library.playing(title, from: origin) }
                playback.play(title, library: library, activity: activity)
            },
            open: { library.openPage($0, from: $1, in: kind) },
            toggleMyList: { activity.toggleMyList($0) }, isOnMyList: { activity.isOnMyList($0) },
            source: [ObjectIdentifier(library), ObjectIdentifier(activity), ObjectIdentifier(playback)], kind: kind)
    }

    static func == (lhs: ShelfActions, rhs: ShelfActions) -> Bool {
        lhs.source == rhs.source && lhs.kind == rhs.kind
    }

    /// What selecting a poster in `row` does: a movie plays, a series
    /// opens its page (title-detail-and-episode-picker/open-a-series-page).
    @MainActor func select(_ title: ShelfTitle, in row: String) {
        switch title.kind {
        case .movie: play(title, .poster(row: row))
        case .series: open(title, .poster(row: row))
        }
    }

    /// What Trailer does on the title page and the banner, nil for no
    /// button. iPhone, iPad and Mac open the link outside the app. Apple TV
    /// has no browser, so there only a link to a video file or stream gets
    /// the button, and it plays in the app
    /// (title-detail-and-episode-picker/trailer,
    /// movies-and-series-browsing/rating-and-trailer-on-the-banner).
    @MainActor static func trailer(
        _ url: URL?, of title: ShelfTitle, playback: ShelfPlayback, openURL: OpenURLAction
    ) -> (() -> Void)? {
        guard let url else { return nil }
        #if os(tvOS)
            guard TrailerLink.playsInApp(url) else { return nil }
            return { playback.playTrailer(url, of: title) }
        #else
            return { openURL(url) }
        #endif
    }
}
