#if os(tvOS)
    import AntennaCore
    import Foundation

    // The small picture in the Guide follows the highlight (tv-guide-grid/the-small-picture-follows-the-highlight).
    extension ShellModel {
        static let guideRestDelay = Duration.milliseconds(700)

        struct GuideReturn {
            let channel: Channel?
        }

        /// The Guide's highlight moved to `channel`'s row, or off the rows
        /// when nil. Once it rests on one row for `guideRestDelay`, the small
        /// picture tunes that channel on the one engine, in place of the
        /// stream it had, so scrolling past rows tunes none of them.
        func guideHighlightMoved(to channel: Channel?) {
            guard channel != guideRest?.channel else { return }
            guideRest?.wait.cancel()
            guideRest = nil
            guard let channel else { return }
            let wait = Task { [weak self] in
                guard let self else { return }
                do {
                    try await dependencies.sleep(Self.guideRestDelay)
                } catch {
                    return
                }
                guard !Task.isCancelled, tab == .guide, multiView == nil else { return }
                preview(channel)
            }
            guideRest = (channel, wait)
        }

        /// Tunes the small picture to `channel`, remembering what played before.
        private func preview(_ channel: Channel) {
            guard channel != tuned else { return }
            if guideReturn == nil { guideReturn = GuideReturn(channel: tuned) }
            tune(channel, remember: false)
        }

        /// Select or Watch on the channel in the small picture keeps it: it
        /// becomes the last channel and starts counting as watched.
        func keepGuidePreview(_ channel: Channel) async {
            guard let back = guideReturn, channel == tuned else { return }
            guideReturn = nil
            await adoptTuned()
            if back.channel != channel { guidePicks += 1 }
        }

        /// Leaving the Guide any other way than select or Watch tunes back
        /// to what played before it opened. When nothing played, the
        /// channel in the small picture stays.
        func leaveGuide() async {
            guideRest?.wait.cancel()
            guideRest = nil
            guard let back = guideReturn else { return }
            guideReturn = nil
            guard back.channel != tuned else { return await adoptTuned() }
            if let channel = back.channel, channel.sourceID.map({ descriptors[$0] != nil }) ?? true {
                tune(channel)
            } else {
                await adoptTuned()
            }
        }

        private func adoptTuned() async {
            guard let tuned else { return }
            session.tuned(tuned)
            if let key = LastChannelKey(tuned) { session.store.write(key) }
            session.stateChanged(await engine.state)
        }
    }
#endif
