import Foundation

/// Finds the points in an MPEG-TS byte stream that playback can start
/// from: a packet that starts a video keyframe once the program tables are
/// known, or, for radio, a packet that starts a sound frame.
///
/// Bytes arrive in any sizes and the scanner keeps a partial packet for the
/// next call. Bytes before the first sync byte and packets that lose sync
/// are dropped. The newest PAT and PMT packets are kept, so a chunk can
/// start with the tables a demuxer needs.
public struct TSStartPoints: Sendable {
    public static let packetSize = 188

    /// Whole packets in arrival order. `startPoint` is true when the first
    /// packet starts a keyframe; a run holds at most one start point.
    public struct Run: Sendable, Equatable {
        public var bytes: Data
        public var startPoint: Bool
    }

    /// The newest packet carrying the program association table.
    public private(set) var pat: Data?
    /// The newest packet carrying the program map table.
    public private(set) var pmt: Data?
    private var pmtPID: Int?
    private var video: (pid: Int, type: UInt8)?
    private var soundPID: Int?
    private var carry = Data()

    public init() {}

    /// Splits `bytes` into runs of whole packets, a new run at each start point.
    public mutating func scan(_ bytes: Data) -> [Run] {
        var data = carry
        data.append(bytes)
        carry = Data()
        var runs: [Run] = []
        var index = data.startIndex
        while data.endIndex - index >= Self.packetSize {
            guard data[index] == 0x47 else {
                index += 1
                continue
            }
            let packet = data[index..<index + Self.packetSize]
            index += Self.packetSize
            let start = read(packet)
            if start || runs.isEmpty {
                runs.append(Run(bytes: Data(packet), startPoint: start))
            } else {
                runs[runs.count - 1].bytes.append(packet)
            }
        }
        carry = Data(data[index...])
        return runs
    }

    /// Reads one packet's tables. True when it starts a keyframe.
    private mutating func read(_ packet: Data) -> Bool {
        let base = packet.startIndex
        let unitStart = packet[base + 1] & 0x40 != 0
        let pid = Int(packet[base + 1] & 0x1F) << 8 | Int(packet[base + 2])
        let control = (packet[base + 3] >> 4) & 0x3
        guard control & 0x1 != 0 else { return false }
        var payload = base + 4
        var randomAccess = false
        if control & 0x2 != 0 {
            let length = Int(packet[base + 4])
            if length > 0, base + 5 < packet.endIndex { randomAccess = packet[base + 5] & 0x40 != 0 }
            payload += 1 + length
        }
        guard payload < packet.endIndex else { return false }
        if pid == 0, unitStart {
            pat = Data(packet)
            pmtPID = Self.programMapPID(packet[payload...])
            return false
        }
        if pid == pmtPID, unitStart {
            pmt = Data(packet)
            readProgramMap(packet[payload...])
            return false
        }
        guard unitStart, pat != nil, pmt != nil else { return false }
        if let video {
            guard pid == video.pid else { return false }
            return randomAccess || Self.startsKeyframe(packet[payload...], type: video.type)
        }
        return pid == soundPID
    }

    /// The PID of the first program's map table in a PAT payload.
    private static func programMapPID(_ payload: Data.SubSequence) -> Int? {
        let table = section(payload)
        guard let table, table.count >= 12, table[table.startIndex] == 0x00 else { return nil }
        let bytes = Array(table)
        let length = Int(bytes[1] & 0x0F) << 8 | Int(bytes[2])
        var at = 8
        while at + 4 <= min(bytes.count, 3 + length - 4) {
            let program = Int(bytes[at]) << 8 | Int(bytes[at + 1])
            let pid = Int(bytes[at + 2] & 0x1F) << 8 | Int(bytes[at + 3])
            if program != 0 { return pid }
            at += 4
        }
        return nil
    }

    /// Picks the first video stream and the first sound stream of a PMT payload.
    private mutating func readProgramMap(_ payload: Data.SubSequence) {
        guard let table = Self.section(payload), table.count >= 16, table[table.startIndex] == 0x02 else { return }
        let bytes = Array(table)
        let length = Int(bytes[1] & 0x0F) << 8 | Int(bytes[2])
        let end = min(bytes.count, 3 + length - 4)
        let info = Int(bytes[10] & 0x0F) << 8 | Int(bytes[11])
        var at = 12 + info
        var foundVideo: (Int, UInt8)?
        var foundSound: Int?
        while at + 5 <= end {
            let type = bytes[at]
            let pid = Int(bytes[at + 1] & 0x1F) << 8 | Int(bytes[at + 2])
            let esInfo = Int(bytes[at + 3] & 0x0F) << 8 | Int(bytes[at + 4])
            if foundVideo == nil, Self.videoTypes.contains(type) { foundVideo = (pid, type) }
            if foundSound == nil, Self.soundTypes.contains(type) { foundSound = pid }
            at += 5 + esInfo
        }
        video = foundVideo.map { (pid: $0.0, type: $0.1) }
        soundPID = foundSound
    }

    /// The table after the pointer field.
    private static func section(_ payload: Data.SubSequence) -> Data.SubSequence? {
        guard let pointer = payload.first else { return nil }
        let start = payload.startIndex + 1 + Int(pointer)
        guard start < payload.endIndex else { return nil }
        return payload[start...]
    }

    static let videoTypes: Set<UInt8> = [0x01, 0x02, 0x1B, 0x24]
    static let soundTypes: Set<UInt8> = [0x03, 0x04, 0x0F, 0x11, 0x81, 0x87]

    /// True when the PES payload in this packet holds a sequence header,
    /// parameter set or keyframe slice for the video codec `type`.
    static func startsKeyframe(_ pes: Data.SubSequence, type: UInt8) -> Bool {
        let bytes = Array(pes)
        guard bytes.count > 9, bytes[0] == 0, bytes[1] == 0, bytes[2] == 1 else { return false }
        var at = 9 + Int(bytes[8])
        while at + 3 < bytes.count {
            if bytes[at] == 0, bytes[at + 1] == 0, bytes[at + 2] == 1 {
                let header = bytes[at + 3]
                switch type {
                case 0x1B:
                    let nal = header & 0x1F
                    if nal == 5 || nal == 7 { return true }
                case 0x24:
                    let nal = (header >> 1) & 0x3F
                    if (16...21).contains(nal) || (32...33).contains(nal) { return true }
                default:
                    if header == 0xB3 { return true }
                }
                at += 3
            } else {
                at += 1
            }
        }
        return false
    }
}
