#if DEBUG
    import AntennaCore
    import Foundation

    /// An Xtream channel that can go to AirPlay as HLS, for the Live
    /// screen's UI tests, compiled into Debug builds only
    /// (playback-engine/a-channel-goes-to-airplay-as-hls).
    ///
    /// `UITESTING_XTREAM_HLS=1` makes Cabin Film an Xtream channel at
    /// `5.ts`, whose source offers HLS (`5.m3u8`); `=ts-only` makes its
    /// source offer MPEG-TS alone. It plays through a routed engine with a
    /// scripted engine on each route. The sound route is scripted too: the
    /// probe's `browse.debug.airPlayRoute` button switches it between the
    /// device and an AirPlay device, and the picture counts as on AirPlay
    /// while the route is AirPlay and Apple's player's engine plays.
    extension UITestingLive {
        static let xtreamHLSVariable = "UITESTING_XTREAM_HLS"
        static var xtreamHLS: Bool { ProcessInfo.processInfo.environment[xtreamHLSVariable] != nil }
        static var xtreamOffersHLS: Bool { ProcessInfo.processInfo.environment[xtreamHLSVariable] == "1" }

        /// Cabin's channels: Cabin Film as an Xtream channel with `UITESTING_XTREAM_HLS`, `cabin` otherwise.
        static var cabinChannels: [Channel] {
            guard xtreamHLS else { return cabin }
            return [
                Channel(
                    id: XtreamTitleID(host: "fixture", kind: .live, rawID: 5).description, name: "Cabin Film",
                    streamURL: URL(fileURLWithPath: "/fixture/live/u/p/5.ts"), group: "Films", number: 5)
            ]
        }

        /// The scripted AirPlay route: true while it is an AirPlay device.
        @MainActor static let airPlayRoute = Broadcast(false)

        /// The Live screen's engine: `scripted` alone, a routed engine with
        /// `scripted` on both routes for multi-view, or with
        /// `UITESTING_XTREAM_HLS` a second scripted engine on Apple's
        /// player's route.
        @MainActor static func liveEngine(_ scripted: Engine, log: URL?) -> any PlaybackEngine {
            if xtreamHLS { return RoutedEngine(system: Engine(log: log), demuxer: scripted) }
            return playsMultiView ? RoutedEngine(system: scripted, demuxer: scripted) : scripted
        }

        /// True with `UITESTING_MULTIVIEW`, which plays through a routed engine.
        static var playsMultiView: Bool { ProcessInfo.processInfo.environment[multiViewVariable] != nil }

        /// `dependencies` with the scripted route and AirPlay picture, and
        /// Cabin's HLS offer, with `UITESTING_XTREAM_HLS`.
        @MainActor static func scriptingAirPlay(_ dependencies: LiveModel.Dependencies) -> LiveModel.Dependencies {
            guard xtreamHLS, let system = (dependencies.engine as? RoutedEngine)?.system as? Engine else { return dependencies }
            XtreamHLSOffers.shared.loaded(cabinID, offersHLS: xtreamOffersHLS)
            var dependencies = dependencies
            dependencies.airPlayRoute = { airPlayRoute.stream() }
            dependencies.airPlay = {
                AsyncStream { continuation in
                    let task = Task { @MainActor in
                        for await state in await system.states() {
                            continuation.yield(airPlayRoute.value && state == .playing)
                        }
                    }
                    continuation.onTermination = { _ in task.cancel() }
                }
            }
            return dependencies
        }

        /// The scripted engine behind `engine`: itself, or for a routed
        /// engine the one on the route that plays now, Apple's player's
        /// while it is not idle.
        @MainActor static func scripted(_ engine: any PlaybackEngine) -> Engine? {
            if let engine = engine as? Engine { return engine }
            guard let routed = engine as? RoutedEngine else { return nil }
            let demuxer = routed.demuxer as? Engine
            if let system = routed.system as? Engine, system !== demuxer, system.state != .idle { return system }
            return demuxer
        }

        /// The sources whose HLS failed, in defaults emptied at launch, for
        /// any UI test launch; nil otherwise.
        static func failureStore(arguments: [String] = ProcessInfo.processInfo.arguments) -> HLSFailureStore? {
            guard arguments.contains(where: { $0.hasPrefix("-ui-testing") }) else { return nil }
            let suite = "ui-testing-hls-failures"
            let defaults = UserDefaults(suiteName: suite) ?? .standard
            defaults.removePersistentDomain(forName: suite)
            return HLSFailureStore(defaults: defaults)
        }
    }
#endif
