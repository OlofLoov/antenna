import Foundation

/// Where the app leaves the shelf summary and tile images for the Top
/// Shelf extension. The app writes, the extension reads. Tests use a fake.
public protocol TopShelfStoring: Sendable {
    /// The snapshot last written; nil when there is none or it cannot be read.
    func read() -> TopShelfSnapshot?
    /// The file URL of a tile named in the snapshot; nil when the file is missing.
    func tileURL(_ file: String) -> URL?
    /// Writes `tiles` (file name to PNG data), then `snapshot`, then deletes
    /// the tiles no longer written. A throw leaves the previous snapshot
    /// readable with its tiles.
    func write(snapshot: Data, tiles: [String: Data]) throws(TopShelfFolder.Failure)
}

/// The shelf files in a folder: `snapshot.json`, `empty.png` and `tiles/`.
public struct TopShelfFolder: TopShelfStoring {
    /// The App Group the Apple TV app and its Top Shelf extension share.
    public static let appGroup = "group.se.codecrave.antenna"
    static let snapshotFile = "snapshot.json"
    static let tilesFolder = "tiles"

    /// Why a write failed. Logs name the case only.
    public enum Failure: Error, Sendable, Equatable {
        /// The folder could not be created or listed.
        case unavailable
        /// A file could not be written, as when storage is full.
        case writeFailed
    }

    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    /// The folder in the shared App Group container; nil when the app is not
    /// signed with the App Group, as in a simulator build without signing.
    public static func shared() -> TopShelfFolder? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
            .map { TopShelfFolder(directory: $0.appending(path: "TopShelf", directoryHint: .isDirectory)) }
    }

    public func read() -> TopShelfSnapshot? {
        TopShelfSnapshot(data: try? Data(contentsOf: directory.appending(path: Self.snapshotFile)))
    }

    public func tileURL(_ file: String) -> URL? {
        guard !file.contains(".."), !file.hasPrefix("/") else { return nil }
        let url = directory.appending(path: file)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    public func write(snapshot: Data, tiles: [String: Data]) throws(Failure) {
        let manager = FileManager.default
        let tileDirectory = directory.appending(path: Self.tilesFolder, directoryHint: .isDirectory)
        do {
            try manager.createDirectory(at: tileDirectory, withIntermediateDirectories: true)
        } catch {
            throw .unavailable
        }
        do {
            for (file, data) in tiles {
                try data.write(to: directory.appending(path: file), options: .atomic)
            }
            // The rename inside an atomic write makes the new snapshot appear whole, last.
            try snapshot.write(to: directory.appending(path: Self.snapshotFile), options: .atomic)
        } catch {
            throw .writeFailed
        }
        let kept = Set(tiles.keys)
        let present = (try? manager.contentsOfDirectory(atPath: tileDirectory.path)) ?? []
        for name in present where !kept.contains("\(Self.tilesFolder)/\(name)") {
            try? manager.removeItem(at: tileDirectory.appending(path: name))
        }
    }
}
