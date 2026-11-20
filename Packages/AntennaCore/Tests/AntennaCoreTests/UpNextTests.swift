import AntennaCore
import Foundation
import Testing

/// When the Next episode button and the Up next card show, which episode
/// is next, the countdown, Cancel and "Still watching?".
@Suite struct UpNextTests {
    static func episode(_ id: Int, season: Int?, number: Int?, title: String = "Episode") -> Episode {
        Episode(id: "e\(id)", episodeID: id, season: season, number: number, title: title)
    }

    static let length: Duration = .seconds(45 * 60)

    // MARK: Which episode is next

    static let series: [Episode] = [
        episode(1, season: 1, number: 1), episode(2, season: 1, number: 2),
        episode(3, season: 2, number: 1), episode(4, season: 2, number: 2),
        episode(5, season: 0, number: 1), episode(6, season: 0, number: 2),
        episode(7, season: nil, number: nil), episode(8, season: nil, number: nil),
    ]

    @Test("up-next/which-episode-is-next the next one in the season, then the next season")
    func nextInOrder() {
        let all = Self.series
        #expect(UpNext.next(after: all[0], in: all)?.id == "e2")
        #expect(UpNext.next(after: all[1], in: all)?.id == "e3")
        #expect(UpNext.next(after: all[2], in: all)?.id == "e4")
    }

    @Test("up-next/which-episode-is-next the last season leads nowhere, not to specials or the start")
    func noWrap() {
        let all = Self.series
        #expect(UpNext.next(after: all[3], in: all) == nil)
        #expect(UpNext.next(after: all[4], in: all)?.id == "e6")
        #expect(UpNext.next(after: all[5], in: all) == nil)
        #expect(UpNext.next(after: all[6], in: all)?.id == "e8")
        #expect(UpNext.next(after: all[7], in: all) == nil)
        #expect(UpNext.next(after: Self.episode(99, season: 1, number: 9), in: all) == nil)
    }

    @Test("up-next/which-episode-is-next a gap in the seasons goes to the next one there is")
    func seasonGap() {
        let all = [Self.episode(1, season: 1, number: 1), Self.episode(2, season: 3, number: 1)]
        #expect(UpNext.next(after: all[0], in: all)?.id == "e2")
    }

    // MARK: The button and the card

    @Test("up-next/next-episode-near-the-end the button from 60 seconds before the end")
    func button() {
        var timer = UpNextTimer()
        timer.position(.seconds(43 * 60 + 59), length: Self.length, asks: false)
        #expect(timer.offer == .none)
        timer.position(.seconds(44 * 60), length: Self.length, asks: false)
        #expect(timer.offer == .button)
        timer.position(.seconds(44 * 60 + 44), length: Self.length, asks: false)
        #expect(timer.offer == .button)
    }

    @Test("up-next/up-next-counts-down the card from 15 seconds, counting down to the next episode")
    func countdown() {
        var timer = UpNextTimer()
        timer.position(.seconds(44 * 60 + 45), length: Self.length, asks: false)
        #expect(timer.offer == .countdown(10))
        timer.position(.seconds(44 * 60 + 46), length: Self.length, asks: false)
        #expect(timer.offer == .countdown(10))
        for left in (1...9).reversed() {
            #expect(timer.tick() == .stay)
            #expect(timer.offer == .countdown(left))
        }
        #expect(timer.tick() == .playNext)
    }

    @Test("up-next/up-next-counts-down an end during the count plays the next episode at once")
    func endDuringCount() {
        var timer = UpNextTimer()
        timer.position(.seconds(44 * 60 + 50), length: Self.length, asks: false)
        _ = timer.tick()
        #expect(timer.ended(asks: false) == .playNext)
    }

    @Test("up-next/up-next-counts-down a short episode or no length shows the card at the end")
    func shortOrUnknown() {
        for length in [Duration.seconds(180), nil] {
            var timer = UpNextTimer()
            timer.position(.seconds(175), length: length, asks: false)
            #expect(timer.offer == .none)
            #expect(timer.ended(asks: false) == .stay)
            #expect(timer.offer == .countdown(10))
            for _ in 1..<10 { #expect(timer.tick() == .stay) }
            #expect(timer.tick() == .playNext)
        }
    }

    @Test("up-next/up-next-counts-down moving back hides both and the count starts again")
    func movingBack() {
        var timer = UpNextTimer()
        timer.position(.seconds(44 * 60 + 50), length: Self.length, asks: false)
        _ = timer.tick()
        _ = timer.tick()
        timer.position(.seconds(44 * 60 + 40), length: Self.length, asks: false)
        #expect(timer.offer == .button)
        timer.position(.seconds(40 * 60), length: Self.length, asks: false)
        #expect(timer.offer == .none)
        timer.position(.seconds(44 * 60 + 50), length: Self.length, asks: false)
        #expect(timer.offer == .countdown(10))
    }

    @Test("up-next/up-next-counts-down playing again after the end hides the card")
    func playingAfterEnd() {
        var timer = UpNextTimer()
        _ = timer.ended(asks: false)
        timer.playing()
        #expect(timer.offer == .none)
        #expect(!timer.hasEnded)
    }

    // MARK: Cancel

    @Test("up-next/cancel-keeps-watching nothing shows again and the end closes")
    func cancel() {
        var timer = UpNextTimer()
        timer.position(.seconds(44 * 60 + 50), length: Self.length, asks: false)
        #expect(timer.cancel() == .stay)
        #expect(timer.offer == .none)
        timer.position(.seconds(44 * 60 + 55), length: Self.length, asks: false)
        #expect(timer.offer == .none)
        #expect(timer.ended(asks: false) == .close)
    }

    @Test("up-next/cancel-keeps-watching Cancel on the card over an ended episode closes")
    func cancelAfterEnd() {
        var timer = UpNextTimer()
        _ = timer.ended(asks: false)
        #expect(timer.cancel() == .close)
    }

    // MARK: Still watching

    @Test("up-next/still-watching after three episodes on their own the card asks and waits")
    func stillWatching() {
        var run = UpNextRun()
        for _ in 0..<2 { run.autoplayed() }
        #expect(!run.asks)
        run.autoplayed()
        #expect(run.asks)
        var timer = UpNextTimer()
        timer.position(.seconds(44 * 60 + 50), length: Self.length, asks: run.asks)
        #expect(timer.offer == .asking)
        #expect(timer.tick() == .stay)
        #expect(timer.ended(asks: run.asks) == .stay)
        #expect(timer.offer == .asking)
    }

    @Test("up-next/still-watching any input starts the run again and the count comes back")
    func inputResets() {
        var run = UpNextRun()
        for _ in 0..<3 { run.autoplayed() }
        run.input()
        #expect(run.inRow == 0)
        var timer = UpNextTimer()
        timer.position(.seconds(44 * 60 + 50), length: Self.length, asks: true)
        timer.input()
        #expect(timer.offer == .countdown(10))
    }

    // MARK: Words and the setting

    @Test("up-next/up-next-counts-down the card's words and what VoiceOver reads")
    func text() {
        let next = Self.episode(5, season: 2, number: 5, title: "The Long Night")
        #expect(UpNextText.title(next, locale: .english) == "S2 E5 · The Long Night")
        #expect(UpNextText.title(Self.episode(9, season: nil, number: nil, title: "Pilot"), locale: .english) == "Pilot")
        #expect(UpNextText.heading(.countdown(7), locale: .english) == "Next episode in 7")
        #expect(UpNextText.heading(.asking, locale: .english) == "Still watching?")
        #expect(UpNextText.heading(.button, locale: .english) == nil)
        #expect(
            UpNextText.spoken(next, offer: .countdown(10), locale: .english)
                == "Up next, Season 2 Episode 5, The Long Night, next episode in 10 seconds")
    }

    @Test("up-next/turn-autoplay-off on by default, kept as JSON, unreadable reads as on")
    func setting() {
        #expect(AutoplaySetting.decode(nil).plays)
        #expect(AutoplaySetting.decode(Data("junk".utf8)).plays)
        #expect(!AutoplaySetting.decode(AutoplaySetting(plays: false).encoded()).plays)
        #expect(AutoplaySetting.key == "player.autoplay")
    }
}
