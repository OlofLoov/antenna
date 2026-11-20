import CoreMedia
import Foundation

/// The newest packets of one sound stream, `length` of them by
/// presentation time, kept for a track switch or a resend.
///
/// Adding a packet and letting the oldest go cost the same however many the
/// ring holds. TrueHD sends 1,200 packets a second, so a ring of 10 seconds
/// holds 12,000, and copying them for each new packet took a fifth of a core.
struct SoundRing {
    let length: CMTime
    private var packets: [DemuxedPacket] = []
    /// Index of the oldest packet still kept; the ones before it wait to be
    /// cleared in one go.
    private var head = 0

    init(length: CMTime) {
        self.length = length
    }

    /// The packets kept, oldest first.
    var kept: ArraySlice<DemuxedPacket> { packets[head...] }

    /// The packets kept from the last timed one at or before `time`, or
    /// from the oldest when none is. MPEG-TS gives a time only to the first
    /// frame of each PES packet, so the frames after it come with no time;
    /// they are kept with it.
    func kept(around time: CMTime) -> ArraySlice<DemuxedPacket> {
        let kept = self.kept
        let start = kept.lastIndex { $0.presentationTime.isNumeric && $0.presentationTime <= time } ?? kept.startIndex
        return kept[start...]
    }

    /// Adds `packet` and lets go of the packets more than `length` older.
    /// A packet with no time is kept after a timed one, and goes with it.
    mutating func add(_ packet: DemuxedPacket) {
        let timed = packet.presentationTime.isNumeric
        guard timed || head < packets.count else { return }
        packets.append(packet)
        guard timed else { return }
        let oldest = CMTimeSubtract(packet.presentationTime, length)
        while head < packets.count, !packets[head].presentationTime.isNumeric || packets[head].presentationTime < oldest { head += 1 }
        // Clearing when half the array is spent keeps the work per packet constant.
        if head > 64, head * 2 > packets.count {
            packets.removeFirst(head)
            head = 0
        }
    }
}
