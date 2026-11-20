import CoreMedia
import Foundation

/// Keeps the times of a live stream running on when the stream's own times
/// jump (playback-engine/live-keeps-playing-across-a-timestamp-jump).
///
/// A broadcast's times jump at an ad break, a switch to another feed or an
/// encoder restart, forward or back, and MPEG-TS times wrap to zero every
/// 26.5 hours. The renderers play by time, so a jump forward would freeze
/// the picture until the clock caught up and a jump back would leave every
/// frame late. `place` moves each packet by an offset so the times carry on
/// from where they were.
///
/// Each picture and sound stream is watched on its own: a decode time more
/// than `jumpLimit` from where the stream's last packet ends is a jump. The
/// first stream to jump sets a new offset that makes it carry on, and the
/// other streams take that same offset when they jump by about as much, so
/// picture and sound keep the distance the new feed gives them. A jump of
/// a whole wrap, give or take `jumpLimit`, moves by exactly one wrap.
/// Subtitles and streams first seen after a jump take the newest offset.
struct LiveTimeline {
    /// How far a stream's decode time may move from where its last packet
    /// ends before it counts as a jump. A second is above the jitter of
    /// broadcast muxers and below any break in a live feed.
    static let jumpLimit = CMTime(value: 1, timescale: 1)
    /// How close two streams' jumps must be to count as the same splice.
    /// Muxers keep sound within a second of the picture it belongs to.
    static let spliceMatch = CMTime(value: 2, timescale: 1)
    /// The 33-bit MPEG-TS clock, 2^33 ticks of 90 kHz.
    static let mpegTSWrap = CMTime(value: 1 << 33, timescale: 90_000)

    /// The length after which the container's times start again at zero,
    /// nil when they do not.
    let wrap: CMTime?

    private struct Stream {
        var offset: CMTime
        var lastDecode: CMTime
        var step: CMTime
    }

    private var streams: [Int: Stream] = [:]
    /// The offset the newest jump set, for streams seen after it.
    private var newest = CMTime.zero
    /// The newest jump: how far the stream that made it moved, and the offset it set.
    private var lastSplice: (jump: CMTime, offset: CMTime)?

    init(wrap: CMTime?) {
        self.wrap = wrap
    }

    /// What `place` did with a packet.
    struct Placed {
        var packet: DemuxedPacket
        /// True when the packet's stream jumped to a new feed's times here;
        /// a wrap does not count.
        var jumped = false
    }

    /// `packet` with its times moved onto the run's timeline. `watched` is
    /// true for picture and sound streams, whose times are checked for jumps.
    mutating func place(_ packet: DemuxedPacket, watched: Bool) -> Placed {
        let time = packet.decodeTime.isNumeric ? packet.decodeTime : packet.presentationTime
        guard watched, time.isNumeric else {
            return Placed(packet: Self.moved(packet, by: streams[packet.streamIndex]?.offset ?? newest))
        }
        guard var stream = streams[packet.streamIndex] else {
            streams[packet.streamIndex] = Stream(offset: newest, lastDecode: time, step: Self.length(of: packet))
            return Placed(packet: Self.moved(packet, by: newest))
        }
        let expected = stream.lastDecode + stream.step
        let jump = time - expected
        var jumped = false
        if Self.magnitude(jump) > Self.jumpLimit {
            if let turns = wraps(in: jump) {
                stream.offset = CMTimeSubtract(stream.offset, CMTimeMultiply(wrap ?? .zero, multiplier: turns))
            } else if let splice = lastSplice, sameSplice(jump, splice, offset: stream.offset) {
                stream.offset = splice.offset
                jumped = true
            } else {
                stream.offset = CMTimeSubtract(stream.offset, jump)
                lastSplice = (jump, stream.offset)
                newest = stream.offset
                jumped = true
            }
        }
        let length = Self.length(of: packet)
        let step = time - stream.lastDecode
        stream.step = length > .zero ? length : (step > .zero && step <= Self.jumpLimit ? step : stream.step)
        stream.lastDecode = time
        streams[packet.streamIndex] = stream
        return Placed(packet: Self.moved(packet, by: stream.offset), jumped: jumped)
    }

    /// Whether a stream that jumped by `jump` from `offset` joins the
    /// newest splice: it has not taken that splice's offset yet, and it
    /// jumped by about as much.
    private func sameSplice(_ jump: CMTime, _ splice: (jump: CMTime, offset: CMTime), offset: CMTime) -> Bool {
        offset != splice.offset && Self.magnitude(jump - splice.jump) <= Self.spliceMatch
    }

    /// The whole wraps in `jump`, when it is that many wraps give or take
    /// `jumpLimit`.
    private func wraps(in jump: CMTime) -> Int32? {
        guard let wrap, wrap > .zero else { return nil }
        let turns = (jump.seconds / wrap.seconds).rounded()
        guard turns != 0, abs(turns) < 4 else { return nil }
        let rest = jump - CMTimeMultiply(wrap, multiplier: Int32(turns))
        return Self.magnitude(rest) <= Self.jumpLimit ? Int32(turns) : nil
    }

    private static func length(of packet: DemuxedPacket) -> CMTime {
        packet.duration.isNumeric && packet.duration > .zero ? packet.duration : .zero
    }

    private static func magnitude(_ time: CMTime) -> CMTime {
        time < .zero ? CMTime.zero - time : time
    }

    private static func moved(_ packet: DemuxedPacket, by offset: CMTime) -> DemuxedPacket {
        guard offset != .zero else { return packet }
        return DemuxedPacket(
            streamIndex: packet.streamIndex, data: packet.data,
            presentationTime: packet.presentationTime.isNumeric ? packet.presentationTime + offset : packet.presentationTime,
            decodeTime: packet.decodeTime.isNumeric ? packet.decodeTime + offset : packet.decodeTime,
            duration: packet.duration, isKeyframe: packet.isKeyframe, isCorrupt: packet.isCorrupt)
    }
}
