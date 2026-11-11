#if DEBUG
    import AntennaCore
    import Foundation

    /// How the scripted engines of `UITestingLive` and `UITestingShell`
    /// play, for the player's UI tests (player-controls-and-playback-errors
    /// capability). Compiled into Debug builds only.
    ///
    /// `UITESTING_PLAYBACK` in the launch environment picks a script:
    /// - `stall`: every load stays loading and never plays.
    /// - `reconnect`: a second after playing, the stream drops and the
    ///   engine reports attempt 2 of 3.
    /// - `fail-<reason>`: the first load of each stream fails with
    ///   `<reason>` (`offline`, `notFound`, `loginNotOnDevice`, `notAllowed`,
    ///   `unreadable`), later loads of it play. With `fail-offline` the
    ///   connection is gone at launch and returns `UITESTING_NETWORK_SECONDS`
    ///   seconds later, 3 unless set.
    ///
    /// `UITESTING_SLOW_SECONDS` sets how long the spinner shows before it
    /// names the source as slow, 10 unless set.
    ///
    /// Every stream has English, English commentary and an unnamed sound
    /// track and English subtitles, or one English sound track and no
    /// subtitles with `UITESTING_TRACKS=single`.
    enum UITestingPlayback {
        static let variable = "UITESTING_PLAYBACK"
        static let slowVariable = "UITESTING_SLOW_SECONDS"
        static let networkVariable = "UITESTING_NETWORK_SECONDS"

        enum Script: Equatable {
            case normal
            case stall
            case reconnect
            case fail(PlaybackFailure)
        }

        static var script: Script {
            guard let value = ProcessInfo.processInfo.environment[variable] else { return .normal }
            switch value {
            case "stall": return .stall
            case "reconnect": return .reconnect
            case "fail-offline": return .fail(.offline)
            case "fail-notFound": return .fail(.notFound)
            case "fail-loginNotOnDevice": return .fail(.loginNotOnDevice)
            case "fail-notAllowed": return .fail(.notAllowed)
            case "fail-unreadable": return .fail(.unreadable)
            default: fatalError("\(variable) takes stall, reconnect or fail-<reason>")
            }
        }

        static var slowDelay: Duration {
            .seconds(ProcessInfo.processInfo.environment[slowVariable].flatMap(Double.init) ?? 10)
        }

        /// Offline until a few seconds after launch with `fail-offline`,
        /// online otherwise.
        static var network: NetworkWatch {
            guard script == .fail(.offline) else { return .online }
            let seconds = ProcessInfo.processInfo.environment[networkVariable].flatMap(Double.init) ?? 3
            return NetworkWatch {
                AsyncStream { continuation in
                    continuation.yield(false)
                    let task = Task {
                        try? await Task.sleep(for: .seconds(seconds))
                        continuation.yield(true)
                    }
                    continuation.onTermination = { _ in task.cancel() }
                }
            }
        }

        /// The state a load of `file` leaves the engine in, or the failure
        /// it throws. With `fail-<reason>`, the first load of each file fails.
        @MainActor static func afterLoad(_ file: String) -> Result<PlaybackState, PlaybackFailure> {
            guard case .fail(let reason) = script, failed.insert(file).inserted else { return .success(.loading) }
            return .failure(reason)
        }

        @MainActor private static var failed: Set<String> = []

        /// The tracks every scripted stream has.
        static var tracks: TrackList {
            let english = MediaTrack(id: "audio-0", kind: .audio, languageCode: "en", name: nil, isDefault: true)
            guard ProcessInfo.processInfo.environment["UITESTING_TRACKS"] != "single" else {
                return TrackList(audio: [english], subtitles: [], selectedAudio: english.id, selectedSubtitle: nil)
            }
            return TrackList(
                audio: [
                    english,
                    MediaTrack(id: "audio-1", kind: .audio, languageCode: "en", name: "Commentary", isDefault: false),
                    MediaTrack(id: "audio-2", kind: .audio, languageCode: nil, name: nil, isDefault: false),
                ],
                subtitles: [MediaTrack(id: "subtitle-0", kind: .subtitle, languageCode: "en", name: nil, isDefault: false)],
                selectedAudio: english.id, selectedSubtitle: nil)
        }

        /// 1080p H.264 with 5.1 AAC sound.
        static let presentation = PresentationInfo(
            video: .init(width: 1920, height: 1080, frameRate: 25, dynamicRange: .sdr, codec: "h264"),
            audio: .init(codec: "aac", channels: 6, isDecodable: true))

        /// The tracks of one scripted engine; a pick changes the selection.
        final class Tracks: Sendable {
            let cast = Broadcast(UITestingPlayback.tracks)
            let format = Broadcast(PresentationInfo?.some(UITestingPlayback.presentation))

            /// A new stream opened: its tracks with the defaults picked, and its format.
            func reset() {
                cast.send(UITestingPlayback.tracks)
                format.send(UITestingPlayback.presentation)
            }

            func selectAudio(_ id: MediaTrack.ID) {
                var list = cast.value
                list.selectedAudio = id
                cast.send(list)
            }

            func selectSubtitle(_ id: MediaTrack.ID?) {
                var list = cast.value
                list.selectedSubtitle = id
                cast.send(list)
            }
        }

        /// False while the script keeps every stream loading.
        static var plays: Bool { script != .stall }

        /// True when a playing stream drops a second after it starts.
        static var drops: Bool { script == .reconnect }
    }
#endif
