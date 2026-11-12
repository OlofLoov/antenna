#if os(tvOS)
    import AntennaCore
    import Foundation

    /// Playing what a Top Shelf tile names (tvos-shell/play-or-resume-from-a-shelf-link).
    extension ShellModel {
        /// What a held shelf item turned out to be.
        enum ShelfResolution: Equatable {
            /// Still waiting for a source.
            case waiting
            /// The channel is tuned and Live shows.
            case tuned(Channel)
            /// A movie or series to resume; the caller plays it.
            case resume(ShelfTitle)
            /// Nothing matches; the shell carries on as it would without it.
            case dropped
        }

        /// Holds the shelf item `id` until a loaded channel or title matches
        /// it, or the launch deadline passes. While held, the launch tune of
        /// the last channel waits, so a link at launch loads one channel.
        func holdShelfItem(_ id: UUID) {
            shelfItem = id
            let sleep = dependencies.sleep
            Task { [weak self] in
                do {
                    try await sleep(Self.launchDeadline)
                } catch {
                    return
                }
                guard let self, shelfItem == id else { return }
                dropShelfItem()
            }
        }

        /// Matches the held item against the loaded channels, then `titles`.
        /// A channel plays as after going to Live; a title is handed back to
        /// resume. With no match, the item drops once no source is loading
        /// and `titlesPending` is false.
        @discardableResult
        func resolveShelfItem(titles: [ShelfTitle], titlesPending: Bool) -> ShelfResolution {
            guard let id = shelfItem else { return .dropped }
            if let channel = channels.first(where: { TopShelfItemID.channel($0) == id }) {
                shelfItem = nil
                settingsOpen = false
                // Tuned now, so no launch tune slips in before it.
                if channel != tuned { tune(channel) }
                Task { await showLive() }
                return .tuned(channel)
            }
            if let title = titles.first(where: { TopShelfItemID.title($0) == id }) {
                dropShelfItem()
                return .resume(title)
            }
            guard !sources.contains(where: { $0.state == .loading }), !titlesPending else { return .waiting }
            dropShelfItem()
            return .dropped
        }

        /// Lets go of the held item; the launch tune goes ahead if it was waiting.
        func dropShelfItem() {
            shelfItem = nil
            considerTune()
        }
    }
#endif
