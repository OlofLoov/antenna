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
    /// - `fail-<reason>`: the first load fails with `<reason>` (`offline`,
    ///   `notFound`, `loginNotOnDevice`, `notAllowed`, `unreadable`), later
    ///   loads play. With `fail-offline` the connection is gone at launch
    ///   and returns `UITESTING_NETWORK_SECONDS` seconds later, 3 unless set.
    ///
    /// `UITESTING_SLOW_SECONDS` sets how long the spinner shows before it
    /// names the source as slow, 10 unless set.
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

        /// The state a load leaves the engine in, or the failure it throws.
        /// `loads` counts this load.
        static func afterLoad(_ loads: Int) -> Result<PlaybackState, PlaybackFailure> {
            if case .fail(let reason) = script, loads == 1 { return .failure(reason) }
            return .success(.loading)
        }

        /// False while the script keeps every stream loading.
        static var plays: Bool { script != .stall }

        /// True when a playing stream drops a second after it starts.
        static var drops: Bool { script == .reconnect }
    }
#endif
