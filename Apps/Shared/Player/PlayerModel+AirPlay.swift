import AntennaCore
import Foundation

/// AirPlay for live channels (playback-engine/a-channel-goes-to-airplay-as-hls,
/// playback-engine/a-source-whose-hls-failed-cannot-airplay). An Xtream
/// channel plays as MPEG-TS on the device and moves to its HLS link on
/// Apple's player only once an AirPlay device is picked; the AirPlay button
/// decides on press whether the list can open.
extension PlayerModel {
    /// "AirPlay not available for this stream".
    static var airPlayUnavailableText: String { String(localized: "AirPlay not available for this stream") }

    /// True while the channel playing can go to AirPlay: it plays on Apple's
    /// player, or it has an HLS link its source can send.
    var airPlayPossible: Bool {
        _ = hlsRefusals
        return route == .system || subject.map { canSendHLS($0.channel) } == true
    }

    /// True while the next tune of the channel playing goes as HLS for AirPlay.
    var tunesForAirPlay: Bool { handoff.wantsHLS }

    /// The AirPlay button was pressed where the list cannot open.
    func airPlayRefused() {
        timeshift.say(Self.airPlayUnavailableText)
    }

    func airPlayListClosed() {
        airPlayChanged(.pickerClosed)
    }

    func canSendHLS(_ channel: Channel) -> Bool {
        dependencies.failures.hlsAddress(for: channel, offers: dependencies.offers) != nil
    }

    /// Follows the sound route until the calling task ends.
    func observeAirPlayRoute() async {
        let updates = dependencies.airPlayRoute?() ?? AirPlayRouteWatch.system()
        for await airPlay in updates {
            airPlayChanged(.route(airPlay: airPlay))
        }
    }

    /// Follows the routed engine's fallbacks until the calling task ends. A
    /// fallback means the HLS link did not start: its source is kept as
    /// unable to go to AirPlay and the message shows.
    func observeHLSFallbacks() async {
        guard let routed = engine as? RoutedEngine else { return }
        for await fallback in await routed.fallbacks() {
            guard let fallback else { continue }
            if let source = fallback.source { dependencies.failures.record(source) }
            hlsRefusals += 1
            airPlayChanged(.hlsFailed)
        }
    }

    func airPlayTuned(_ channel: Channel?) {
        run(handoff.tuned(canSendHLS: channel.map(canSendHLS) ?? false))
    }

    func airPlayChanged(_ event: AirPlayHandoff.Event) {
        run(handoff.handle(event, canSendHLS: subject.map { canSendHLS($0.channel) } ?? false))
    }

    private func run(_ steps: [AirPlayHandoff.Step]) {
        for step in steps {
            switch step {
            case .playHLS, .playTransportStream:
                handoffWait?.cancel()
                if let subject { reload(subject.channel) }
            case .prepareHLS:
                let link = subject.flatMap { dependencies.failures.hlsAddress(for: $0.channel, offers: dependencies.offers) }
                prepare(link)
            case .dropPreparedHLS:
                prepare(nil)
            case .wait:
                handoffWait?.cancel()
                let wait = dependencies.airPlayWait
                handoffWait = Task { [weak self] in
                    do { try await self?.dependencies.sleep(wait) } catch { return }
                    guard !Task.isCancelled else { return }
                    self?.airPlayChanged(.waitEnded)
                }
            case .sayUnavailable:
                airPlayRefused()
            }
        }
    }

    private func prepare(_ link: URL?) {
        if let prepareHLS = dependencies.prepareHLS {
            prepareHLS(link)
        } else {
            engine.prepareForAirPlay(link)
        }
    }
}
