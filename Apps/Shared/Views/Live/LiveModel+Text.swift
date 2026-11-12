import AntennaCore
import Foundation

extension LiveModel {
    /// What the now-playing line and the details say about `channel` at `date`.
    func nowText(for channel: Channel, at date: Date) -> LiveNowText {
        let panel = programmes.panel(for: channel, at: date)
        return LiveNowText(
            channel: channel.name, number: RowKey(channel).flatMap(catalogue.number(for:)), state: programmes.state(channel),
            current: panel.now, next: panel.next, now: date, time: Self.time)
    }

    /// A programme's start or end in the user's locale.
    static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}

extension LiveModel.Dependencies {
    /// The engine, loader, Keychain check and guide the app runs on.
    /// The language picks are `profile`'s on this device.
    @MainActor static func live(loader: SourceLoader, guide: AppGuideStore?, profile: UUID = Profile.mainID) -> Self {
        .init(
            engine: RoutedEngine.app(),
            load: { try await loader.load($0) },
            hasLogin: { loader.hasLogin($0) },
            guide: guide,
            programmes: .store(guide),
            languages: ChannelLanguageStore(profile: profile),
            recents: RecentsStore(profile: profile))
    }
}
