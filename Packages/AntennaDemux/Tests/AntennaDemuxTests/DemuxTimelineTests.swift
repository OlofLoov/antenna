import AntennaCore
import AntennaTestSupport
import CoreMedia
import Foundation
import Testing

@testable import AntennaDemux

/// Live MPEG-TS whose times jump or wrap, and whose sound starts late or
/// moves to another stream, played through a run into recording renderers.
@Suite(.serialized, .timeLimit(.minutes(2))) struct DemuxTimelineTests {
    private static func fixture(_ name: String) throws -> URL {
        try FixtureServer.fixtures().appending(path: name)
    }

    /// The largest step between two pictures in the order they show, and
    /// whether no two show at the same time.
    private static func pictureSteps(_ outcome: PictureCheck.Outcome) -> (largest: Double, forward: Bool) {
        let shown = outcome.queued.sorted()
        let steps = zip(shown, shown.dropFirst()).map { CMTimeSubtract($1, $0).seconds }
        return (steps.max() ?? 0, steps.allSatisfy { $0 > 0 })
    }

    /// The largest gap or overlap where one sound buffer meets the next.
    private static func largestJoin(_ outcome: PictureCheck.Outcome) -> Double {
        zip(outcome.sound, outcome.sound.dropFirst()).map { earlier, later in
            abs(CMTimeSubtract(later.time, CMTimeAdd(earlier.time, earlier.duration)).seconds)
        }.max() ?? 0
    }

    /// How far the fixture's last sound buffer starts from its last
    /// picture, by the fixture's own times.
    private static func soundAfterPicture(_ file: String) throws -> Double {
        let bytes = MemoryBytes(try Data(contentsOf: try fixture(file)))
        let demuxer = try Demuxer(read: { bytes.read(into: $0, count: $1) })
        let builder = try SampleBuilder(stream: try #require(demuxer.streams.first { $0.kind == .audio }))
        var picture = CMTime.invalid
        var sound = CMTime.invalid
        while let packet = demuxer.nextPacket() {
            if packet.streamIndex == builder.stream.index {
                for buffer in try builder.sampleBuffers(for: packet) { sound = CMSampleBufferGetPresentationTimeStamp(buffer) }
            } else {
                // The newest picture, also after a jump back.
                let later = !picture.isValid || packet.presentationTime > picture
                let jumpedBack = picture.isValid && CMTimeSubtract(picture, packet.presentationTime).seconds > 1
                if later || jumpedBack { picture = packet.presentationTime }
            }
        }
        return CMTimeSubtract(sound, picture).seconds
    }

    @Test(
        "playback-engine/live-keeps-playing-across-a-timestamp-jump pictures and sound carry on in step",
        arguments: ["jump-forward.ts", "jump-back.ts", "pts-wrap.ts"])
    func carriesOn(file: String) async throws {
        let outcome = try await PictureCheck.run(try Self.fixture(file))
        let duration = file == "pts-wrap.ts" ? 5.0 : 4.0
        #expect(outcome.queued.count >= Int(duration * 25) - 1, "every picture is queued")
        let steps = Self.pictureSteps(outcome)
        #expect(steps.forward)
        #expect(steps.largest < 0.1, "no picture waits for the clock to catch up")
        #expect(Self.largestJoin(outcome) < 0.03, "the sound has no gap and no overlap")
        // The new feed's sound is as far from its picture as the feed has it.
        let lastPicture = try #require(outcome.queued.max())
        let lastSound = try #require(outcome.sound.last?.time)
        #expect(abs(CMTimeSubtract(lastSound, lastPicture).seconds - (try Self.soundAfterPicture(file))) < 0.03)
    }

    @Test("playback-engine/sound-that-starts-late-is-played a sound stream that starts after the picture plays")
    func lateSoundPlays() async throws {
        let outcome = try await PictureCheck.run(try Self.fixture("late-audio.ts"))
        let first = try #require(outcome.sound.first?.time.seconds)
        let start = try #require(outcome.queued.min()?.seconds)
        #expect(abs(first - start - 2) < 0.15, "the sound starts when it appears, two seconds in")
        #expect(outcome.sound.count > 50)
        #expect(Self.largestJoin(outcome) < 0.03)
    }

    @Test("playback-engine/sound-that-starts-late-is-played sound that moves to another stream plays on")
    func movedSoundPlaysOn() async throws {
        let outcome = try await PictureCheck.run(try Self.fixture("audio-pid-change.ts"))
        let first = try #require(outcome.sound.first)
        let last = try #require(outcome.sound.last)
        let span = CMTimeSubtract(CMTimeAdd(last.time, last.duration), first.time).seconds
        #expect(span > 3.8, "sound from the first stream and then the second")
        #expect(Self.largestJoin(outcome) < 0.03)
    }

    // MARK: The timeline

    private static func packet(_ stream: Int, _ ticks: Int64, length: Int64 = 3600) -> DemuxedPacket {
        DemuxedPacket(
            streamIndex: stream, data: Data(), presentationTime: CMTime(value: ticks, timescale: 90_000),
            decodeTime: CMTime(value: ticks, timescale: 90_000), duration: CMTime(value: length, timescale: 90_000),
            isKeyframe: false)
    }

    private static func ticks(_ placed: LiveTimeline.Placed) -> Int64 {
        CMTimeConvertScale(placed.packet.decodeTime, timescale: 90_000, method: .roundHalfAwayFromZero).value
    }

    @Test("playback-engine/live-keeps-playing-across-a-timestamp-jump a jump carries on from the last packet")
    func jumpCarriesOn() {
        var timeline = LiveTimeline(wrap: LiveTimeline.mpegTSWrap)
        _ = timeline.place(Self.packet(0, 90_000), watched: true)
        let next = timeline.place(Self.packet(0, 90_000 + 3600 + 90_000 * 600), watched: true)
        #expect(next.jumped)
        #expect(Self.ticks(next) == 93_600)
        let back = timeline.place(Self.packet(0, 9000), watched: true)
        #expect(back.jumped)
        #expect(Self.ticks(back) == 97_200)
    }

    @Test("playback-engine/live-keeps-playing-across-a-timestamp-jump the sound takes the picture's offset")
    func soundFollowsThePicture() {
        var timeline = LiveTimeline(wrap: LiveTimeline.mpegTSWrap)
        _ = timeline.place(Self.packet(0, 900_000), watched: true)
        _ = timeline.place(Self.packet(1, 900_000 + 1800, length: 1920), watched: true)
        // The new feed: picture at 10 s, its sound 0.3 s later.
        let picture = timeline.place(Self.packet(0, 900_000 * 10), watched: true)
        let sound = timeline.place(Self.packet(1, 900_000 * 10 + 27_000, length: 1920), watched: true)
        #expect(picture.jumped && sound.jumped)
        #expect(Self.ticks(sound) - Self.ticks(picture) == 27_000)
        let subtitle = timeline.place(Self.packet(2, 900_000 * 10 + 9000), watched: false)
        #expect(Self.ticks(subtitle) - Self.ticks(picture) == 9000)
    }

    @Test("playback-engine/live-keeps-playing-across-a-timestamp-jump times that wrap at 33 bits carry on exactly")
    func wrapCarriesOn() {
        var timeline = LiveTimeline(wrap: LiveTimeline.mpegTSWrap)
        let top: Int64 = 1 << 33
        _ = timeline.place(Self.packet(0, top - 3600), watched: true)
        let wrapped = timeline.place(Self.packet(0, 0), watched: true)
        #expect(!wrapped.jumped)
        #expect(Self.ticks(wrapped) == top)
        _ = timeline.place(Self.packet(1, top - 1000, length: 1920), watched: true)
        let sound = timeline.place(Self.packet(1, 920, length: 1920), watched: true)
        #expect(Self.ticks(sound) == top + 920)
    }
}

/// Live streams whose times jump or whose sound starts late, through the engine.
@MainActor
@Suite(.serialized, .timeLimit(.minutes(1))) struct DemuxLiveEngineTests {
    @Test("playback-engine/live-keeps-playing-across-a-timestamp-jump a jump back plays on without buffering")
    func jumpBackPlaysOn() async throws {
        let server = try FixtureServer()
        let base = try await server.start()
        let engine = DemuxEngine(sleep: { _ in }, log: { _ in })
        let states = Recorded(await engine.states())
        let positions = Recorded(await engine.position())
        try await engine.load(base.appending(path: "jump-back.ts"))
        await engine.play()
        // The jump comes two seconds in; the fixture ends at four.
        #expect(await eventually { positions.values.last.map { $0.time >= .milliseconds(3500) } == true })
        let played = states.values.prefix { $0 != .buffering }
        #expect(played.count == states.values.count, "states \(states.values)")
        states.cancel()
        positions.cancel()
        await engine.stop()
        await server.stop()
    }

    @Test("playback-engine/sound-that-starts-late-is-played the late sound is listed, selected and reported")
    func lateSoundIsListed() async throws {
        let server = try FixtureServer()
        let base = try await server.start()
        let engine = DemuxEngine(sleep: { _ in }, log: { _ in })
        let tracks = Recorded(await engine.tracks())
        let presentation = Recorded(await engine.presentation())
        try await engine.load(base.appending(path: "late-audio.ts"))
        await engine.play()
        #expect(await eventually { tracks.values.last?.selectedAudio == "audio-0" })
        #expect(tracks.values.last?.audio.count == 1)
        #expect(await eventually { presentation.values.last??.audio?.channels == 2 })
        tracks.cancel()
        presentation.cancel()
        await engine.stop()
        await server.stop()
    }
}
