#if DEBUG
    import AntennaCore
    import Foundation

    /// The guide Search reads in a Debug build launched for UI tests: the
    /// scripted programmes the Live and shell tests already show, gathered
    /// into a guide index. Compiled into Debug builds only.
    enum UITestingSearch {
        /// True when any UI testing launch argument is present.
        static var testing: Bool {
            ProcessInfo.processInfo.arguments.contains { $0.hasPrefix("-ui-testing-") }
        }

        /// Every programme `overlay` has for `channels` from `date` on, or nil
        /// outside UI tests. Each channel's source counts as loaded, with or
        /// without programmes.
        @MainActor
        static func guide(channels: [Channel], overlay: OverlayGuide, at date: Date) -> GuideIndex? {
            guard testing else { return nil }
            var bySource: [UUID: [Programme]] = [:]
            for channel in channels {
                guard let sourceID = channel.sourceID else { continue }
                bySource[sourceID, default: []] += []
                guard let key = GuideKey(channel: channel) else { continue }
                let list = [overlay.current(channel, date)].compactMap(\.self) + overlay.next(channel, date, 50)
                bySource[sourceID, default: []] += list.map { programme in
                    var copy = programme
                    copy.channelID = key.epgID
                    return copy
                }
            }
            return GuideIndex(programmes: bySource)
        }
    }
#endif
