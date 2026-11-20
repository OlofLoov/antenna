import AntennaCore
import CoreMedia
import Foundation

/// The tracks of a run after streams appeared, or after the run moved to
/// another sound on its own.
struct TrackUpdate: Sendable {
    let audioTracks: [TrackStream]
    let subtitleTracks: [TrackStream]
    /// The sound that plays from now, nil when it did not change.
    let playing: TrackStream?
}

// MARK: Live streams

extension DemuxRun {
    /// How long the sound that plays may send nothing, by the times of
    /// another sound stream that does send, before the run moves to that one.
    static let soundGone = CMTime(value: 3, timescale: 2)

    /// `packet` on the run's timeline. After a jump in the picture's times,
    /// pictures wait for the next keyframe: what comes before it may refer
    /// to pictures of the feed before the jump.
    func place(_ packet: DemuxedPacket, _ prepared: Prepared, _ state: inout PumpState) -> DemuxedPacket {
        guard state.timeline != nil else { return packet }
        let isVideo = packet.streamIndex == prepared.video?.stream.index
        let watched = isVideo || prepared.sounds[packet.streamIndex] != nil
        guard let placed = state.timeline?.place(packet, watched: watched) else { return packet }
        if placed.jumped, isVideo { waitForKeyframe("timestamps jumped", &state) }
        return placed.packet
    }

    /// Takes in streams FFmpeg found after the start: a sound stream gets a
    /// builder and a subtitle stream its decoder, and the engine hears of
    /// the new tracks (playback-engine/sound-that-starts-late-is-played).
    func addStreams(_ prepared: inout Prepared, _ state: inout PumpState) {
        let streams = prepared.demuxer.streams
        state.streamCount = streams.count
        let tracks = DemuxStart.tracks(of: streams)
        for sound in tracks.audio where !prepared.audioTracks.contains(where: { $0.stream.index == sound.stream.index }) {
            prepared.sounds[sound.stream.index] = try? SampleBuilder(stream: sound.stream)
        }
        let newSubtitles = tracks.subtitles.filter { subtitle in
            !prepared.subtitleTracks.contains { $0.stream.index == subtitle.stream.index }
        }
        prepared.pictureSubtitles.merge(DVBSubtitleDecoder.decoders(for: newSubtitles)) { kept, _ in kept }
        for subtitle in newSubtitles { state.subtitleCodecs[subtitle.stream.index] = subtitle.stream.codec }
        guard tracks.audio != prepared.audioTracks || tracks.subtitles != prepared.subtitleTracks else { return }
        prepared.audioTracks = tracks.audio
        prepared.subtitleTracks = tracks.subtitles
        tracksChanged?(TrackUpdate(audioTracks: tracks.audio, subtitleTracks: tracks.subtitles, playing: nil))
    }

    /// Notes where each sound stream has got to, and moves to another sound
    /// when the run has none or the one that plays stopped sending while
    /// another sends: a sound stream that starts after the picture, or a
    /// program whose sound moved to another stream. The new sound is chosen
    /// among the ones that send, by the same rules as at the start. Returns
    /// false once the feed is closed.
    func followSound(_ packet: DemuxedPacket, _ prepared: Prepared, _ state: inout PumpState) -> Bool {
        let time = packet.decodeTime.isNumeric ? packet.decodeTime : packet.presentationTime
        guard time.isNumeric else { return true }
        state.soundEnds[packet.streamIndex] = packet.duration.isNumeric && packet.duration > .zero ? time + packet.duration : time
        guard packet.streamIndex != state.sound, let start = state.startTime else { return true }
        if let playing = state.sound, prepared.sounds[playing] != nil, time - (state.soundEnds[playing] ?? start) <= Self.soundGone {
            return true
        }
        let sending = prepared.audioTracks.filter { track in
            guard prepared.sounds[track.stream.index] != nil, let end = state.soundEnds[track.stream.index] else { return false }
            return time - end <= Self.soundGone
        }
        let pick = TrackChoice.initial(audio: sending.map(\.track), subtitles: [], options: options).audio
        guard let next = sending.first(where: { $0.track.id == pick }) else { return true }
        return takeOverSound(next, from: state.sound == nil ? nil : state.soundQueuedTo, prepared, &state)
    }

    /// Plays `next` from `from` on, out of its ring, after what is queued of
    /// the sound before it. The newest packet in the ring is the one the
    /// run is reading, which the run queues itself.
    private func takeOverSound(_ next: TrackStream, from: CMTime?, _ prepared: Prepared, _ state: inout PumpState) -> Bool {
        let stream = next.stream.index
        state.sound = stream
        guard let builder = prepared.sounds[stream] else { return true }
        guard queueKept(stream, from: from, builder: builder, state, skippingNewest: true) else { return false }
        tracksChanged?(TrackUpdate(audioTracks: prepared.audioTracks, subtitleTracks: prepared.subtitleTracks, playing: next))
        state.soundChannels = Self.channels(builder)
        if let channels = state.soundChannels {
            soundSwitched?(PresentationInfo.Audio(codec: builder.codecName, channels: channels, isDecodable: true))
        }
        return true
    }

    /// Queues the sound of `stream` out of its ring from `from` on, or from
    /// the oldest sound kept when `from` is nil. With `skippingNewest`, the
    /// newest packet is left for the run to queue. Returns false once the
    /// feed is closed.
    func queueKept(_ stream: Int, from: CMTime?, builder: SampleBuilder, _ state: PumpState, skippingNewest: Bool = false) -> Bool {
        guard let ring = state.rings[stream] else { return true }
        let packets = from.map { ring.kept(around: $0) } ?? ring.kept
        for packet in skippingNewest ? packets.dropLast() : packets {
            for buffer in (try? builder.sampleBuffers(for: packet)) ?? [] {
                let end = CMTimeAdd(CMSampleBufferGetPresentationTimeStamp(buffer), CMSampleBufferGetDuration(buffer))
                if let from, end <= from { continue }
                guard audioFeed.push(buffer) else { return false }
            }
        }
        return true
    }
}
