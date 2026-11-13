import AntennaCore
import Foundation
import Testing

/// The times, skips and scrubs of a movie or episode.
@Suite struct TitleTimelineTests {
    let film = TitleTimeline(time: .seconds(600), length: .seconds(5400))

    @Test("player-controls-and-playback-errors/move-around-in-a-movie-or-episode back and forward 10 seconds")
    func skips() {
        #expect(film.skipped(forward: true) == .seconds(610))
        #expect(film.skipped(forward: false) == .seconds(590))
        #expect(film.skipped(by: .seconds(-45)) == .seconds(555))
    }

    @Test("player-controls-and-playback-errors/move-around-in-a-movie-or-episode skips stop at the start and the end")
    func skipsAtTheEnds() {
        #expect(TitleTimeline(time: .seconds(5), length: .seconds(5400)).skipped(forward: false) == .zero)
        #expect(TitleTimeline(time: .seconds(5395), length: .seconds(5400)).skipped(forward: true) == .seconds(5400))
        #expect(TitleTimeline(time: .seconds(5), length: nil).skipped(forward: false) == .zero)
        #expect(TitleTimeline(time: .seconds(9000), length: nil).skipped(forward: true) == .seconds(9010), "no end without a length")
    }

    @Test("player-controls-and-playback-errors/move-around-in-a-movie-or-episode a drag maps the bar to the title")
    func dragging() {
        #expect(film.fraction == 600.0 / 5400)
        #expect(film.time(at: 0.5) == .seconds(2700))
        #expect(film.time(at: -0.2) == .zero)
        #expect(film.time(at: 1.4) == .seconds(5400))
        #expect(TitleTimeline(time: .seconds(10), length: nil).time(at: 0.5) == nil)
        #expect(TitleTimeline(time: .seconds(10), length: nil).fraction == nil)
    }

    @Test("player-controls-and-playback-errors/move-around-in-a-movie-or-episode a slide on Apple TV moves an eighth of the title")
    func sliding() {
        #expect(film.slideSpan == .seconds(675))
        #expect(film.slid(from: .seconds(600), by: 0.5) == .seconds(937.5))
        #expect(film.slid(from: .seconds(600), by: -2) == .zero)
        #expect(TitleTimeline(time: .zero, length: .seconds(240)).slideSpan == .seconds(60), "at least a minute")
        #expect(TitleTimeline(time: .zero, length: .seconds(4 * 3600)).slideSpan == .seconds(1200), "at most 20 minutes")
        #expect(TitleTimeline(time: .zero, length: nil).slid(from: .zero, by: 1) == nil, "only skips without a length")
    }

    @Test("player-controls-and-playback-errors/move-around-in-a-movie-or-episode elapsed and remaining time")
    func text() {
        #expect(TitleTimeline.clock(.seconds(245)) == "4:05")
        #expect(TitleTimeline.clock(.seconds(3723)) == "1:02:03")
        #expect(TitleTimeline.clock(.milliseconds(59_900)) == "0:59")
        #expect(film.elapsedText() == "10:00")
        #expect(film.remainingText() == "-1:20:00")
        #expect(film.remainingText(at: .milliseconds(600_400)) == "-1:20:00", "elapsed rounds down, remaining up")
        #expect(film.elapsedText(at: .seconds(9999)) == "1:30:00")
        #expect(TitleTimeline(time: .seconds(65), length: nil).remainingText() == nil)
    }

    @Test("player-controls-and-playback-errors/move-around-in-a-movie-or-episode VoiceOver reads the time and the length")
    func spoken() {
        #expect(TitleTimeline(time: .seconds(724), length: .seconds(5400)).spokenText() == "12 minutes, 4 seconds of 1 hour, 30 minutes")
        #expect(TitleTimeline(time: .zero, length: nil).spokenText() == "0 seconds")
    }
}
