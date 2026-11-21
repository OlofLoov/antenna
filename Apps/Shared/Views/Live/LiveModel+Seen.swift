import AntennaCore
import Foundation

/// The seen-channel record (new-channels), kept off a source load's way to the tune.
extension LiveModel {
    /// Writes what the device has seen of `id`'s channels after they show,
    /// then lists the New group from it
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
            seenChanges += 1
            await showNew()
        }
        records[id] = (ticket, task)
    }

    /// The channels `id` loaded, nil before its first load.
    func loadedChannels(of id: UUID) -> [Channel]? {
        channelsBySource[id]
    }
}
