#if os(tvOS)
    import AntennaCore
    import Foundation

    extension ShellModel {
        /// Loads the tuned channel again with a new buffer: the engine
        /// stops, which deletes the old one, and the channel tunes at live.
        func restartWithNewBuffer() {
            guard let tuned else { return }
            Task {
                await engine.stop()
                load(tuned)
            }
        }

        /// Tells the player which programme Start over would restart and
        /// how to ask for its catch-up.
        func wireStartOver() {
            let timeshift = player.timeshift
            timeshift.restartChannel = { [weak self] in self?.restartWithNewBuffer() }
            var guide = OverlayGuide.store(dependencies.guide)
            #if DEBUG
                if let scripted = UITestingShell.guide() { guide = scripted }
            #endif
            timeshift.nowPlaying = { [weak self] in
                guard let self, let tuned else { return nil }
                return (tuned, guide.panel(for: tuned, at: .now).now)
            }
            timeshift.catchupAddress = { [weak self] channel, request in
                guard let self else { return nil }
                let source = channel.sourceID.flatMap { descriptors[$0] }
                return await dependencies.catchup.url(for: channel, source: source, request: request)
            }
        }
    }
#endif
