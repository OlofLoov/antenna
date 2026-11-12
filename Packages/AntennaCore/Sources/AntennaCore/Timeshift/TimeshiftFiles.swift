import Foundation

/// The file operations the buffer makes, so tests can make a write or a
/// read fail partway.
public protocol TimeshiftFiles: Sendable {
    /// Creates an empty file, replacing any file there.
    func create(_ url: URL) throws
    func append(_ data: Data, to url: URL) throws
    /// Up to `count` bytes from `offset`; empty at the end of the file.
    func read(_ url: URL, offset: Int, count: Int) throws -> Data
    func remove(_ url: URL)
}

/// Why a buffer file operation failed.
public enum TimeshiftFileError: Error, Sendable, Equatable {
    /// The device has no space left.
    case noSpace
    case failed
}

/// The buffer's files on this device's disk.
public struct DiskTimeshiftFiles: TimeshiftFiles {
    public init() {}

    public func create(_ url: URL) throws {
        guard FileManager.default.createFile(atPath: url.path, contents: nil) else { throw TimeshiftFileError.failed }
    }

    public func append(_ data: Data, to url: URL) throws {
        do {
            let handle = try FileHandle(forWritingTo: url)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } catch let error as CocoaError where error.code == .fileWriteOutOfSpace {
            throw TimeshiftFileError.noSpace
        } catch let error as NSError where error.domain == NSPOSIXErrorDomain && error.code == Int(ENOSPC) {
            throw TimeshiftFileError.noSpace
        } catch {
            throw TimeshiftFileError.failed
        }
    }

    public func read(_ url: URL, offset: Int, count: Int) throws -> Data {
        do {
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            try handle.seek(toOffset: UInt64(offset))
            return try handle.read(upToCount: count) ?? Data()
        } catch {
            throw TimeshiftFileError.failed
        }
    }

    public func remove(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}
