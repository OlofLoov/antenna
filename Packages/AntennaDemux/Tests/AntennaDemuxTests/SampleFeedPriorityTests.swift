@preconcurrency import AVFoundation
import AntennaCore
import CoreMedia
import Foundation
import Testing

@testable import AntennaDemux

/// The demux thread runs at user-initiated priority and waits on the feed's
/// queue and on the stream's network callbacks. Both run at that priority
/// too, so the wait is not a priority inversion.
struct SampleFeedPriorityTests {
    @Test func theFeedHandsBuffersOverAtUserInitiatedPriority() async throws {
        let renderer = PriorityRecordingRenderer()
        let feed = SampleFeed(renderer: renderer, label: "test.priority", limit: 4)
        feed.start()
        #expect(feed.push(try Self.buffer()))
        for _ in 0..<200 where renderer.classes.isEmpty {
            try await Task.sleep(for: .milliseconds(10))
        }
        feed.close()
        #expect(renderer.classes.first == QOS_CLASS_USER_INITIATED)
    }

    @Test func theStreamingSessionDeliversAtUserInitiatedPriority() {
        let session = PlaybackNetwork.makeStreamingSession()
        #expect(session.delegateQueue.qualityOfService == .userInitiated)
        #expect(session.delegateQueue.maxConcurrentOperationCount == 1)
        #expect(session.configuration.urlCache == nil)
        #expect(session.configuration.httpCookieStorage == nil)
        #expect(session.configuration.urlCredentialStorage == nil)
        #expect(session.configuration.timeoutIntervalForRequest == 8)
    }

    static func buffer() throws -> CMSampleBuffer {
        var block: CMBlockBuffer?
        #expect(
            CMBlockBufferCreateWithMemoryBlock(
                allocator: nil, memoryBlock: nil, blockLength: 1, blockAllocator: nil, customBlockSource: nil,
                offsetToData: 0, dataLength: 1, flags: kCMBlockBufferAssureMemoryNowFlag, blockBufferOut: &block) == noErr)
        var buffer: CMSampleBuffer?
        var timing = CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: .zero, decodeTimeStamp: .invalid)
        var size = 1
        #expect(
            CMSampleBufferCreateReady(
                allocator: nil, dataBuffer: block, formatDescription: nil, sampleCount: 1, sampleTimingEntryCount: 1,
                sampleTimingArray: &timing, sampleSizeEntryCount: 1, sampleSizeArray: &size, sampleBufferOut: &buffer) == noErr)
        return try #require(buffer)
    }
}

/// A renderer that notes the priority each buffer reaches it at.
private final class PriorityRecordingRenderer: NSObject, AVQueuedSampleBufferRendering, @unchecked Sendable {
    private let lock = NSLock()
    private var seen: [qos_class_t] = []
    let timebase: CMTimebase

    override init() {
        var made: CMTimebase?
        CMTimebaseCreateWithSourceClock(allocator: nil, sourceClock: CMClockGetHostTimeClock(), timebaseOut: &made)
        guard let made else { preconditionFailure("No host clock timebase") }
        timebase = made
    }

    var classes: [qos_class_t] { lock.withLock { seen } }

    func enqueue(_ sampleBuffer: CMSampleBuffer) {
        let current = qos_class_self()
        lock.withLock { seen.append(current) }
    }

    func flush() {}
    var isReadyForMoreMediaData: Bool { true }
    // swiftlint:disable:next identifier_name
    var hasSufficientMediaDataForReliablePlaybackStart: Bool { true }
    func requestMediaDataWhenReady(on queue: DispatchQueue, using block: @escaping @Sendable () -> Void) {}
    func stopRequestingMediaData() {}
}
