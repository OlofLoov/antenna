/// Reads bits and Exp-Golomb codes from the front of a byte array, as
/// H.264 parameter sets are written. Every read returns nil, or false,
/// once the bytes run out.
struct BitReader {
    private let bytes: [UInt8]
    private var position = 0

    init(_ bytes: [UInt8]) {
        self.bytes = bytes
    }

    mutating func bits(_ count: Int) -> Int? {
        guard count <= 32, position + count <= bytes.count * 8 else { return nil }
        var value = 0
        for _ in 0..<count {
            let byte = bytes[position / 8]
            value = value << 1 | Int((byte >> (7 - UInt8(position % 8))) & 1)
            position += 1
        }
        return value
    }

    mutating func skip(_ count: Int) -> Bool {
        guard position + count <= bytes.count * 8 else { return false }
        position += count
        return true
    }

    /// An unsigned Exp-Golomb code, ue(v).
    mutating func unsignedGolomb() -> Int? {
        var zeros = 0
        while true {
            guard let bit = bits(1) else { return nil }
            if bit == 1 { break }
            zeros += 1
            guard zeros < 32 else { return nil }
        }
        guard let rest = bits(zeros) else { return nil }
        return (1 << zeros) - 1 + rest
    }

    /// A signed Exp-Golomb code, se(v).
    mutating func signedGolomb() -> Int? {
        unsignedGolomb().map { $0 % 2 == 1 ? ($0 + 1) / 2 : -($0 / 2) }
    }

    /// Skips an H.264 scaling list of `size` entries.
    mutating func skipScalingList(size: Int) -> Bool {
        var last = 8
        var next = 8
        for _ in 0..<size where next != 0 {
            guard let delta = signedGolomb() else { return false }
            next = (last + delta + 256) % 256
            last = next == 0 ? last : next
        }
        return true
    }
}
