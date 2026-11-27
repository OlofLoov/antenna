#if DEBUG
    import AntennaCore
    import Foundation
    import Network

    /// Device records as JSON files in one folder, one per device, so two
    /// simulators on one Mac share an account (`-ui-testing-play-on-shared`).
    struct FilePlayDevices: PlayDeviceStoring {
        let folder: URL

        private struct Record: Codable {
            var id: UUID
            var kind: String
            var name: String
            var publicKey: Data
            var keyDate: Date
            var lastSeen: Date
            var created: Date?
        }

        func save(_ device: PlayDeviceInfo) throws(PlayOnStoreError) {
            let record = Record(
                id: device.id, kind: device.kind.rawValue, name: device.name, publicKey: device.publicKey, keyDate: device.keyDate,
                lastSeen: device.lastSeen, created: device.created ?? .now)
            do {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                try JSONEncoder().encode(record).write(to: folder.appending(path: "\(device.id.uuidString).json"), options: .atomic)
            } catch {
                throw .failed
            }
        }

        func all() throws(PlayOnStoreError) -> [PlayDeviceInfo] {
            let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
            return files.compactMap { file in
                guard let data = try? Data(contentsOf: file), let record = try? JSONDecoder().decode(Record.self, from: data),
                    let kind = PlayDeviceInfo.Kind(rawValue: record.kind)
                else { return nil }
                return PlayDeviceInfo(
                    id: record.id, kind: kind, name: record.name, publicKey: record.publicKey, keyDate: record.keyDate,
                    lastSeen: record.lastSeen, created: record.created)
            }
        }

        func sweep(notSeenSince cutoff: Date) throws(PlayOnStoreError) -> Int { 0 }

        /// Writes the port a TV listens on, for a phone that cannot browse.
        func publish(port: UInt16, of id: UUID) {
            try? Data("\(port)".utf8).write(to: folder.appending(path: "\(id.uuidString).port"), options: .atomic)
        }

        /// Each TV's loopback endpoint, from the ports TVs wrote.
        func endpoints() -> [UUID: NWEndpoint] {
            let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
            var found: [UUID: NWEndpoint] = [:]
            for file in files where file.pathExtension == "port" {
                guard let id = UUID(uuidString: file.deletingPathExtension().lastPathComponent),
                    let text = try? String(contentsOf: file, encoding: .utf8), let port = NWEndpoint.Port(text)
                else { continue }
                found[id] = .hostPort(host: "127.0.0.1", port: port)
            }
            return found
        }
    }

    /// A browser that reads the TVs' ports from the shared folder instead of Bonjour.
    @MainActor
    final class FolderBrowser: PlayOnBrowsing {
        let store: FilePlayDevices
        private var running = false
        var endpoints: [UUID: NWEndpoint] { running ? store.endpoints() : [:] }
        let denied = false

        init(store: FilePlayDevices) {
            self.store = store
        }

        func start() {
            running = true
        }

        func stop() {
            running = false
        }
    }
#endif
