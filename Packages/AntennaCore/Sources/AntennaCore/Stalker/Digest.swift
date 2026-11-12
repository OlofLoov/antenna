import Foundation

/// MD5 and SHA-256 over bytes, written out so AntennaCore keeps to
/// Foundation. Only the Stalker device identity uses them; neither protects
/// anything.
enum Digest {
    /// The uppercase hex form of `bytes`.
    static func hex(_ bytes: [UInt8]) -> String {
        let digits = Array("0123456789ABCDEF".utf8)
        var out: [UInt8] = []
        out.reserveCapacity(bytes.count * 2)
        for byte in bytes {
            out.append(digits[Int(byte >> 4)])
            out.append(digits[Int(byte & 0x0F)])
        }
        return String(decoding: out, as: UTF8.self)
    }

    // MARK: MD5 (RFC 1321)

    private static let md5Shifts: [UInt32] = [
        7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22,
        5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20,
        4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
        6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21,
    ]

    /// floor(abs(sin(i + 1)) * 2^32), as RFC 1321 defines the table.
    private static let md5Constants: [UInt32] = (0..<64).map { UInt32(abs(sin(Double($0 + 1))) * 4_294_967_296) }

    static func md5(_ message: [UInt8]) -> [UInt8] {
        var state: [UInt32] = [0x6745_2301, 0xEFCD_AB89, 0x98BA_DCFE, 0x1032_5476]
        var words = [UInt32](repeating: 0, count: 16)
        for chunk in blocks(message, bigEndianLength: false) {
            for index in 0..<16 {
                let base = index * 4
                words[index] =
                    UInt32(chunk[base]) | UInt32(chunk[base + 1]) << 8 | UInt32(chunk[base + 2]) << 16 | UInt32(chunk[base + 3]) << 24
            }
            var (va, vb, vc, vd) = (state[0], state[1], state[2], state[3])
            for round in 0..<64 {
                var mixed: UInt32
                let word: Int
                switch round {
                case 0..<16:
                    mixed = (vb & vc) | (~vb & vd)
                    word = round
                case 16..<32:
                    mixed = (vd & vb) | (~vd & vc)
                    word = (5 * round + 1) % 16
                case 32..<48:
                    mixed = vb ^ vc ^ vd
                    word = (3 * round + 5) % 16
                default:
                    mixed = vc ^ (vb | ~vd)
                    word = (7 * round) % 16
                }
                mixed = mixed &+ va &+ md5Constants[round] &+ words[word]
                va = vd
                vd = vc
                vc = vb
                vb = vb &+ rotateLeft(mixed, md5Shifts[round])
            }
            state[0] = state[0] &+ va
            state[1] = state[1] &+ vb
            state[2] = state[2] &+ vc
            state[3] = state[3] &+ vd
        }
        return state.flatMap { value in (0..<4).map { UInt8(truncatingIfNeeded: value >> (8 * UInt32($0))) } }
    }

    // MARK: SHA-256 (FIPS 180-4)

    private static let sha256Constants: [UInt32] = [
        0x428a_2f98, 0x7137_4491, 0xb5c0_fbcf, 0xe9b5_dba5, 0x3956_c25b, 0x59f1_11f1, 0x923f_82a4, 0xab1c_5ed5,
        0xd807_aa98, 0x1283_5b01, 0x2431_85be, 0x550c_7dc3, 0x72be_5d74, 0x80de_b1fe, 0x9bdc_06a7, 0xc19b_f174,
        0xe49b_69c1, 0xefbe_4786, 0x0fc1_9dc6, 0x240c_a1cc, 0x2de9_2c6f, 0x4a74_84aa, 0x5cb0_a9dc, 0x76f9_88da,
        0x983e_5152, 0xa831_c66d, 0xb003_27c8, 0xbf59_7fc7, 0xc6e0_0bf3, 0xd5a7_9147, 0x06ca_6351, 0x1429_2967,
        0x27b7_0a85, 0x2e1b_2138, 0x4d2c_6dfc, 0x5338_0d13, 0x650a_7354, 0x766a_0abb, 0x81c2_c92e, 0x9272_2c85,
        0xa2bf_e8a1, 0xa81a_664b, 0xc24b_8b70, 0xc76c_51a3, 0xd192_e819, 0xd699_0624, 0xf40e_3585, 0x106a_a070,
        0x19a4_c116, 0x1e37_6c08, 0x2748_774c, 0x34b0_bcb5, 0x391c_0cb3, 0x4ed8_aa4a, 0x5b9c_ca4f, 0x682e_6ff3,
        0x748f_82ee, 0x78a5_636f, 0x84c8_7814, 0x8cc7_0208, 0x90be_fffa, 0xa450_6ceb, 0xbef9_a3f7, 0xc671_78f2,
    ]

    static func sha256(_ message: [UInt8]) -> [UInt8] {
        var state: [UInt32] = [
            0x6a09_e667, 0xbb67_ae85, 0x3c6e_f372, 0xa54f_f53a, 0x510e_527f, 0x9b05_688c, 0x1f83_d9ab, 0x5be0_cd19,
        ]
        var words = [UInt32](repeating: 0, count: 64)
        for chunk in blocks(message, bigEndianLength: true) {
            for index in 0..<16 {
                let base = index * 4
                words[index] =
                    UInt32(chunk[base]) << 24 | UInt32(chunk[base + 1]) << 16 | UInt32(chunk[base + 2]) << 8 | UInt32(chunk[base + 3])
            }
            for index in 16..<64 {
                let early = words[index - 15]
                let late = words[index - 2]
                let sigma0 = rotateRight(early, 7) ^ rotateRight(early, 18) ^ (early >> 3)
                let sigma1 = rotateRight(late, 17) ^ rotateRight(late, 19) ^ (late >> 10)
                words[index] = words[index - 16] &+ sigma0 &+ words[index - 7] &+ sigma1
            }
            var work = state
            for round in 0..<64 {
                let (va, vb, vc, vd, ve, vf, vg, vh) = (work[0], work[1], work[2], work[3], work[4], work[5], work[6], work[7])
                let sum1 = rotateRight(ve, 6) ^ rotateRight(ve, 11) ^ rotateRight(ve, 25)
                let choose = (ve & vf) ^ (~ve & vg)
                let first = vh &+ sum1 &+ choose &+ sha256Constants[round] &+ words[round]
                let sum0 = rotateRight(va, 2) ^ rotateRight(va, 13) ^ rotateRight(va, 22)
                let majority = (va & vb) ^ (va & vc) ^ (vb & vc)
                work = [first &+ sum0 &+ majority, va, vb, vc, vd &+ first, ve, vf, vg]
            }
            for index in 0..<8 { state[index] = state[index] &+ work[index] }
        }
        return state.flatMap { value in (0..<4).reversed().map { UInt8(truncatingIfNeeded: value >> (8 * UInt32($0))) } }
    }

    // MARK: Shared

    /// The message with the 0x80 byte, zero padding and the bit length
    /// appended, cut into 64-byte blocks.
    private static func blocks(_ message: [UInt8], bigEndianLength: Bool) -> [[UInt8]] {
        var bytes = message
        let bitLength = UInt64(message.count) &* 8
        bytes.append(0x80)
        while bytes.count % 64 != 56 { bytes.append(0) }
        let length = (0..<8).map { UInt8(truncatingIfNeeded: bitLength >> (8 * UInt64($0))) }
        bytes.append(contentsOf: bigEndianLength ? length.reversed() : length)
        return stride(from: 0, to: bytes.count, by: 64).map { Array(bytes[$0..<$0 + 64]) }
    }

    private static func rotateLeft(_ value: UInt32, _ count: UInt32) -> UInt32 {
        (value << count) | (value >> (32 - count))
    }

    private static func rotateRight(_ value: UInt32, _ count: UInt32) -> UInt32 {
        (value >> count) | (value << (32 - count))
    }
}
