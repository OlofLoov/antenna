#if os(iOS) || os(macOS)
    import AntennaCore
    import Foundation
    import Observation
    import SwiftData

    /// One file the import sheet was opened for: where it is, and the
    /// source Re-import replaces, if any.
    struct ImportRequest: Identifiable, Equatable {
        let id = UUID()
        var url: URL
        /// The file source Re-import was chosen on; nil adds a source.
        var replacing: Target?

        struct Target: Equatable {
            var id: UUID
            var name: String
        }
    }

    /// The import sheet's state (local-m3u-file-import capability): reading
    /// the file off the main actor, the checks' outcome, the fields, and
    /// the save.
    @MainActor @Observable
    final class ImportModel {
        enum Phase: Equatable {
            case reading
            case inspected(PlaylistImport.Inspected, ImportText.Summary)
            /// Import stays disabled. `link` is set for a file holding one link.
            case refused(ImportText.Problem, link: URL?)
        }

        let request: ImportRequest
        let fileName: String
        private(set) var size: Int?
        private(set) var phase = Phase.reading
        var name = ""
        var guideLink = ""
        /// The file source this file name was imported as before; never set in replace mode.
        private(set) var earlier: ImportRequest.Target?
        /// Why the last save failed.
        private(set) var saveError: String?
        @ObservationIgnored let text: ImportText
        @ObservationIgnored private var reading: Task<Void, Never>?

        init(_ request: ImportRequest, text: ImportText = ImportText()) {
            self.request = request
            self.text = text
            fileName = request.url.lastPathComponent
            name = ImportText.defaultName(fileName: fileName)
        }

        var sizeText: String? { size.map(text.size) }

        /// Reads and checks the file, then fills in the guide link and looks
        /// for an earlier import of the same file name.
        func read(in context: ModelContext) async {
            let url = request.url
            let task = Task.detached { ImportReader.read(url) }
            reading = Task { _ = await task.value }
            let result = await task.value
            guard !Task.isCancelled else { return }
            size = result.size
            switch result.outcome {
            case nil:
                phase = .refused(text.unreadable(fileName: fileName), link: nil)
            case .playlist(let inspected)?:
                phase = .inspected(inspected, text.summary(inspected))
                arrange(header: inspected.playlist.epgURLs.first, in: context)
            case let outcome?:
                var link: URL?
                if case .linkList(let links) = outcome, links.count == 1 { link = links.first }
                phase = .refused(text.problem(outcome, fileName: fileName) ?? text.unreadable(fileName: fileName), link: link)
            }
        }

        private func arrange(header: URL?, in context: ModelContext) {
            if let target = request.replacing {
                let existing = FileImport.record(target.id, in: context)
                guideLink = (existing?.epgURL ?? header)?.absoluteString ?? ""
                return
            }
            if let before = FileImport.importedBefore(fileName, in: context) {
                earlier = .init(id: before.id, name: before.name)
                guideLink = (before.epgURL ?? header)?.absoluteString ?? ""
            } else {
                guideLink = header?.absoluteString ?? ""
            }
        }

        /// Cancel while reading: the read stops and nothing is saved.
        func cancel() {
            reading?.cancel()
        }

        /// Saves the inspected file: onto `replacing` for Re-import or
        /// "Replace <name>", otherwise as a new source. Nil when nothing was saved.
        func save(replacing target: UUID?, credentials: any CredentialStoring, into context: ModelContext) -> Saved? {
            guard case .inspected(let inspected, _) = phase else { return nil }
            let request = FileImport.Request(
                inspected: inspected, fileName: fileName, name: name, guideLink: guideLink, replacing: target)
            do {
                let record = try FileImport(credentials: credentials).save(request, into: context)
                let stored = record.playlistData.map { String(decoding: $0, as: UTF8.self) } ?? inspected.text
                return Saved(record: record, playlist: PlaylistImport.playlist(stored: stored, restored: inspected.text))
            } catch {
                switch error {
                case .credentials(let reason): saveError = "Could not store the logins in this file: \(reason)"
                }
                return nil
            }
        }

        /// What Import saved: the record and its channels as Live will list them.
        struct Saved {
            var record: SourceRecord
            var playlist: Playlist
        }
    }

    /// Reads a picked, shared or dropped file within the size limit.
    enum ImportReader {
        struct Result: Sendable {
            /// Nil when the file could not be read.
            var outcome: PlaylistImport.Outcome?
            var size: Int?
        }

        /// Never reads a file whose known size is over the limit, and at
        /// most one byte past it otherwise. A copy the system left in
        /// `Documents/Inbox` is deleted after reading.
        nonisolated static func read(_ url: URL) -> Result {
            let scoped = url.startAccessingSecurityScopedResource()
            defer {
                if scoped { url.stopAccessingSecurityScopedResource() }
                if url.deletingLastPathComponent().lastPathComponent == "Inbox" { try? FileManager.default.removeItem(at: url) }
            }
            var result = Result()
            var coordinationError: NSError?
            NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { readable in
                let known = try? readable.resourceValues(forKeys: [.fileSizeKey]).fileSize
                result.size = known
                if let known, PlaylistImport.isTooLarge(known) {
                    result.outcome = .tooLarge(bytes: known)
                    return
                }
                guard let handle = try? FileHandle(forReadingFrom: readable) else { return }
                defer { try? handle.close() }
                let data: Data
                do {
                    data = try handle.read(upToCount: PlaylistImport.maximumBytes + 1) ?? Data()
                } catch {
                    return
                }
                if known == nil, PlaylistImport.isTooLarge(data.count) {
                    result.outcome = .tooLarge(bytes: nil)
                    return
                }
                result.size = known ?? data.count
                result.outcome = PlaylistImport.inspect(data)
            }
            return result
        }
    }
#endif
