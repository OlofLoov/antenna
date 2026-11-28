import AntennaCore
import SwiftUI

#if os(iOS)
    import UIKit
#endif

extension PlayDestination {
    /// What a control does for `item`; nil sends nothing.
    func actions(_ item: PlayOnItem?, openURL: OpenURLAction) -> PlayOnActions {
        PlayOnActions(
            opened: { [weak self] in self?.opened() },
            pick: { [weak self] id in
                guard let item else { return }
                Task { await self?.send(item, to: id) }
            },
            openSettings: { if let url = Self.settingsURL { openURL(url) } })
    }

    /// Antuna's page in Settings, where local network access is turned on.
    static var settingsURL: URL? {
        #if os(macOS)
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocalNetwork")
        #elseif os(iOS)
            URL(string: UIApplication.openSettingsURLString)
        #else
            nil
        #endif
    }

    /// The line for the TV's answer; none for a start while connected,
    /// where the bar already says what plays.
    static func notice(
        for result: PlayAnswer.Result, tv: String, item: PlayOnItem, locale: Locale, connected: Bool = false
    ) -> PlayOnNotice? {
        let text = PlayOnText.line(for: result, tv: tv, item: item.title, sourceName: item.sourceName, locale: locale)
        switch result {
        case .started: return connected ? nil : PlayOnNotice(text: text, kind: .sent)
        case .waiting, .canceled: return PlayOnNotice(text: text, kind: .sent)
        case .noLogin(let source): return PlayOnNotice(text: text, kind: .error, signIn: source)
        case .needsPasscode, .noSource, .notFound, .unsupportedVersion: return PlayOnNotice(text: text, kind: .error)
        }
    }
}
