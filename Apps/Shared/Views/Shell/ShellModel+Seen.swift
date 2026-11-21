#if os(tvOS)
    import AntennaCore
    import Foundation

    /// The seen-channel record (new-channels), kept off a source load's way to the launch tune.
    extension ShellModel {
        /// Writes what the device has seen of `id`'s channels after the
        /// launch tune, which the New group then lists
        /// (session-restore-and-recently-watched/the-last-channel-does-not-wait-for-bookkeeping).
        func record(_ id: UUID, _ channels: [Channel]) {
            records[id]?.task.cancel()
            recordTickets += 1
            let ticket = recordTickets
            let store = dependencies.seen
            let task = Task { [weak self] in
                let memory = await store.recording(id, channels: channels)
                guard let self else { return }
                defer { if records[id]?.ticket == ticket { records[id] = nil } }
                guard !Task.isCancelled, descriptors[id] != nil else { return }
                seen[id] = memory
            }
            records[id] = (ticket, task)
        }

        /// Waits until every seen-channel record is written. For tests.
        func recorded() async {
            while let next = records.values.first { await next.task.value }
        }
    }
#endif
