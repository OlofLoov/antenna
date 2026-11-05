import Foundation

/// How large a guide may be before it fails as `.tooLarge`. MB here means
/// 1 000 000 bytes.
public struct GuideLimits: Sendable, Equatable {
    /// The most bytes a gzip body may send.
    public var compressedBytes: Int64
    /// The most bytes of XML, sent plain or unpacked from gzip.
    public var unpackedBytes: Int64

    public init(compressedBytes: Int64, unpackedBytes: Int64) {
        self.compressedBytes = compressedBytes
        self.unpackedBytes = unpackedBytes
    }

    /// tvOS 32 MB compressed and 96 MB unpacked; elsewhere 96 MB and 256 MB.
    public static let platform: GuideLimits = {
        #if os(tvOS)
            GuideLimits(compressedBytes: 32_000_000, unpackedBytes: 96_000_000)
        #else
            GuideLimits(compressedBytes: 96_000_000, unpackedBytes: 256_000_000)
        #endif
    }()
}

/// Takes one guide body as it arrives, writes it to a file named after the
/// source, then unpacks and parses it. The body is never held in memory
/// whole: the file is mapped to parse it, so only a copy the entity
/// sanitizer makes counts as resident.
///
/// A body is XML when its first byte, after an optional UTF-8 byte order mark
/// and whitespace, is `<`, and gzip when it starts with `1f 8b`. A gzip body
/// is unpacked and checked again, and must then be XML. Anything else fails
/// as `.unsupportedEncoding`.
final class GuideDecoder {
    enum Kind: Equatable {
        case xml
        case gzip
    }

    private let limits: GuideLimits
    private let expectedLength: Int64?
    private let rawFile: URL
    private let xmlFile: URL
    private let handle: FileHandle
    private var head: [UInt8] = []
    private(set) var kind: Kind?
    private(set) var bytesReceived: Int64 = 0

    /// Creates or empties `<directory>/<sourceID>.download`.
    init(limits: GuideLimits, expectedLength: Int64?, directory: URL, sourceID: UUID) throws(GuideError) {
        self.limits = limits
        self.expectedLength = expectedLength
        rawFile = directory.appending(path: "\(sourceID.uuidString).download")
        xmlFile = directory.appending(path: "\(sourceID.uuidString).xml")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            guard FileManager.default.createFile(atPath: rawFile.path(), contents: nil) else { throw GuideError.network(.cannotCreateFile) }
            handle = try FileHandle(forWritingTo: rawFile)
        } catch {
            throw .network(.cannotCreateFile)
        }
    }

    deinit {
        try? handle.close()
        try? FileManager.default.removeItem(at: rawFile)
        try? FileManager.default.removeItem(at: xmlFile)
    }

    /// The limit on bytes received, once the body has been sniffed.
    private var wireLimit: Int64 {
        kind == .gzip ? limits.compressedBytes : limits.unpackedBytes
    }

    func append(_ chunk: Data) throws(GuideError) {
        bytesReceived += Int64(chunk.count)
        if kind == nil {
            head += chunk
            switch Self.sniff(head) {
            case .some(.some(let found)):
                kind = found
                head = []
                if let expectedLength, expectedLength > wireLimit { throw .tooLarge }
            case .some(.none):
                throw .unsupportedEncoding
            case .none:
                break
            }
        }
        guard bytesReceived <= wireLimit else { throw .tooLarge }
        do {
            try handle.write(contentsOf: chunk)
        } catch {
            throw .network(.cannotWriteToFile)
        }
    }

    /// Unpacks and parses what arrived. `.empty` for a body with no
    /// programmes, `.malformed` for damaged gzip or XML the parser rejects.
    func finish() throws(GuideError) -> SourceGuide {
        do {
            try handle.close()
        } catch {
            throw .network(.cannotWriteToFile)
        }
        guard let kind else { throw .empty }
        var file = rawFile
        if kind == .gzip {
            try unpack()
            file = xmlFile
        }
        let data: Data
        do {
            data = try Data(contentsOf: file, options: .alwaysMapped)
        } catch {
            throw .network(.cannotOpenFile)
        }
        if kind == .gzip {
            switch Self.sniff(data) {
            case .some(.some(.xml)): break
            case .none: throw .empty
            default: throw .unsupportedEncoding
            }
        }
        // XMLParser rejects anything before an XML declaration, so the parse
        // starts at the first `<`. Slicing the mapped data copies nothing.
        let start = data.firstIndex(of: UInt8(ascii: "<")) ?? data.startIndex
        let parsed: XMLTVParser.Result
        do {
            parsed = try XMLTVParser().parse(data[start...])
        } catch {
            throw .malformed
        }
        let guide = SourceGuide(parsed.programmes)
        guard !guide.programmes.isEmpty else { throw .empty }
        return guide
    }

    private func unpack() throws(GuideError) {
        let compressed: Data
        let output: FileHandle
        do {
            compressed = try Data(contentsOf: rawFile, options: .alwaysMapped)
            guard FileManager.default.createFile(atPath: xmlFile.path(), contents: nil) else { throw GuideError.network(.cannotCreateFile) }
            output = try FileHandle(forWritingTo: xmlFile)
        } catch {
            throw .network(.cannotCreateFile)
        }
        defer {
            try? output.close()
            try? FileManager.default.removeItem(at: rawFile)
        }
        do {
            try Gunzip.unpack(compressed, limit: limits.unpackedBytes) { try output.write(contentsOf: $0) }
        } catch {
            switch error {
            case .tooLarge: throw .tooLarge
            case .malformed: throw .malformed
            case .write: throw .network(.cannotWriteToFile)
            }
        }
    }

    /// Nil while the bytes seen so far cannot decide; `.some(nil)` when they
    /// are neither XML nor gzip. Reads past any amount of leading whitespace.
    static func sniff(_ bytes: some Collection<UInt8>) -> Kind?? {
        let start = Array(bytes.prefix(3))
        guard let first = start.first else { return nil }
        if first == 0x1f {
            guard start.count > 1 else { return nil }
            return start[1] == 0x8b ? .some(.gzip) : .some(nil)
        }
        let bom: [UInt8] = [0xef, 0xbb, 0xbf]
        var rest = bytes.dropFirst(0)
        if first == 0xef {
            guard start.count == 3 else { return start == Array(bom.prefix(start.count)) ? nil : .some(nil) }
            guard start == bom else { return .some(nil) }
            rest = bytes.dropFirst(3)
        }
        guard let next = rest.first(where: { ![0x20, 0x09, 0x0a, 0x0d].contains($0) }) else { return nil }
        return next == UInt8(ascii: "<") ? .some(.xml) : .some(nil)
    }
}
