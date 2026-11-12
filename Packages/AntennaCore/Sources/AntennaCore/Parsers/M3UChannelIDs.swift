import Foundation

/// Gives each M3U channel an id built from its guide id, name and group,
/// never from its stream link (m3u-playlists/stable-and-unique-ids).
///
/// The first entry with given fields gets `m3u.<hash>`, the n-th
/// `m3u.<hash>.<n>`. `<hash>` is 64-bit FNV-1a over the three fields in
/// lowercase hex, so a title that holds a link is not copied into the id.
struct M3UChannelIDs {
    /// Earlier id to new id; the first entry with an earlier id wins.
    private(set) var formerIDs: [String: String] = [:]
    private var counts: [UInt64: Int] = [:]

    init(capacity: Int = 0) {
        formerIDs.reserveCapacity(capacity)
        counts.reserveCapacity(capacity)
    }

    /// The id for the next channel in playlist order. Records `formerID`.
    mutating func next(for channel: Channel, formerID: String) -> String {
        let hash = Self.hash(channel)
        let count = (counts[hash] ?? 0) + 1
        counts[hash] = count
        let id = count == 1 ? Self.id(hash) : Self.id(hash) + ".\(count)"
        if formerIDs[formerID] == nil { formerIDs[formerID] = id }
        return id
    }

    /// 64-bit FNV-1a over the three fields, each written as `-` when absent
    /// or `=` and its UTF-8 when present, with U+001F between them, so an
    /// absent field and an empty one differ.
    static func hash(_ channel: Channel) -> UInt64 {
        var value: UInt64 = 0xcbf2_9ce4_8422_2325
        func add(_ byte: UInt8) {
            value ^= UInt64(byte)
            value &*= 0x0000_0100_0000_01b3
        }
        func add(field: String?) {
            guard var text = field else { return add(UInt8(ascii: "-")) }
            add(UInt8(ascii: "="))
            text.withUTF8 { bytes in
                for byte in bytes { add(byte) }
            }
        }
        add(field: channel.epgID)
        add(0x1F)
        add(field: channel.name)
        add(0x1F)
        add(field: channel.group)
        return value
    }

    /// `m3u.` and `hash` as 16 lowercase hex digits.
    static func id(_ hash: UInt64) -> String {
        let digits: [UInt8] = Array("0123456789abcdef".utf8)
        var bytes: [UInt8] = Array("m3u.".utf8)
        bytes.reserveCapacity(20)
        for shift in stride(from: 60, through: 0, by: -4) {
            bytes.append(digits[Int((hash >> UInt64(shift)) & 0xF)])
        }
        return String(decoding: bytes, as: UTF8.self)
    }
}
