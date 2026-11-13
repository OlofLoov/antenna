import AntennaCore
import CoreMedia
import Foundation

/// One stream from open to end on its own thread: FFmpeg demuxes the bytes,
/// `SampleBuilder` makes sample buffers and the feeds take them. Video
/// before the first keyframe and sound before the first picture are
/// dropped, so playback starts on a whole frame.
///
/// Every sound stream with a builder is read, and the last `soundRing` of
/// each kept, so `selectAudio` switches within a moment: what is queued of
/// the old sound is flushed and the new one starts at the clock's time.
/// Text subtitles and DVB subtitle pictures of every stream go to `cueFound`.
final class DemuxRun: @unchecked Sendable {
    private let bytes: any DemuxBytes
    private let videoFeed: SampleFeed
    private let audioFeed: SampleFeed
    private let lock = NSLock()
    private var cancelled = false
    private var answer: Once<Result<DemuxStart, any Error>>?
    private var rateFound: (@Sendable (Double) -> Void)?
    private var waitsForSound = true
    private var options = PlaybackOptions()
    /// A sound switch `selectAudio` or `resendSound` asked for and the run
    /// has not made yet. A nil stream means the sound that plays.
    private var requestedSound: (stream: Int?, from: CMTime)?

    /// Called when a film's saved time or skip target could not be reached
    /// and it starts from the beginning instead.
    var seekFailed: (@Sendable () -> Void)?
    /// Called with each subtitle line of every text subtitle stream, and
    /// each picture of every DVB subtitle stream.
    var cueFound: (@Sendable (TimedCue) -> Void)?
    /// Called when the picture changes size or dynamic range after the start.
    var pictureChanged: (@Sendable (PictureChange) -> Void)?
    /// Called once a sound switch is made, with the new sound's format, and
    /// when the sound that plays changes its channel count.
    var soundSwitched: (@Sendable (PresentationInfo.Audio) -> Void)?

    /// Where a film starts, counted from its beginning; nil from the start.
    private var startAt: CMTime?
    /// The film's zero point from an earlier run of the same film, so a
    /// skip counts from where the film's first run started.
    private var knownOrigin: CMTime?
    /// The zero point `startAt` was counted from, once the skip is made.
    private var seekedOrigin: CMTime?

    /// How much of each sound stream is kept for a switch.
    static let soundRing = CMTime(value: 10, timescale: 1)

    init(bytes: any DemuxBytes, videoFeed: SampleFeed, audioFeed: SampleFeed) {
        self.bytes = bytes
        self.videoFeed = videoFeed
        self.audioFeed = audioFeed
    }

    private var isCancelled: Bool {
        lock.withLock { cancelled }
    }

    /// Fails the start with `failure` if it has not happened yet, and stops
    /// reading. Used when no picture arrives in time.
    func giveUp(_ failure: PlaybackFailure) {
        let answer = lock.withLock { self.answer }
        answer?.call(.failure(failure))
        cancel()
    }

    /// Stops reading. The connection closes and the thread ends quietly.
    func cancel() {
        lock.withLock { cancelled = true }
        bytes.cancel()
        videoFeed.close()
        audioFeed.close()
    }

    /// Plays the sound of the container stream `stream` from `time` on the
    /// stream's clock, the time on screen now.
    func selectAudio(stream: Int, from time: CMTime) {
        lock.withLock { requestedSound = (stream, time) }
    }

    /// Queues the sound that plays again from `time`, out of its ring, as
    /// when the audio renderer dropped what it held.
    func resendSound(from time: CMTime) {
        lock.withLock { requestedSound = (nil, time) }
    }

    private func takeSoundRequest() -> (stream: Int?, from: CMTime)? {
        lock.withLock {
            defer { requestedSound = nil }
            return requestedSound
        }
    }

    /// Starts the thread. `ready` is called exactly once: with the start,
    /// the `PlaybackFailure` that stops the stream from playing, or
    /// `CancellationError` when `cancel` came first. `ended` is called when a
    /// stream that started stops, with nil when the bytes ran out normally.
    /// `rateFound` is called once when the frame rate becomes known after
    /// the start: the start came before enough frames to tell. `options`
    /// chooses the sound and subtitles it starts with.
    func start(
        ready: @escaping @Sendable (Result<DemuxStart, any Error>) -> Void,
        rateFound: @escaping @Sendable (Double) -> Void = { _ in },
        waitsForSound: Bool = true,
        startAt: CMTime? = nil,
        origin: CMTime? = nil,
        options: PlaybackOptions = PlaybackOptions(),
        ended: @escaping @Sendable (PlaybackFailure?) -> Void
    ) {
        self.rateFound = rateFound
        self.startAt = startAt
        knownOrigin = origin
        self.waitsForSound = waitsForSound
        self.options = options
        let answer = Once(ready)
        lock.withLock { self.answer = answer }
        let thread = Thread { [self] in
            run(ready: answer.call, ended: ended)
            answer.call(.failure(CancellationError()))
        }
        thread.name = "se.codecrave.antenna.demux"
        thread.qualityOfService = .userInitiated
        thread.start()
    }

    /// FFmpeg open on the stream, with a builder for the first video stream
    /// and for every sound stream it can build buffers for.
    private struct Prepared {
        let demuxer: Demuxer
        let video: SampleBuilder?
        /// Builders by container stream index.
        let sounds: [Int: SampleBuilder]
        let audioTracks: [TrackStream]
        let subtitleTracks: [TrackStream]
        /// DVB subtitle decoders by container stream index.
        let pictureSubtitles: [Int: DVBSubtitleDecoder]
        /// The sound that plays first, decodable or not.
        let audio: TrackStream?
        let subtitle: TrackStream?
    }

    private func run(
        ready: @escaping @Sendable (Result<DemuxStart, any Error>) -> Void,
        ended: @escaping @Sendable (PlaybackFailure?) -> Void
    ) {
        let prepared: Prepared
        switch prepare() {
        case .success(let value):
            prepared = value
        case .failure(let error):
            if !isCancelled { ready(.failure(error)) }
            return
        }
        defer { prepared.demuxer.close() }
        // A saved time within a film that can skip: start at the keyframe
        // before it. Otherwise the film starts at the beginning.
        if let startAt, bytes.canSeek, let length = prepared.demuxer.duration, startAt < length {
            let origin = knownOrigin ?? prepared.demuxer.seekOrigin
            if prepared.demuxer.seek(to: startAt, from: origin) {
                seekedOrigin = origin
            } else {
                seekFailed?()
            }
        }
        let announced = pump(prepared, ready: ready)
        guard !isCancelled else { return }
        if announced {
            ended(bytes.failureReason)
        } else {
            ready(.failure(bytes.failureReason ?? PlaybackFailure.unreadable))
        }
    }

    /// Looks at the first bytes, opens FFmpeg and picks the streams. HLS at
    /// a raw-looking address goes to Apple's player; a web page is not a
    /// stream.
    private func prepare() -> Result<Prepared, any Error> {
        let bytes = self.bytes
        switch StreamSniff(bytes.peek(512)) {
        case .hls: return .failure(EngineHandoff.toSystemPlayer)
        case .html: return .failure(PlaybackFailure.unreadable)
        case .mpegTS, .matroska, .avi, .other: break
        }
        let demuxer: Demuxer
        do {
            demuxer = try Self.demuxer(over: bytes, options: options)
        } catch {
            return .failure(bytes.failureReason ?? PlaybackFailure.unreadable)
        }
        let video = demuxer.streams.first { $0.kind == .video }
        guard let videoBuilder = Result(catching: { try video.map(SampleBuilder.init) }).success else {
            demuxer.close()
            return .failure(PlaybackFailure.cannotDecode(codec: video?.codec ?? "video"))
        }
        let tracks = DemuxStart.tracks(of: demuxer.streams)
        var sounds: [Int: SampleBuilder] = [:]
        for sound in tracks.audio {
            sounds[sound.stream.index] = try? SampleBuilder(stream: sound.stream)
        }
        guard videoBuilder != nil || !sounds.isEmpty else {
            demuxer.close()
            return .failure(tracks.audio.first.map { PlaybackFailure.cannotDecode(codec: $0.stream.codec) } ?? PlaybackFailure.unreadable)
        }
        // Sound the device can play comes first, so a DTS default with a
        // Dolby Digital second track starts on the Dolby one
        // (playback-engine/streams-start-with-sound-the-device-can-play).
        let playable = Set(tracks.audio.filter { sounds[$0.stream.index] != nil }.map(\.track.id))
        let chosen = TrackChoice.initial(
            audio: tracks.audio.map(\.track), subtitles: tracks.subtitles.map(\.track), options: options, playable: playable)
        let audio = tracks.audio.first { $0.track.id == chosen.audio }
        return .success(
            Prepared(
                demuxer: demuxer, video: videoBuilder, sounds: sounds, audioTracks: tracks.audio, subtitleTracks: tracks.subtitles,
                pictureSubtitles: DVBSubtitleDecoder.decoders(for: tracks.subtitles), audio: audio,
                subtitle: tracks.subtitles.first { $0.track.id == chosen.subtitle }))
    }

    /// What `pump` has seen so far.
    private struct PumpState {
        var startTime: CMTime?
        var heldSound: [CMSampleBuffer] = []
        var announced = false
        var frameTimes: [Double] = []
        var rateKnown: Bool
        /// Set for a stream whose pictures may be interlaced.
        var fields: FieldPictures?
        var fieldsDecided = false
        /// Video before the first keyframe is dropped; after it, everything
        /// goes to the builder, even while a decoder holds pictures back.
        var sawKeyframe = false
        /// The container stream of the sound that plays.
        var sound: Int?
        /// The newest packets of each sound stream with a builder.
        var rings: [Int: [DemuxedPacket]] = [:]
        /// The channel count of the sound last reported.
        var soundChannels: Int?
        /// The picture size and dynamic range last reported.
        var picture: (size: CMVideoDimensions, range: PresentationInfo.DynamicRange)?
    }

    /// Reads packets into the feeds until the end or `cancel`, calling
    /// `ready` once the first picture (and, within half a second of stream,
    /// the first sound) is queued. Returns whether it did.
    private func pump(_ prepared: Prepared, ready: @Sendable (Result<DemuxStart, any Error>) -> Void) -> Bool {
        var state = PumpState(rateKnown: prepared.video?.stream.frameRate != nil)
        state.sound = prepared.audio?.stream.index
        let subtitleCodecs = Dictionary(uniqueKeysWithValues: prepared.subtitleTracks.map { ($0.stream.index, $0.stream.codec) })
        reading: while !isCancelled, let packet = prepared.demuxer.nextPacket() {
            if let request = takeSoundRequest() {
                guard switchSound(to: request, prepared, &state) else { break reading }
            }
            if packet.streamIndex == prepared.video?.stream.index, let builder = prepared.video {
                if !state.sawKeyframe, !packet.isKeyframe { continue }
                state.sawKeyframe = true
                if !state.fieldsDecided {
                    state.fieldsDecided = true
                    state.fields = Self.fieldPictures(for: builder, keyframe: packet)
                }
                for buffer in (try? builder.sampleBuffers(for: packet)) ?? [] {
                    let shown = (try? state.fields?.buffers(from: buffer)) ?? [buffer]
                    for picture in shown {
                        guard takePicture(picture, &state) else { break reading }
                    }
                }
                if packet.isKeyframe, state.announced { notePicture(builder, at: packet.presentationTime, &state) }
            } else if let builder = prepared.sounds[packet.streamIndex] {
                keep(packet, in: &state)
                guard packet.streamIndex == state.sound else { continue }
                for buffer in (try? builder.sampleBuffers(for: packet)) ?? [] {
                    guard takeSound(buffer, &state, hasVideo: prepared.video != nil) else { break reading }
                }
                noteSoundFormat(builder, &state)
            } else if let decoder = prepared.pictureSubtitles[packet.streamIndex] {
                pictureCues(from: packet, decoder: decoder)
            } else if let codec = subtitleCodecs[packet.streamIndex] {
                cue(from: packet, codec: codec)
            }
            // In MPEG-TS the first sound can follow the first keyframe.
            let waited = state.startTime.map { CMTimeSubtract(packet.decodeTime, $0).seconds > 0.5 } ?? false
            let playing = state.sound.flatMap { prepared.sounds[$0] }
            let soundKnown = !waitsForSound || playing == nil || playing?.formatDescription != nil || waited
            if !state.announced, let startTime = state.startTime, soundKnown {
                state.announced = true
                let interlaced = state.fields.map { $0.sawFields || $0.isInterlacedBySPS } ?? false
                let start = describe(prepared, startTime: startTime, frameTimes: state.frameTimes, interlaced: interlaced)
                state.rateKnown = state.rateKnown || start.frameRate != nil || prepared.video == nil
                if let size = start.pictureSize { state.picture = (size, start.dynamicRange) }
                state.soundChannels = start.soundChannels
                ready(.success(start))
            }
        }
        return state.announced
    }

    /// Reports the picture's new size or dynamic range when a keyframe changes them.
    private func notePicture(_ builder: SampleBuilder, at time: CMTime, _ state: inout PumpState) {
        guard let format = builder.formatDescription, format.mediaType == .video else { return }
        let size = CMVideoFormatDescriptionGetDimensions(format)
        let range = SampleBuilder.dynamicRange(of: format)
        if let last = state.picture, last.size.width == size.width, last.size.height == size.height, last.range == range { return }
        state.picture = (size, range)
        pictureChanged?(PictureChange(time: time, size: size, dynamicRange: range, format: format))
    }

    /// Sends the line in a subtitle packet. A line with no length in the
    /// container stays four seconds.
    private func cue(from packet: DemuxedPacket, codec: String) {
        guard packet.presentationTime.isNumeric, let text = SubtitleText.decode(packet.data, codec: codec) else { return }
        let length = packet.duration.isNumeric && packet.duration > .zero ? packet.duration : CMTime(value: 4, timescale: 1)
        cueFound?(
            TimedCue(
                streamIndex: packet.streamIndex, start: packet.presentationTime, end: CMTimeAdd(packet.presentationTime, length), text: text
            ))
    }

    /// Queues a picture. The first one sets the start and lets through the
    /// sound held back for it; the next few tell the frame rate. Returns
    /// false once the feed is closed.
    private func takePicture(_ buffer: CMSampleBuffer, _ state: inout PumpState) -> Bool {
        if state.startTime == nil {
            let first = sampleTime(buffer)
            state.startTime = first
            state.heldSound.filter { sampleTime($0) >= first }.forEach { audioFeed.push($0) }
            state.heldSound = []
        }
        if !state.rateKnown {
            state.frameTimes.append(sampleTime(buffer).seconds)
            if state.announced, state.frameTimes.count >= 6, let rate = FrameRate.estimate(presentationTimes: state.frameTimes) {
                state.rateKnown = true
                rateFound?(rate)
            }
        }
        return videoFeed.push(buffer)
    }

    /// Queues a sound buffer, or holds it back until the first picture.
    /// Returns false once the feed is closed.
    private func takeSound(_ buffer: CMSampleBuffer, _ state: inout PumpState, hasVideo: Bool) -> Bool {
        if hasVideo, state.startTime == nil {
            state.heldSound.append(buffer)
            if state.heldSound.count > 200 { state.heldSound.removeFirst() }
            return true
        }
        if state.startTime == nil { state.startTime = sampleTime(buffer) }
        return audioFeed.push(buffer)
    }

    /// A film counts from the container's start time, or from the zero point
    /// a skip was counted from; otherwise from the first frame. Counting a
    /// skipped film from its first frame would put its position back at zero.
    private func origin(_ prepared: Prepared, firstFrame: CMTime) -> CMTime {
        guard prepared.demuxer.duration != nil else { return firstFrame }
        if prepared.demuxer.startTime.isNumeric { return prepared.demuxer.startTime }
        return seekedOrigin ?? knownOrigin ?? firstFrame
    }

    private func describe(_ prepared: Prepared, startTime: CMTime, frameTimes: [Double], interlaced: Bool) -> DemuxStart {
        let picture = prepared.video?.formatDescription.map(CMVideoFormatDescriptionGetDimensions)
        let builder = prepared.audio.flatMap { prepared.sounds[$0.stream.index] }
        let audio = builder.map(Self.named) ?? prepared.audio?.stream
        return DemuxStart(
            format: prepared.demuxer.format, streams: prepared.demuxer.streams, video: prepared.video.map(Self.named),
            audio: audio, startTime: startTime, duration: prepared.demuxer.duration,
            pictureSize: picture, dynamicRange: prepared.video?.formatDescription.map(SampleBuilder.dynamicRange) ?? .sdr,
            frameRate: prepared.video.flatMap { $0.stream.frameRate ?? FrameRate.estimate(presentationTimes: frameTimes) },
            videoFormat: prepared.video?.formatDescription, isInterlaced: interlaced,
            origin: origin(prepared, firstFrame: startTime),
            canSeek: bytes.canSeek && prepared.demuxer.duration != nil,
            soundChannels: builder.flatMap(Self.channels) ?? prepared.audio?.stream.channels ?? 0,
            soundDecodable: prepared.audio == nil || builder != nil,
            audioTracks: prepared.audioTracks, subtitleTracks: prepared.subtitleTracks,
            selectedAudio: prepared.audio?.track.id, selectedSubtitle: prepared.subtitle?.track.id)
    }

    private func sampleTime(_ buffer: CMSampleBuffer) -> CMTime {
        CMSampleBufferGetPresentationTimeStamp(buffer)
    }
}

// MARK: Sound rings and switches

extension DemuxRun {
    /// Keeps `packet` in its sound stream's ring, dropping what is older than `soundRing`.
    private func keep(_ packet: DemuxedPacket, in state: inout PumpState) {
        guard packet.presentationTime.isNumeric else { return }
        var ring = state.rings[packet.streamIndex, default: []]
        ring.append(packet)
        let oldest = CMTimeSubtract(packet.presentationTime, Self.soundRing)
        if let drop = ring.firstIndex(where: { $0.presentationTime >= oldest }), drop > 0 { ring.removeFirst(drop) }
        state.rings[packet.streamIndex] = ring
    }

    /// Makes a sound switch: drops what is queued of the old sound and
    /// queues the new one from the requested time out of its ring. Returns
    /// false once the feed is closed.
    private func switchSound(to request: (stream: Int?, from: CMTime), _ prepared: Prepared, _ state: inout PumpState) -> Bool {
        let resend = request.stream == nil
        guard let stream = request.stream ?? state.sound, resend || stream != state.sound,
            let track = prepared.audioTracks.first(where: { $0.stream.index == stream })
        else { return true }
        state.sound = stream
        audioFeed.flush()
        // Before the first picture the sound is still held back for it.
        if resend, state.startTime == nil { return true }
        state.heldSound = []
        guard let builder = prepared.sounds[stream] else {
            soundSwitched?(PresentationInfo.Audio(codec: track.stream.codec, channels: track.stream.channels, isDecodable: false))
            return true
        }
        for packet in state.rings[stream] ?? [] where packet.presentationTime >= request.from {
            for buffer in (try? builder.sampleBuffers(for: packet)) ?? [] {
                guard audioFeed.push(buffer) else { return false }
            }
        }
        let channels = Self.channels(builder) ?? track.stream.channels
        state.soundChannels = channels
        soundSwitched?(PresentationInfo.Audio(codec: builder.codecName, channels: channels, isDecodable: true))
        return true
    }

    /// Reports a new channel count of the sound that plays, as when a
    /// channel goes from stereo to 5.1 for a film.
    private func noteSoundFormat(_ builder: SampleBuilder, _ state: inout PumpState) {
        guard state.announced, let channels = Self.channels(builder), channels != state.soundChannels else { return }
        state.soundChannels = channels
        soundSwitched?(PresentationInfo.Audio(codec: builder.codecName, channels: channels, isDecodable: true))
    }
}

/// Calls a result handler at most once, from any thread.
private final class Once<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var handler: (@Sendable (Value) -> Void)?

    init(_ handler: @escaping @Sendable (Value) -> Void) {
        self.handler = handler
    }

    @Sendable func call(_ value: Value) {
        let handler = lock.withLock {
            defer { self.handler = nil }
            return self.handler
        }
        handler?(value)
    }
}

extension Result {
    /// The success value, nil for a failure.
    fileprivate var success: Success? {
        if case .success(let value) = self { return value }
        return nil
    }
}
