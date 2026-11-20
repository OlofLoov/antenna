import CoreMedia
import Foundation

// MARK: Pictures

extension DemuxRun {
    /// Queues the pictures of one video packet, or drops it: while the run
    /// waits for a keyframe, when FFmpeg marks it damaged, and when it leads
    /// the keyframe the pictures started at. Returns false once the feed is
    /// closed.
    func takeVideo(_ packet: DemuxedPacket, builder: SampleBuilder, _ state: inout PumpState) -> Bool {
        if takeKeyframeRequest() { waitForKeyframe(nil, &state) }
        if packet.isCorrupt {
            waitForKeyframe("lost video data", &state)
            return true
        }
        if !state.sawKeyframe, !packet.isKeyframe { return true }
        if Self.isLeading(packet, &state) { return true }
        state.sawKeyframe = true
        if !state.fieldsDecided {
            state.fieldsDecided = true
            state.fields = Self.fieldPictures(for: builder, keyframe: packet)
        }
        for buffer in (try? builder.sampleBuffers(for: packet)) ?? [] {
            let shown = (try? state.fields?.buffers(from: buffer)) ?? [buffer]
            for picture in shown {
                guard takePicture(picture, &state) else { return false }
            }
        }
        if packet.isKeyframe, state.announced { notePicture(builder, at: packet.presentationTime, &state) }
        return true
    }

    /// Drops pictures until the next keyframe: a picture that refers to a
    /// damaged or missing one decodes to green or smeared blocks
    /// (playback-engine/undecodable-pictures-are-not-shown). The last
    /// picture stays on screen until then.
    func waitForKeyframe(_ reason: String?, _ state: inout PumpState) {
        if state.sawKeyframe, let reason { pictureDropped?(reason) }
        state.sawKeyframe = false
        state.startKeyframe = nil
    }

    /// Whether `packet` is a picture that leads the keyframe the picture
    /// started at: decoded after it but shown before it, as the RASL pictures
    /// after an HEVC CRA and the B-frames after an open-GOP H.264 keyframe
    /// are. They may refer to pictures before the keyframe, which were never
    /// read, and decode to green or broken pictures
    /// (playback-engine/undecodable-pictures-are-not-shown).
    static func isLeading(_ packet: DemuxedPacket, _ state: inout PumpState) -> Bool {
        if packet.isKeyframe {
            state.startKeyframe = state.sawKeyframe ? nil : packet.presentationTime
            return false
        }
        guard let start = state.startKeyframe, start.isNumeric, packet.presentationTime.isNumeric else { return false }
        return packet.presentationTime < start
    }

    /// Reports the picture's new size or dynamic range when a keyframe changes them.
    func notePicture(_ builder: SampleBuilder, at time: CMTime, _ state: inout PumpState) {
        guard let format = builder.formatDescription, format.mediaType == .video else { return }
        let size = CMVideoFormatDescriptionGetDimensions(format)
        let range = SampleBuilder.dynamicRange(of: format)
        if let last = state.picture, last.size.width == size.width, last.size.height == size.height, last.range == range { return }
        state.picture = (size, range)
        pictureChanged?(PictureChange(time: time, size: size, dynamicRange: range, format: format))
    }
}
