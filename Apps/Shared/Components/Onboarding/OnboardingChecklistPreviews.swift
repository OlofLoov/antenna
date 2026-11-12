import SwiftUI

/// Fixture lines for the checklist and summary previews, with the boards' numbers.
private enum Fixture {
    typealias Line = OnboardingChecklist.Line

    static let signedIn = Line(id: "login", state: .done, title: "Signed in", detail: "Account active until 14 March 2027 · 2 connections")
    static let playlist = Line(id: "playlist", state: .done, title: "Playlist downloaded", detail: "tv.example-provider.net")
    static let channelsTV = Line(
        id: "channels", state: .done, title: "412 live channels in 18 groups",
        detail: "Sport, News, Movies, Series, Kids, Documentary, Music, Local and 10 more")
    static let channelsPhone = Line(id: "channels", state: .done, title: "412 live channels", detail: "18 groups")
    static let noLive = Line(id: "channels", state: .muted, title: "No live channels")
    static let noChannels = Line(id: "channels", state: .failed, title: "No channels found")
    static let movies = Line(
        id: "movies", state: .done, title: "1 240 movies and 86 series", detail: "Posters and descriptions load as you browse")
    static let moviesPhone = Line(id: "movies", state: .done, title: "1 240 movies and 86 series", detail: "In the Movies tab")
    static let downloading = Line(id: "guide", state: .running, title: "Downloading the guide · 2,4 MB", bar: .indeterminate)
    static let guideLoaded = Line(id: "guide", state: .done, title: "Guide for 7 days · 388 of 412 channels", bar: .full)

    static let tiles = [
        OnboardingSummary.Tile(id: "channels", value: "412", caption: "live channels · 18 groups"),
        OnboardingSummary.Tile(id: "guide", value: "7 days", caption: "of guide · 388 channels"),
        OnboardingSummary.Tile(id: "movies", value: "1 326", caption: "movies and series"),
        OnboardingSummary.Tile(id: "catchUp", value: "7 days", caption: "of catch-up on 212 channels"),
    ]

    static let note = "Synced through iCloud. Antenna on Apple TV, iPad and Mac shows this source on its own."
    @MainActor static var actions: OnboardingChecklist.Actions { .init(primary: {}, addAnother: {}) }
}

#Preview("Checklist, iPhone, loading") {
    OnboardingChecklist.Phone(
        headline: "You're set", subtitle: "Everything below is loading. The guide finishes in the background while you watch.",
        sections: [.init(id: "a", lines: [Fixture.signedIn, Fixture.channelsPhone, Fixture.moviesPhone, Fixture.downloading])],
        footnote: Fixture.note, primary: .startWatching(enabled: true), actions: Fixture.actions)
}

#Preview("Checklist, iPhone, no live channels") {
    OnboardingChecklist.Phone(
        headline: "You're set", subtitle: "Everything below is loading. The guide finishes in the background while you watch.",
        sections: [.init(id: "a", lines: [Fixture.signedIn, Fixture.noLive, Fixture.moviesPhone, Fixture.downloading])],
        footnote: Fixture.note, primary: .browseMovies, actions: Fixture.actions)
}

#Preview("Checklist, iPhone, nothing to watch") {
    OnboardingChecklist.Phone(
        headline: "Nothing to watch yet", subtitle: "The playlist has no channels. Go back and check the link.",
        sections: [.init(id: "a", lines: [Fixture.playlist, Fixture.noChannels, Fixture.downloading])],
        footnote: Fixture.note, primary: .startWatching(enabled: false), actions: .init(primary: {}, addAnother: nil))
}

#Preview("Checklist, iPhone, two sources") {
    OnboardingChecklist.Phone(
        headline: "You're set", subtitle: "Everything below is loading. The guide finishes in the background while you watch.",
        sections: [
            .init(
                id: "a", title: "Home provider",
                lines: [Fixture.signedIn, Fixture.channelsPhone, Fixture.moviesPhone, Fixture.downloading]),
            .init(
                id: "b", title: "Holiday flat",
                lines: [
                    Fixture.playlist, .init(id: "channels", state: .done, title: "96 live channels", detail: "6 groups"),
                    .init(id: "guide", state: .running, title: "Reading the guide…", bar: .indeterminate),
                ]),
        ],
        footnote: Fixture.note, primary: .startWatching(enabled: true), actions: Fixture.actions)
}

#Preview("Checklist, Apple TV", traits: .fixedLayout(width: 1920, height: 1080)) {
    OnboardingChecklist.Television(
        title: "Setting up Home provider", lines: [Fixture.signedIn, Fixture.channelsTV, Fixture.movies, Fixture.downloading],
        primary: .startWatching(enabled: true), caption: "The guide keeps loading behind the picture", start: {})
}

#Preview("Checklist, Apple TV, no live channels", traits: .fixedLayout(width: 1920, height: 1080)) {
    OnboardingChecklist.Television(
        title: "Setting up Home provider", lines: [Fixture.signedIn, Fixture.noLive, Fixture.movies, Fixture.downloading],
        primary: .browseMovies, caption: nil, start: {})
}

#Preview("Checklist, Apple TV, nothing to watch", traits: .fixedLayout(width: 1920, height: 1080)) {
    OnboardingChecklist.Television(
        title: "Setting up Home provider", lines: [Fixture.playlist, Fixture.noChannels, Fixture.downloading],
        primary: .startWatching(enabled: false), caption: "Press Menu to go back and check the link", start: {})
}

#Preview("Summary, Apple TV", traits: .fixedLayout(width: 1920, height: 1080)) {
    OnboardingSummary.Television(
        eyebrow: "Home provider added", tiles: Fixture.tiles, liveCaption: "Live · 101 Eurosport 1",
        footnote: "The source syncs through iCloud to iPhone, iPad and Mac. The login stays on this Apple TV.",
        primary: .startWatching(enabled: true), actions: Fixture.actions
    ) {
        Color.clear
    }
}

#Preview("Summary, Apple TV, two sources", traits: .fixedLayout(width: 1920, height: 1080)) {
    OnboardingSummary.Television(
        eyebrow: "Home provider · Holiday flat",
        tiles: [.init(id: "channels", value: "508", caption: "live channels · 24 groups")] + Fixture.tiles.dropFirst(),
        liveCaption: "Live · 101 Eurosport 1",
        footnote: "The sources sync through iCloud to iPhone, iPad and Mac. The login stays on this Apple TV.",
        primary: .startWatching(enabled: true), actions: Fixture.actions
    ) {
        Color.clear
    }
}
