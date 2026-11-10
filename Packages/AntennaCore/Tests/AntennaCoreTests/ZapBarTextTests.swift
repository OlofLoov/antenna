import AntennaCore
import Foundation
import Testing

/// The words and numbers the zap bar and channel overlay share.
@Suite struct ZapBarTextTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("tv-zap-bar-and-number-entry/what-is-on-and-what-is-next time left rounds minutes up")
    func remainingTime() {
        func left(_ seconds: TimeInterval) -> String { RemainingTime.text(until: now.addingTimeInterval(seconds), now: now) }
        #expect(left(26 * 60) == "26 min left")
        #expect(left(25 * 60 + 1) == "26 min left")
        #expect(left(94 * 60) == "1 h 34 min left")
        #expect(left(120 * 60) == "2 h left")
        #expect(left(60) == "1 min left")
        #expect(left(59) == "Ends now")
        #expect(left(0) == "Ends now")
        #expect(left(-300) == "Ends now")
    }

    @Test("tv-zap-bar-and-number-entry/what-is-on-and-what-is-next progress stays between empty and full")
    func progress() {
        let start = now.addingTimeInterval(-15 * 60)
        let end = now.addingTimeInterval(45 * 60)
        #expect(ProgrammeProgress.fraction(start: start, end: end, now: now) == 0.25)
        #expect(ProgrammeProgress.fraction(start: start, end: end, now: start.addingTimeInterval(-60)) == 0)
        #expect(ProgrammeProgress.fraction(start: start, end: end, now: end.addingTimeInterval(60)) == 1)
        #expect(ProgrammeProgress.fraction(start: now, end: now, now: now) == 1)
        #expect(ProgrammeProgress.fraction(start: now, end: now.addingTimeInterval(-10), now: now) == 1)
    }

    @Test("tv-zap-bar-and-number-entry/picture-and-sound-quality picture size badges")
    func pictureBadge() {
        #expect(QualityBadge.picture(height: 2160) == "4K")
        #expect(QualityBadge.picture(height: 4320) == "4K")
        #expect(QualityBadge.picture(height: 1080) == "1080p")
        #expect(QualityBadge.picture(height: 1088) == "1080p")
        #expect(QualityBadge.picture(height: 720) == "720p")
        #expect(QualityBadge.picture(height: 576) == nil)
        #expect(QualityBadge.picture(height: 0) == nil)
    }

    @Test("tv-zap-bar-and-number-entry/picture-and-sound-quality sound badges")
    func soundBadge() {
        func badge(_ codec: String, _ channels: Int, decodable: Bool = true) -> String? {
            QualityBadge.sound(PresentationInfo.Audio(codec: codec, channels: channels, isDecodable: decodable))
        }
        #expect(badge("aac", 6) == "AAC 5.1")
        #expect(badge("eac3", 8) == "E-AC-3 7.1")
        #expect(badge("aac", 2) == "AAC Stereo")
        #expect(badge("mp2", 1) == "MP2 Mono")
        #expect(badge("", 6) == "5.1")
        #expect(badge("aac", 4) == nil)
        #expect(badge("aac", 0) == nil)
        #expect(badge("opus", 2, decodable: false) == nil)
    }
}

/// The zap bar's channel, guide, badge and footer words.
@Suite struct ZapBarWordsTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("tv-zap-bar-and-number-entry/what-is-on-and-what-is-next the guide grid's wording when nothing is on")
    func guideWording() {
        let on = Programme(channelID: "s", start: now.addingTimeInterval(-600), stop: now.addingTimeInterval(1560), title: "Match")
        #expect(
            ZapBarText.line(state: .loaded, current: on, now: now)
                == .programme(title: "Match", progress: 600.0 / 2160, remaining: "26 min left"))
        #expect(ZapBarText.line(state: .loaded, current: nil, now: now) == .message("No programme information"))
        #expect(ZapBarText.line(state: .noData, current: nil, now: now) == .message("No programme information"))
        #expect(ZapBarText.line(state: .loading, current: nil, now: now) == .message("Loading guide…"))
        #expect(ZapBarText.line(state: .failed(.timeout), current: nil, now: now) == .message("Guide unavailable"))
    }

    @Test("tv-zap-bar-and-number-entry/which-channel-this-is the list and the place in it")
    func position() {
        #expect(ZapBarText.position(list: "Sport", index: 4, count: 42) == "Sport · 4 of 42")
        #expect(ZapBarText.position(list: "All channels", index: 131, count: 1312) == "All channels · 131 of 1312")
    }

    @Test("tv-zap-bar-and-number-entry/picture-and-sound-quality LIVE and quality only while playing")
    func badges() {
        let format = PresentationInfo(
            video: .init(width: 1920, height: 1080, frameRate: 25, dynamicRange: .sdr, codec: "h264"),
            audio: .init(codec: "aac", channels: 6, isDecodable: true))
        #expect(ZapBarText.badges(state: .playing, presentation: format) == ["LIVE", "1080p", "AAC 5.1"])
        #expect(ZapBarText.badges(state: .playing, presentation: nil) == ["LIVE"], "before the player reports the format")
        #expect(ZapBarText.badges(state: .buffering, presentation: format) == [])
        #expect(ZapBarText.badges(state: .failed(.unreadable), presentation: format) == [])
        #expect(ZapBarText.badges(state: .loading, presentation: nil) == [])
    }

    @Test("tv-zap-bar-and-number-entry/catch-up-hint the footer names the days")
    func footer() {
        let link = URL(fileURLWithPath: "/a.ts")
        #expect(Channel(id: "a", name: "A", streamURL: link, hasCatchup: true, catchupDays: 7).catchUpFooter == "Catch-up 7 days")
        #expect(Channel(id: "a", name: "A", streamURL: link, hasCatchup: true, catchupDays: 1).catchUpFooter == "Catch-up 1 day")
        #expect(Channel(id: "a", name: "A", streamURL: link, hasCatchup: true).catchUpFooter == "Catch-up")
        #expect(Channel(id: "a", name: "A", streamURL: link).catchUpFooter == nil)
        #expect(ZapBarText.browseHint == "Press to browse channels")
    }
}
