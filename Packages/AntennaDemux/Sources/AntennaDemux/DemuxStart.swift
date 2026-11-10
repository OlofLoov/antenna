import AntennaCore
import CoreMedia
import Foundation

/// One audio or subtitle track of a run and the container stream it comes from.
struct TrackStream: Sendable, Equatable {
    let track: MediaTrack
    let stream: DemuxedStream
}

/// A subtitle line from the container, timed on the stream's clock.
struct TimedCue: Sendable, Equatable {
    let streamIndex: Int
    let start: CMTime
    let end: CMTime
    let text: String
}

/// The picture changed size or dynamic range partway through, from `time`
/// on the stream's clock.
struct PictureChange: @unchecked Sendable {
    let time: CMTime
    let size: CMVideoDimensions
    let dynamicRange: PresentationInfo.DynamicRange
    let format: CMFormatDescription
}

/// What a run found once its first picture (or, for radio, its first
/// sound) is queued for the renderers.
struct DemuxStart: Sendable {
    let format: String
    let streams: [DemuxedStream]
    let video: DemuxedStream?
    /// The sound stream that plays, decodable or not.
    var audio: DemuxedStream?
    /// The presentation time playback starts at: the first video keyframe,
    /// or the first sound for radio.
    let startTime: CMTime
    /// Nil for live streams.
    let duration: CMTime?
    /// The picture size from the newest keyframe, nil without a picture.
    var pictureSize: CMVideoDimensions?
    /// SDR, HDR10 or HLG, from the newest keyframe's format.
    var dynamicRange: PresentationInfo.DynamicRange
    /// Frames a second: what the container says, or what the first
    /// frames' times show.
    var frameRate: Double?
    /// The newest keyframe's format, for the TV's display criteria.
    var videoFormat: CMFormatDescription?
    /// True when the stream is interlaced and shown deinterlaced.
    let isInterlaced: Bool
    /// The zero point of a film's position: the container's start time.
    /// For live streams, the first picture.
    let origin: CMTime
    /// True for a film whose server takes byte ranges, so it can skip.
    let canSeek: Bool
    /// Channel count of the sound that plays, 0 without sound.
    var soundChannels: Int
    /// False when the sound that plays cannot be decoded and the stream plays without it.
    var soundDecodable: Bool
    /// "audio-n" in stream order.
    let audioTracks: [TrackStream]
    /// "subtitle-n" in stream order, text subtitles only.
    let subtitleTracks: [TrackStream]
    var selectedAudio: MediaTrack.ID?
    var selectedSubtitle: MediaTrack.ID?
}

extension DemuxStart {
    /// The picture and sound format to report.
    var presentation: PresentationInfo {
        let video = self.video.map {
            PresentationInfo.Video(
                width: pictureSize.map { Int($0.width) } ?? $0.width, height: pictureSize.map { Int($0.height) } ?? $0.height,
                frameRate: frameRate, dynamicRange: dynamicRange, codec: $0.codec, isInterlaced: isInterlaced)
        }
        let audio = self.audio.map { PresentationInfo.Audio(codec: $0.codec, channels: soundChannels, isDecodable: soundDecodable) }
        return PresentationInfo(video: video, audio: audio)
    }

    /// The audio and subtitle tracks to report, with the ones that play selected.
    var trackList: TrackList {
        TrackList(
            audio: audioTracks.map(\.track), subtitles: subtitleTracks.map(\.track), selectedAudio: selectedAudio,
            selectedSubtitle: selectedSubtitle)
    }

    /// The tracks of `streams`: every sound, and the subtitles in a text format.
    static func tracks(of streams: [DemuxedStream]) -> (audio: [TrackStream], subtitles: [TrackStream]) {
        let sounds = streams.filter { $0.kind == .audio }
        let texts = streams.filter { $0.kind == .subtitle && SubtitleText.textCodecs.contains($0.codec) }
        func listed(_ streams: [DemuxedStream], _ prefix: String, _ kind: MediaTrack.Kind) -> [TrackStream] {
            zip(streams.indices, streams).map { number, stream in
                TrackStream(
                    track: MediaTrack(
                        id: "\(prefix)-\(number)", kind: kind, languageCode: stream.language, name: stream.title,
                        isDefault: stream.isDefault),
                    stream: stream)
            }
        }
        return (listed(sounds, "audio", .audio), listed(texts, "subtitle", .subtitle))
    }
}
