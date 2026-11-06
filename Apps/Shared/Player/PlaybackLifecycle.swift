import AVFoundation
import AntennaCore
import Foundation

#if os(iOS) || os(tvOS)
    import UIKit
#endif

/// Pauses and resumes an engine around the app's life: leaving the app,
/// calls and other apps taking the sound, and headphones coming out. It
/// resumes only what it paused itself, so a pause the user made stands.
@MainActor
final class PlaybackLifecycle {
    private let engine: any PlaybackEngine
    private let continuesInBackground: @MainActor () -> Bool
    private let pausesInBackground: Bool
    private var pausedForBackground = false
    private var pausedForInterruption = false
    private var tokens: [any NSObjectProtocol] = []

    /// Leaving the app pauses on iPhone, iPad and Apple TV, not on a Mac.
    static var platformPausesInBackground: Bool {
        #if os(macOS)
            false
        #else
            true
        #endif
    }

    /// `continuesInBackground` says whether playback goes on after the app
    /// leaves the screen, in Picture in Picture or as background audio.
    init(
        engine: any PlaybackEngine,
        continuesInBackground: @escaping @MainActor () -> Bool = { false },
        pausesInBackground: Bool = PlaybackLifecycle.platformPausesInBackground
    ) {
        self.engine = engine
        self.continuesInBackground = continuesInBackground
        self.pausesInBackground = pausesInBackground
    }

    /// Sets the audio session for film playback and starts listening to the
    /// system. Call once, when the player appears.
    func start() {
        guard tokens.isEmpty else { return }
        #if os(iOS) || os(tvOS)
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playback, mode: .moviePlayback)
            let center = NotificationCenter.default
            let background: @Sendable (Notification) -> Void = { [weak self] _ in
                MainActor.assumeIsolated { self?.run { await $0.enteredBackground() } }
            }
            let active: @Sendable (Notification) -> Void = { [weak self] _ in
                MainActor.assumeIsolated { self?.run { await $0.becameActive() } }
            }
            let interruption: @Sendable (Notification) -> Void = { [weak self] note in
                let event = Self.interruption(note.userInfo)
                MainActor.assumeIsolated { self?.run { await $0.handle(event) } }
            }
            let route: @Sendable (Notification) -> Void = { [weak self] note in
                let unplugged = Self.isOldDeviceUnavailable(note.userInfo)
                MainActor.assumeIsolated {
                    guard unplugged else { return }
                    self?.run { await $0.headphonesUnplugged() }
                }
            }
            tokens = [
                center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main, using: background),
                center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main, using: active),
                center.addObserver(forName: AVAudioSession.interruptionNotification, object: session, queue: .main, using: interruption),
                center.addObserver(forName: AVAudioSession.routeChangeNotification, object: session, queue: .main, using: route),
            ]
        #endif
    }

    /// Stops listening.
    func end() {
        tokens.forEach(NotificationCenter.default.removeObserver)
        tokens = []
    }

    private func run(_ body: @escaping @MainActor (PlaybackLifecycle) async -> Void) {
        Task { await body(self) }
    }

    // MARK: Events

    /// What an interruption notification says.
    enum Interruption: Sendable, Equatable {
        case began
        case ended(shouldResume: Bool)
        case unknown
    }

    /// The app left the screen. Playback pauses unless it goes on in
    /// Picture in Picture or as background audio; a stream still loading
    /// or reconnecting stops trying.
    func enteredBackground() async {
        guard pausesInBackground, !continuesInBackground() else { return }
        switch await engine.state {
        case .playing, .buffering, .loading, .reconnecting:
            await engine.pause()
            pausedForBackground = true
        case .idle, .paused, .ended, .failed:
            break
        }
    }

    /// The app is on screen again. Plays what leaving the app paused.
    func becameActive() async {
        guard pausedForBackground else { return }
        pausedForBackground = false
        await engine.play()
    }

    func handle(_ event: Interruption) async {
        switch event {
        case .began:
            switch await engine.state {
            case .playing, .buffering, .loading, .reconnecting:
                await engine.pause()
                pausedForInterruption = true
            case .idle, .paused, .ended, .failed:
                break
            }
        case .ended(let shouldResume):
            let resume = pausedForInterruption && shouldResume
            pausedForInterruption = false
            if resume { await engine.play() }
        case .unknown:
            break
        }
    }

    /// Headphones came out. Playback pauses and nothing resumes it.
    func headphonesUnplugged() async {
        pausedForBackground = false
        pausedForInterruption = false
        switch await engine.state {
        case .playing, .buffering, .loading, .reconnecting:
            await engine.pause()
        case .idle, .paused, .ended, .failed:
            break
        }
    }

    // MARK: Reading notifications

    #if os(iOS) || os(tvOS)
        nonisolated static func interruption(_ info: [AnyHashable: Any]?) -> Interruption {
            guard let raw = info?[AVAudioSessionInterruptionTypeKey] as? UInt,
                let type = AVAudioSession.InterruptionType(rawValue: raw)
            else { return .unknown }
            switch type {
            case .began:
                return .began
            case .ended:
                let options = (info?[AVAudioSessionInterruptionOptionKey] as? UInt).map(AVAudioSession.InterruptionOptions.init) ?? []
                return .ended(shouldResume: options.contains(.shouldResume))
            @unknown default:
                return .unknown
            }
        }

        nonisolated static func isOldDeviceUnavailable(_ info: [AnyHashable: Any]?) -> Bool {
            guard let raw = info?[AVAudioSessionRouteChangeReasonKey] as? UInt else { return false }
            return AVAudioSession.RouteChangeReason(rawValue: raw) == .oldDeviceUnavailable
        }
    #endif
}
