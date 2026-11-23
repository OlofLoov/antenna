import AntennaCore
import Foundation

extension LiveModel {
    /// What the now-playing line and the details say about `channel` at
    /// `date`, with times written for `locale`.
    func nowText(for channel: Channel, at date: Date, locale: Locale) -> LiveNowText {
        let panel = programmes.panel(for: channel, at: date)
        return LiveNowText(
            channel: channel.name, number: RowKey(channel).flatMap(catalogue.channelNumber(for:)), state: programmes.state(channel),
            current: panel.now, next: panel.next, now: date, time: { Self.time($0, locale: locale) })
    }

    /// A programme's start or end, written for `locale`. Views pass their
    /// `@Environment(\.locale)`.
    nonisolated static func time(_ date: Date, locale: Locale) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(locale))
    }
}

extension LiveModel.Dependencies {
    /// The engine, loader, Keychain check and guide the app runs on.
    /// The language picks are `profile`'s on this device.
    /// With `refresher`, sources load through it one at a time and report their status.
    @MainActor static func live(
        loader: SourceLoader, guide: AppGuideStore?, profile: UUID = Profile.mainID, refresher: SourceRefresher? = nil
    ) -> Self {
        var dependencies = Self(
            engine: RoutedEngine.app(),
            load: { source in
                if let refresher { return try await refresher.load(source) }
                return try await loader.load(source)
            },
            hasLogin: { refresher?.hasLogin($0) ?? loader.hasLogin($0) },
            guide: guide,
            programmes: .store(guide),
            languages: ChannelLanguageStore(profile: profile),
            recents: RecentsStore(profile: profile))
        dependencies.seen = .app
        dependencies.launchLogins = { LaunchLogins(credentials: loader.credentials).logins(for: $0) }
        dependencies.waitsForICloud = { loader.waitsForICloud($0) }
        return dependencies
    }
}
