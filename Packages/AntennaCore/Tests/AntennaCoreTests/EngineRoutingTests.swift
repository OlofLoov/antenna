import AntennaCore
import AntennaTestSupport
import Foundation
import Testing

@Suite struct EngineRouterTests {
    @Test(
        "playback-engine/every-common-stream-type-plays HLS and ordinary files go to Apple's player",
        arguments: ["m3u8", "mp4", "mov", "m4v", "mp3", "aac", "m4a", "M3U8", "MP4"])
    func systemExtensions(ext: String) {
        #expect(EngineRouter.route(for: .test("http://panel.example:8080/live/u/p/42.\(ext)?token=t")) == .system)
    }

    @Test(
        "playback-engine/every-common-stream-type-plays raw streams, Matroska, AVI and no extension go to the demuxer",
        arguments: [
            "http://panel.example/live/u/p/42.ts", "http://panel.example/movie/u/p/7.mkv", "http://panel.example/movie/u/p/7.avi",
            "http://panel.example/live/u/p/42", "http://panel.example/play.php?id=3", "http://panel.example/",
        ])
    func demuxerAddresses(address: String) {
        #expect(EngineRouter.route(for: .test(address)) == .demuxer)
    }

    @Test("playback-engine/every-common-stream-type-plays the first bytes tell HLS, MPEG-TS and web pages apart")
    func sniffing() throws {
        let root = try FixtureServer.fixtures()
        #expect(StreamSniff(try Data(contentsOf: root.appending(path: "hls/index.m3u8"))) == .hls)
        #expect(StreamSniff(Data("\u{FEFF}\n  #EXTM3U\n".utf8)) == .hls)
        #expect(StreamSniff(try Data(contentsOf: root.appending(path: "channel.ts"))) == .mpegTS)
        #expect(StreamSniff(try Data(contentsOf: root.appending(path: "page.html"))) == .html)
        #expect(StreamSniff(try Data(contentsOf: root.appending(path: "garbage.bin"))) == .other)
        #expect(StreamSniff(try Data(contentsOf: root.appending(path: "film.mp4"))) == .other)
        #expect(StreamSniff(Data()) == .other)
    }

    @Test("playback-engine/every-common-stream-type-plays the first bytes tell Matroska and AVI, which only the demuxer reads")
    func sniffingFilesForTheDemuxer() throws {
        let root = try FixtureServer.fixtures()
        let matroska = StreamSniff(try Data(contentsOf: root.appending(path: "film.mkv")))
        let avi = StreamSniff(try Data(contentsOf: root.appending(path: "channel.avi")))
        #expect(matroska == .matroska)
        #expect(avi == .avi)
        #expect(matroska.needsDemuxer && avi.needsDemuxer && StreamSniff.mpegTS.needsDemuxer)
        #expect(!StreamSniff.hls.needsDemuxer && !StreamSniff.other.needsDemuxer && !StreamSniff.html.needsDemuxer)
        #expect(!StreamSniff(try Data(contentsOf: root.appending(path: "film.mp4"))).needsDemuxer)
    }
}

@Suite(.timeLimit(.minutes(1))) struct RoutedEngineTests {
    let log = EngineLog()
    let system: FakeEngine
    let demuxer: FakeEngine
    let routed: RoutedEngine

    init() {
        system = FakeEngine("system", log: log)
        demuxer = FakeEngine("demuxer", log: log)
        routed = RoutedEngine(system: system, demuxer: demuxer)
    }

    @Test("playback-engine/every-common-stream-type-plays each address loads on its route")
    func routesByAddress() async throws {
        try await routed.load(.test("http://x/a.m3u8"))
        try await routed.load(.test("http://x/live/1.ts"))
        #expect(
            await log.entries == ["system.load a.m3u8", "system.stop", "demuxer.load 1.ts"])
        #expect(await routed.activeEngine === demuxer)
    }

    @Test("playback-engine/every-common-stream-type-plays a raw-looking address that is HLS plays on Apple's player with no error")
    func handsOffToTheSystemPlayer() async throws {
        await demuxer.script(.failure(EngineHandoff.toSystemPlayer))
        var states = await routed.states().makeAsyncIterator()
        try await routed.load(.test("http://x/live/1"))
        await routed.play()
        #expect(await log.entries == ["demuxer.load 1", "demuxer.stop", "system.load 1", "system.play"])
        #expect(await routed.activeEngine === system)
        var seen: [PlaybackState] = []
        while let state = await states.next() {
            seen.append(state)
            if state == .playing { break }
        }
        #expect(!seen.contains { if case .failed = $0 { true } else { false } })
    }

    @Test("playback-engine/every-common-stream-type-plays a file address whose bytes are Matroska plays on the demuxer with no error")
    func handsOffToTheDemuxer() async throws {
        await system.script(.failure(EngineHandoff.toDemuxer))
        var states = await routed.states().makeAsyncIterator()
        try await routed.load(.test("http://x/series/u/p/9.mp4"))
        await routed.play()
        #expect(await log.entries == ["system.load 9.mp4", "system.stop", "demuxer.load 9.mp4", "demuxer.play"])
        #expect(await routed.activeEngine === demuxer)
        var seen: [PlaybackState] = []
        while let state = await states.next() {
            seen.append(state)
            if state == .playing { break }
        }
        #expect(!seen.contains { if case .failed = $0 { true } else { false } })
    }

    @Test("playback-engine/starting-a-channel-replaces-the-old-one-cleanly the old engine stops before the new one loads")
    func stopsTheOldEngineFirst() async throws {
        try await routed.load(.test("http://x/1.ts"))
        await routed.play()
        try await routed.load(.test("http://x/2.m3u8"))
        let entries = await log.entries
        let stop = try #require(entries.firstIndex(of: "demuxer.stop"))
        let load = try #require(entries.firstIndex(of: "system.load 2.m3u8"))
        #expect(stop < load)
    }

    @Test("playback-engine/starting-a-channel-replaces-the-old-one-cleanly a newer load abandons the older one quietly")
    func newerLoadCancelsOlder() async throws {
        await demuxer.holdLoads()
        let first = Task { try await routed.load(.test("http://x/1.ts")) }
        #expect(await eventually { await demuxer.isHolding })
        await demuxer.release()
        try await routed.load(.test("http://x/2.m3u8"))
        await #expect(throws: CancellationError.self) { try await first.value }
    }

    @Test("playback-engine/starting-a-channel-replaces-the-old-one-cleanly stop abandons a pending load and reports idle")
    func stopCancelsPendingLoad() async throws {
        await demuxer.holdLoads()
        let pending = Task { try await routed.load(.test("http://x/1.ts")) }
        #expect(await eventually { await demuxer.isHolding })
        await routed.stop()
        await demuxer.release()
        await #expect(throws: CancellationError.self) { try await pending.value }
        #expect(await routed.state == .idle)
    }

    @Test("playback-engine/starting-a-channel-replaces-the-old-one-cleanly nothing from the previous engine is reported after a switch")
    func forwardsOnlyTheActiveEngine() async throws {
        let info = PresentationInfo(video: nil, audio: .init(codec: "aac", channels: 2, isDecodable: true))
        let seen = Collected<PresentationInfo?>()
        let watcher = Task { for await value in await routed.presentation() { await seen.add(value) } }
        defer { watcher.cancel() }
        try await routed.load(.test("http://x/1.ts"))
        await demuxer.send(info)
        #expect(await eventually { await seen.last == info })
        try await routed.load(.test("http://x/2.m3u8"))
        #expect(await eventually { await seen.last == .some(nil) })
        await demuxer.send(info)
        await system.send(.playing)
        #expect(await eventually { await routed.state == .playing })
        try await Task.sleep(for: .milliseconds(50))
        #expect(await seen.last == .some(nil))
    }

    @Test func oneEngineForBothRoutesIsNeverStoppedBySwitching() async throws {
        let shared = FakeEngine("shared", log: log)
        let routed = RoutedEngine(system: shared, demuxer: shared)
        try await routed.load(.test("http://x/1.ts"))
        try await routed.load(.test("http://x/2.m3u8"))
        #expect(await log.entries == ["shared.load 1.ts", "shared.load 2.m3u8"])
    }

    @Test func forwardsControlsToTheActiveEngine() async throws {
        try await routed.load(.test("http://x/2.m3u8"))
        await routed.pause()
        await routed.selectAudio("audio-1")
        await routed.selectSubtitle(nil)
        try await routed.seek(to: .seconds(3))
        #expect(await log.entries.suffix(4) == ["system.pause", "system.audio audio-1", "system.subtitle off", "system.seek"])
        #expect(await routed.capabilities.supportsPictureInPicture)
    }
}
