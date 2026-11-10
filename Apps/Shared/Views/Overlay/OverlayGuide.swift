#if os(tvOS)
    import AntennaCore
    import Foundation

    /// The guide the channel overlay reads: each channel's loading state and
    /// the programme on at a time. The app reads `AppGuideStore`; the shell's
    /// UI tests pass a scripted one.
    struct OverlayGuide {
        let state: @MainActor (Channel) -> GuideLoadingState
        let current: @MainActor (Channel, Date) -> Programme?

        /// What `channel`'s row says at `date`.
        @MainActor func line(for channel: Channel, at date: Date) -> GuideLine {
            GuideLine(state: state(channel), current: current(channel, date), now: date)
        }

        /// The app's guide store; with none, every channel has no guide.
        static func store(_ store: AppGuideStore?) -> OverlayGuide {
            OverlayGuide(
                state: { store?.loadingState(for: $0) ?? .unavailable },
                current: { channel, date in GuideKey(channel: channel).flatMap { store?.current(for: $0, at: date) } })
        }
    }
#endif
