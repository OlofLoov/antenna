@preconcurrency import AVFoundation
import CoreMedia
import Foundation

/// Sample buffers on their way from the demuxing thread to one renderer.
///
/// `push` blocks the demuxing thread while `limit` buffers wait, so FFmpeg
/// reads no further ahead than the renderer can take. The renderer pulls on
/// its own queue whenever it is ready for more. `close` wakes a blocked
/// `push`, drops what waits and flushes the renderer.
final class SampleFeed: @unchecked Sendable {
    let renderer: any AVQueuedSampleBufferRendering
    private let limit: Int
    private let condition = NSCondition()
    private let queue: DispatchQueue
    private var waiting: [CMSampleBuffer] = []
    private var closed = false
    private var discarding = false

    /// The presentation time of the last buffer the renderer took.
    private(set) var lastEnqueued: CMTime = .invalid

    init(renderer: any AVQueuedSampleBufferRendering, label: String, limit: Int) {
        self.renderer = renderer
        self.limit = limit
        queue = DispatchQueue(label: "se.codecrave.antenna.demux.\(label)")
    }

    /// Starts handing buffers to the renderer.
    func start() {
        renderer.requestMediaDataWhenReady(on: queue) { [weak self] in
            self?.drain()
        }
    }

    /// Queues `buffer`. Returns false once the feed is closed.
    @discardableResult
    func push(_ buffer: CMSampleBuffer) -> Bool {
        condition.lock()
        if discarding {
            condition.unlock()
            return true
        }
        while waiting.count >= limit, !closed {
            condition.wait()
        }
        guard !closed else {
            condition.unlock()
            return false
        }
        waiting.append(buffer)
        condition.unlock()
        queue.async { [weak self] in self?.drain() }
        return true
    }

    /// Drops every buffer from now on without blocking the demuxing thread,
    /// as when the renderer no longer plays.
    func discard() {
        condition.lock()
        discarding = true
        waiting.removeAll()
        condition.broadcast()
        condition.unlock()
        renderer.stopRequestingMediaData()
        queue.sync { renderer.flush() }
    }

    /// Stops feeding, drops what waits and flushes the renderer.
    func close() {
        condition.lock()
        closed = true
        waiting.removeAll()
        condition.broadcast()
        condition.unlock()
        renderer.stopRequestingMediaData()
        queue.sync { renderer.flush() }
    }

    private func drain() {
        while renderer.isReadyForMoreMediaData {
            condition.lock()
            guard !closed, !waiting.isEmpty else {
                condition.unlock()
                return
            }
            let buffer = waiting.removeFirst()
            condition.broadcast()
            condition.unlock()
            renderer.enqueue(buffer)
            lastEnqueued = CMSampleBufferGetPresentationTimeStamp(buffer)
        }
    }
}
