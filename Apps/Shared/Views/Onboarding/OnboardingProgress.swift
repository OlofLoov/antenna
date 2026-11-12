import AntennaCore
import Foundation

/// Turns the connected sources into checklist lines, summary tiles and the
/// main button, with the copy from the change's design
/// (first-run-onboarding/the-checklist-shows-real-progress,
/// first-run-onboarding/a-summary-when-everything-has-loaded).
@MainActor
struct OnboardingProgress {
    /// Which board's wording the lines use.
    enum Style {
        /// Apple TV: "412 live channels in 18 groups" over the group names.
        case television
        /// iPhone, iPad and Mac: "412 live channels" over "18 groups".
        case phone
    }

    let setups: [SourceSetup]
    var text = SetupText()
    /// The sources were signed in on this Apple TV rather than added.
    var signedIn = false

    // MARK: Lines

    func sections(_ style: Style) -> [OnboardingChecklist.Section] {
        setups.map { setup in
            OnboardingChecklist.Section(
                id: setup.id.uuidString, title: setups.count > 1 ? setup.name : nil, lines: lines(for: setup, style))
        }
    }

    func lines(for setup: SourceSetup, _ style: Style) -> [OnboardingChecklist.Line] {
        var lines: [OnboardingChecklist.Line] = []
        switch setup.connection.reply {
        case .account(let info):
            lines.append(
                .init(
                    id: "login", state: .done, title: "Signed in",
                    detail: text.account(expiry: info.expDate, connections: info.maxConnections)))
        case .playlist where setup.connection.descriptor.kind == .m3uFile:
            // local-m3u-file-import/import-during-onboarding
            lines.append(.init(id: "playlist", state: .done, title: "Playlist imported", detail: setup.connection.fileName))
        case .playlist:
            lines.append(.init(id: "playlist", state: .done, title: "Playlist downloaded", detail: setup.connection.descriptor.url.host()))
        }
        lines.append(channelsLine(setup, style))
        if let library = setup.library { lines.append(libraryLine(library, style)) }
        if let guide = guideLine(setup.guide) { lines.append(guide) }
        return lines
    }

    private func channelsLine(_ setup: SourceSetup, _ style: Style) -> OnboardingChecklist.Line {
        switch setup.channels {
        case .running:
            return .init(id: "channels", state: .running, title: "Loading channels…")
        case .done(let tally) where tally.channels > 0:
            switch style {
            case .television:
                return .init(id: "channels", state: .done, title: text.channels(tally), detail: text.groupNames(tally.groups))
            case .phone:
                return .init(
                    id: "channels", state: .done, title: text.liveChannels(tally.channels), detail: text.groups(tally.groups.count))
            }
        case .done, .failed:
            if setup.hasLibrary || setup.library == .running {
                return .init(id: "channels", state: .muted, title: "No live channels")
            }
            return .init(id: "channels", state: .failed, title: "No channels found")
        }
    }

    private func libraryLine(_ library: SourceSetup.Line<SourceSetup.Library?>, _ style: Style) -> OnboardingChecklist.Line {
        let detail = style == .phone ? "In the Movies tab" : "Posters and descriptions load as you browse"
        switch library {
        case .running:
            return .init(id: "movies", state: .running, title: "Loading movies and series…")
        case .done(let counts?) where counts.total > 0:
            return .init(id: "movies", state: .done, title: text.movies(counts.movies, series: counts.series), detail: detail)
        case .done(nil):
            return .init(id: "movies", state: .done, title: "Movies and series available", detail: detail)
        case .done, .failed:
            return .init(id: "movies", state: .muted, title: "No movies or series")
        }
    }

    private func guideLine(_ guide: SourceSetup.Guide) -> OnboardingChecklist.Line? {
        switch guide {
        case .none:
            nil
        case .waiting:
            .init(id: "guide", state: .running, title: "Downloading the guide", bar: .indeterminate)
        case .downloading(let bytes):
            .init(id: "guide", state: .running, title: text.downloading(bytes: bytes), bar: .indeterminate)
        case .reading:
            .init(id: "guide", state: .running, title: "Reading the guide…", bar: .indeterminate)
        case .loaded(let days, let matched, let total):
            .init(id: "guide", state: .done, title: text.guide(days: days, matched: matched, total: total), bar: .full)
        case .failed:
            .init(id: "guide", state: .failed, title: "Guide could not be loaded")
        }
    }

    // MARK: Buttons and headings

    /// Start watching once any source has live channels, Browse movies when
    /// none has and one has movies or series, and a disabled Start watching
    /// otherwise (first-run-onboarding/a-provider-with-no-live-channels).
    var primary: OnboardingChecklist.Primary {
        if setups.contains(where: \.hasLive) { return .startWatching(enabled: true) }
        if setups.contains(where: \.hasLibrary) && setups.allSatisfy({ $0.channels.isFinished }) { return .browseMovies }
        return .startWatching(enabled: false)
    }

    /// Every source finished with nothing to watch.
    var isEmpty: Bool { !setups.isEmpty && setups.allSatisfy(\.isEmpty) }

    /// The first channel of the first group of the first source with live channels.
    var firstChannel: Channel? {
        setups.lazy.compactMap { $0.channels.value?.firstChannel }.first
    }

    /// The sheet's title on iPhone, iPad and Mac.
    var title: String {
        setups.count > 1 ? "\(setups.count) sources added" : setups.first?.name ?? ""
    }

    /// The Apple TV eyebrow: "<name> added", the names joined by " · ".
    var eyebrow: String {
        setups.count > 1
            ? setups.map(\.name).joined(separator: " · ") : "\(setups.first?.name ?? "") \(signedIn ? "signed in" : "added")"
    }

    /// The Apple TV title while loading.
    var loadingTitle: String {
        "Setting up \(setups.last?.name ?? "")"
    }

    // MARK: Summary

    /// The Apple TV tiles: channels, guide, movies and catch-up, each left
    /// out when it is zero, failed or unknown. Counts add up across sources;
    /// guide and catch-up days take the larger value.
    var tiles: [OnboardingSummary.Tile] {
        var tiles: [OnboardingSummary.Tile] = []
        let tallies = setups.compactMap { $0.channels.value }
        let channels = tallies.map(\.channels).reduce(0, +)
        if channels > 0 {
            let groups = tallies.map(\.groups.count).reduce(0, +)
            tiles.append(.init(id: "channels", value: text.count(channels), caption: "live channels · \(text.groups(groups))"))
        }
        let guides = setups.compactMap { setup -> (days: Int, matched: Int)? in
            if case .loaded(let days, let matched, _) = setup.guide { return (days, matched) }
            return nil
        }
        let matched = guides.map(\.matched).reduce(0, +)
        if let days = guides.map(\.days).max(), days > 0, matched > 0 {
            tiles.append(.init(id: "guide", value: text.days(days), caption: "of guide · \(text.count(matched)) channels"))
        }
        let libraries = setups.compactMap { $0.library?.value }
        if !libraries.contains(where: { $0 == nil }) {
            let total = libraries.compactMap { $0?.total }.reduce(0, +)
            if total > 0 { tiles.append(.init(id: "movies", value: text.count(total), caption: "movies and series")) }
        }
        let catchUp = tallies.map(\.catchUpChannels).reduce(0, +)
        if catchUp > 0 {
            let days = tallies.compactMap(\.catchUpDays).max()
            tiles.append(
                .init(
                    id: "catchUp", value: days.map(text.days) ?? "Catch-up",
                    caption: "\(days == nil ? "on" : "of catch-up on") \(text.count(catchUp)) channels"
                ))
        }
        return tiles
    }

    /// "Live · 101 Eurosport 1" for the first channel, nil without one.
    var liveCaption: String? {
        guard let tally = setups.lazy.compactMap({ $0.channels.value }).first(where: { $0.firstChannel != nil }),
            let channel = tally.firstChannel
        else { return nil }
        return ["Live ·", tally.firstNumber.map(String.init), channel.name].compactMap(\.self).joined(separator: " ")
    }
}
