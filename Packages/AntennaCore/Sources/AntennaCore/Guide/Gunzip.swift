import Foundation

/// Unpacks the first member of a gzip file (RFC 1952, deflate per RFC 1951)
/// in Swift, so AntennaCore keeps to Foundation (decision adr-0005). Output goes to
/// `write` in blocks of about 64 KiB, and unpacking stops on the block that
/// takes the total past `limit`. The CRC and length trailer are not checked;
/// a damaged stream fails as a deflate error. Bytes after the first member
/// are ignored.
enum Gunzip {
    enum Failure: Error, Equatable {
        case malformed
        case tooLarge
        /// `write` threw.
        case write
    }

    static func unpack(_ data: Data, limit: Int64, write: @escaping (Data) throws -> Void) throws(Failure) {
        do {
            try data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) throws in
                var reader = Reader(bytes: raw.bindMemory(to: UInt8.self))
                try reader.skipHeader()
                var output = Output(limit: limit, write: write)
                try inflate(&reader, into: &output)
                try output.flush(keepingWindow: false)
            }
        } catch let failure as Failure {
            throw failure
        } catch {
            throw .malformed
        }
    }

    // MARK: Input

    private struct Reader {
        let bytes: UnsafeBufferPointer<UInt8>
        var position = 0
        var buffer: UInt64 = 0
        var count = 0

        mutating func byte() throws(Failure) -> UInt8 {
            guard position < bytes.count else { throw .malformed }
            defer { position += 1 }
            return bytes[position]
        }

        /// The next `width` bits, least significant first. Fewer than 8 bits are
        /// left in `buffer` afterwards, so a stored block can drop them.
        mutating func bits(_ width: Int) throws(Failure) -> Int {
            while count < width {
                buffer |= UInt64(try byte()) << UInt64(count)
                count += 8
            }
            let value = Int(buffer & ((1 << UInt64(width)) - 1))
            buffer >>= UInt64(width)
            count -= width
            return value
        }

        mutating func skipHeader() throws(Failure) {
            guard try byte() == 0x1f, try byte() == 0x8b, try byte() == 8 else { throw .malformed }
            let flags = try byte()
            for _ in 0..<6 { _ = try byte() }
            if flags & 0x04 != 0 {
                let length = Int(try byte()) | Int(try byte()) << 8
                for _ in 0..<length { _ = try byte() }
            }
            if flags & 0x08 != 0 { while try byte() != 0 {} }
            if flags & 0x10 != 0 { while try byte() != 0 {} }
            if flags & 0x02 != 0 { _ = try byte(); _ = try byte() }
        }
    }

    // MARK: Output

    private struct Output {
        static let window = 32_768
        static let block = 65_536

        let limit: Int64
        let write: (Data) throws -> Void
        var pending: [UInt8] = []
        var flushed: Int64 = 0

        init(limit: Int64, write: @escaping (Data) throws -> Void) {
            self.limit = limit
            self.write = write
            pending.reserveCapacity(Self.window + Self.block + 258)
        }

        var total: Int64 { flushed + Int64(pending.count) }

        mutating func append(_ byte: UInt8) throws(Failure) {
            pending.append(byte)
            if pending.count >= Self.window + Self.block { try flush(keepingWindow: true) }
        }

        /// Copies `length` bytes from `distance` back, overlapping as deflate allows.
        mutating func copy(distance: Int, length: Int) throws(Failure) {
            guard distance <= pending.count else { throw .malformed }
            for _ in 0..<length { try append(pending[pending.count - distance]) }
        }

        /// Writes all but the last 32 KiB, which later back references may need.
        mutating func flush(keepingWindow: Bool) throws(Failure) {
            guard total <= limit else { throw .tooLarge }
            let keep = keepingWindow ? min(Self.window, pending.count) : 0
            let out = pending.count - keep
            guard out > 0 else { return }
            do {
                try write(Data(pending[0..<out]))
            } catch {
                throw .write
            }
            pending.removeFirst(out)
            flushed += Int64(out)
        }
    }

    // MARK: Huffman codes

    /// A canonical Huffman code as counts per length and symbols in code order.
    private struct Code {
        var counts = [Int](repeating: 0, count: 16)
        var symbols: [Int]

        init(lengths: [Int]) throws(Failure) {
            symbols = [Int](repeating: 0, count: lengths.count)
            for length in lengths { counts[length] += 1 }
            var left = 1
            for length in 1...15 {
                left = left * 2 - counts[length]
                guard left >= 0 else { throw .malformed }
            }
            var offsets = [Int](repeating: 0, count: 16)
            for length in 1..<15 { offsets[length + 1] = offsets[length] + counts[length] }
            for (symbol, length) in lengths.enumerated() where length != 0 {
                symbols[offsets[length]] = symbol
                offsets[length] += 1
            }
        }

        func decode(_ reader: inout Reader) throws(Failure) -> Int {
            var code = 0
            var first = 0
            var index = 0
            for length in 1...15 {
                code |= try reader.bits(1)
                let count = counts[length]
                if code - first < count { return symbols[index + code - first] }
                index += count
                first = (first + count) << 1
                code <<= 1
            }
            throw .malformed
        }
    }

    private static let lengthBase = [
        3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258,
    ]
    private static let lengthExtra = [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0]
    private static let distanceBase = [
        1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289,
        16385, 24577,
    ]
    private static let distanceExtra = [0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13]
    private static let lengthOrder = [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15]

    private static let fixed: (literals: [Int], distances: [Int]) = (
        [Int](repeating: 8, count: 144) + [Int](repeating: 9, count: 112) + [Int](repeating: 7, count: 24) + [Int](repeating: 8, count: 8),
        [Int](repeating: 5, count: 30)
    )

    // MARK: Blocks

    private static func inflate(_ reader: inout Reader, into output: inout Output) throws(Failure) {
        var last = false
        while !last {
            last = try reader.bits(1) == 1
            switch try reader.bits(2) {
            case 0:
                try stored(&reader, into: &output)
            case 1:
                try codes(&reader, into: &output, literals: Code(lengths: fixed.literals), distances: Code(lengths: fixed.distances))
            case 2:
                let (literals, distances) = try dynamicCodes(&reader)
                try codes(&reader, into: &output, literals: literals, distances: distances)
            default:
                throw .malformed
            }
        }
    }

    private static func stored(_ reader: inout Reader, into output: inout Output) throws(Failure) {
        reader.buffer = 0
        reader.count = 0
        let length = Int(try reader.byte()) | Int(try reader.byte()) << 8
        let complement = Int(try reader.byte()) | Int(try reader.byte()) << 8
        guard length == ~complement & 0xffff else { throw .malformed }
        for _ in 0..<length { try output.append(try reader.byte()) }
    }

    private static func dynamicCodes(_ reader: inout Reader) throws(Failure) -> (Code, Code) {
        let literalCount = try reader.bits(5) + 257
        let distanceCount = try reader.bits(5) + 1
        let codeLengthCount = try reader.bits(4) + 4
        guard literalCount <= 286, distanceCount <= 30 else { throw .malformed }

        var codeLengths = [Int](repeating: 0, count: 19)
        for index in 0..<codeLengthCount { codeLengths[lengthOrder[index]] = try reader.bits(3) }
        let lengthCode = try Code(lengths: codeLengths)

        var lengths: [Int] = []
        lengths.reserveCapacity(literalCount + distanceCount)
        while lengths.count < literalCount + distanceCount {
            let symbol = try lengthCode.decode(&reader)
            switch symbol {
            case 0...15:
                lengths.append(symbol)
            case 16:
                guard let previous = lengths.last else { throw .malformed }
                lengths += [Int](repeating: previous, count: 3 + (try reader.bits(2)))
            case 17:
                lengths += [Int](repeating: 0, count: 3 + (try reader.bits(3)))
            default:
                lengths += [Int](repeating: 0, count: 11 + (try reader.bits(7)))
            }
        }
        guard lengths.count == literalCount + distanceCount, lengths[256] != 0 else { throw .malformed }
        return (try Code(lengths: Array(lengths[0..<literalCount])), try Code(lengths: Array(lengths[literalCount...])))
    }

    private static func codes(_ reader: inout Reader, into output: inout Output, literals: Code, distances: Code) throws(Failure) {
        while true {
            let symbol = try literals.decode(&reader)
            if symbol < 256 {
                try output.append(UInt8(symbol))
                continue
            }
            if symbol == 256 { return }
            let lengthIndex = symbol - 257
            guard lengthIndex < lengthBase.count else { throw .malformed }
            let length = lengthBase[lengthIndex] + (try reader.bits(lengthExtra[lengthIndex]))
            let distanceIndex = try distances.decode(&reader)
            guard distanceIndex < distanceBase.count else { throw .malformed }
            let distance = distanceBase[distanceIndex] + (try reader.bits(distanceExtra[distanceIndex]))
            try output.copy(distance: distance, length: length)
        }
    }
}
