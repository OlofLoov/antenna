import Foundation
import Network

extension FixtureServer {
    /// Byte `offset` of a `generated` body. The pattern repeats every 251
    /// bytes, a prime, so a byte read from the wrong place shows unless the
    /// place is a multiple of 251 away.
    public static func generatedByte(at offset: Int) -> UInt8 {
        UInt8(offset % 251)
    }

    /// Bytes `offset` to `offset + count` of a `generated` body, `count` at most a megabyte.
    public static func generated(from offset: Int, count: Int) -> Data {
        let start = offset % 251
        return generatedCycle.subdata(in: start..<start + count)
    }

    /// The pattern from byte 0 for 251 bytes more than a megabyte, so any
    /// megabyte of a `generated` body is a slice of it.
    private static let generatedCycle = Data((0..<(251 + (1 << 20))).map(generatedByte))

    /// Sends a `generated` body, or the range of it asked for, a megabyte at
    /// a time, each once the last one is on its way.
    func sendGenerated(length: Int, for request: Request, on connection: NWConnection) async throws {
        let range = request.headers["range"].flatMap { Self.byteRange($0, length: length) }
        let part = range ?? 0..<length
        let extra =
            ["Accept-Ranges: bytes"] + (range.map { ["Content-Range: bytes \($0.lowerBound)-\($0.upperBound - 1)/\(length)"] } ?? [])
        let header = head(status: range == nil ? 200 : 206, type: "video/x-matroska", length: part.count, extra: extra)
        try await Self.send(connection, head: header, body: Data())
        guard request.method != "HEAD" else { return }
        var offset = part.lowerBound
        while offset < part.upperBound {
            let end = min(part.upperBound, offset + (1 << 20))
            let chunk = Self.generated(from: offset, count: end - offset)
            try await Self.send(connection, head: "", body: chunk)
            offset = end
        }
    }
}
