import Foundation
import Testing

@testable import AntennaCore

/// Session folders on disk, under a temporary root.
@Suite struct TimeshiftStoreTests {
    static func store() -> TimeshiftStore {
        TimeshiftStore(
            root: FileManager.default.temporaryDirectory.appending(path: "timeshift-\(UUID().uuidString)", directoryHint: .isDirectory))
    }

    @Test("timeshift-catch-up-and-start-over/changing-channel-starts-fresh: each session gets a new folder, excluded from backup")
    func newSession() throws {
        let store = Self.store()
        defer { try? FileManager.default.removeItem(at: store.root) }
        let first = try store.makeSession()
        let second = try store.makeSession()
        #expect(first != second)
        #expect(first.deletingLastPathComponent().standardizedFileURL == store.root.standardizedFileURL)
        #expect(UUID(uuidString: first.lastPathComponent) != nil)
        #expect(try first.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true)
    }

    @Test("timeshift-catch-up-and-start-over/changing-channel-starts-fresh: the old buffer moves away at once and is deleted later")
    func retire() async throws {
        let store = Self.store()
        defer { try? FileManager.default.removeItem(at: store.root) }
        let session = try store.makeSession()
        try Data(repeating: 1, count: 1 << 20).write(to: session.appending(path: "0.ts"))
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            store.retire(session) { done.resume() }
            // Gone from its place before `retire` returns.
            #expect(!FileManager.default.fileExists(atPath: session.path))
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: store.root.path).isEmpty)
    }

    @Test("timeshift-catch-up-and-start-over/changing-channel-starts-fresh: leftovers from an earlier run are deleted at launch")
    func leftovers() async throws {
        let store = Self.store()
        defer { try? FileManager.default.removeItem(at: store.root) }
        let old = try store.makeSession()
        try Data([1, 2, 3]).write(to: old.appending(path: "0.ts"))
        try FileManager.default.createDirectory(at: store.root.appending(path: "retired-x"), withIntermediateDirectories: true)
        var fresh: URL?
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            store.clearLeftovers { done.resume() }
            #expect(!FileManager.default.fileExists(atPath: old.path))
            // A session made right after launch is not swept up.
            fresh = try? store.makeSession()
        }
        let left = try FileManager.default.contentsOfDirectory(atPath: store.root.path)
        #expect(left == [fresh?.lastPathComponent].compactMap(\.self))
        // A root that was never made is fine.
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            Self.store().clearLeftovers { done.resume() }
        }
    }

    @Test("timeshift-catch-up-and-start-over/when-the-stream-cannot-be-recorded: free space is known for the store's volume")
    func freeSpace() {
        let store = Self.store()
        defer { try? FileManager.default.removeItem(at: store.root) }
        #expect((store.freeBytes() ?? 0) > 0)
    }

    @Test("timeshift-catch-up-and-start-over/changing-channel-starts-fresh: a buffer on disk writes and reads its chunks")
    func onDisk() throws {
        let store = Self.store()
        defer { try? FileManager.default.removeItem(at: store.root) }
        let clock = TestClock()
        let buffer = TimeshiftBuffer(directory: try store.makeSession(), limits: .standard(for: .mac), byteCap: 1 << 30, now: clock.reading)
        var scanner = TSStartPoints()
        buffer.record(scanner.scan(TSPackets.group(tag: 1)), pat: scanner.pat, pmt: scanner.pmt)
        clock.advance(2)
        buffer.record(scanner.scan(TSPackets.group(tag: 2)), pat: scanner.pat, pmt: scanner.pmt)
        buffer.finish()
        let reader = try #require(buffer.reader(at: .distantPast))
        let (data, _) = reader.drain(limit: 100_000)
        #expect(data == TSPackets.group(tag: 1) + TSPackets.pat + TSPackets.pmt + TSPackets.group(tag: 2))
        #expect(try FileManager.default.contentsOfDirectory(atPath: buffer.directory.path).sorted() == ["0.ts", "1.ts"])
    }
}
