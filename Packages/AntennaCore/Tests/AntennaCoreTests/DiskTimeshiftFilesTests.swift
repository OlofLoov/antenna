import Foundation
import Testing

@testable import AntennaCore

/// The buffer's files on disk, read from a thread of its own as the
/// demuxing thread does. Such a thread drains its
/// autorelease pool only when it ends, which for live TV is when the
/// channel changes.
@Suite struct DiskTimeshiftFilesTests {
    static let part = 1 << 20
    static let reads = 300

    @Test("playback-engine/live-playback-keeps-memory-steady bytes read back from the buffer do not pile up")
    func readsLetTheirBytesGo() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "disk-files-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appending(path: "0.ts")
        let files = DiskTimeshiftFiles()
        try files.create(file)
        try files.append(Data(repeating: 0x47, count: Self.part), to: file)

        // About 300 MB read back, as twenty minutes of an HD channel.
        let grown = try Self.onOwnThread {
            let before = Self.footprint()
            for _ in 0..<Self.reads {
                let data = try files.read(file, offset: 0, count: Self.part)
                guard data.count == Self.part else { throw TimeshiftFileError.failed }
            }
            return Self.footprint() - before
        }
        #expect(grown < 32 << 20, "grew \(grown >> 20) MB over \(Self.reads) reads of 1 MB")
    }

    /// Runs `body` on a new thread with no pool of its own around it, and
    /// returns its result once the thread is done with it.
    static func onOwnThread(_ body: @escaping @Sendable () throws -> Int) throws -> Int {
        let done = DispatchSemaphore(value: 0)
        nonisolated(unsafe) var result: Result<Int, any Error> = .success(0)
        let thread = Thread {
            result = Result(catching: body)
            done.signal()
        }
        thread.start()
        done.wait()
        return try result.get()
    }

    /// The process's physical footprint, the figure jetsam acts on.
    static func footprint() -> Int {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let status = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return status == KERN_SUCCESS ? Int(info.phys_footprint) : 0
    }
}
