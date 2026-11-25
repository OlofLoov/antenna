import AntennaCore
import Foundation
import Testing

/// The Apple TV preview's timing and its one request at a time.
@Suite struct PreviewScheduleTests {
    let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func at(_ seconds: Double) -> Date {
        start.addingTimeInterval(seconds)
    }

    @Test("movies-and-series-browsing/expanded-card-for-the-focused-title-on-apple-tv a title shows once it has rested 0.8 seconds")
    func rest() {
        var schedule = PreviewSchedule()
        schedule.start(on: "banner")
        #expect(schedule.shown == "banner", "the preview starts on the banner's title")
        schedule.focused("a", at: at(0))
        #expect(schedule.check(at: at(0.79)) == nil)
        #expect(schedule.shown == "banner")
        #expect(schedule.due == at(0.8))
        #expect(schedule.check(at: at(0.8)) == "a")
        #expect(schedule.shown == "a")
        #expect(schedule.pending == nil)
        #expect(schedule.check(at: at(5)) == nil, "a rested title is not asked about twice")
    }

    @Test("movies-and-series-browsing/expanded-card-for-the-focused-title-on-apple-tv posters passed on the way never show")
    func fastSwipe() {
        var schedule = PreviewSchedule(shown: "first")
        for index in 0..<10 {
            schedule.focused("passed \(index)", at: at(Double(index) * 0.2))
            #expect(schedule.check(at: at(Double(index) * 0.2 + 0.19)) == nil)
        }
        schedule.focused("eleventh", at: at(2))
        #expect(schedule.check(at: at(2.5)) == nil)
        #expect(schedule.shown == "first", "the preview keeps the first title")
        #expect(schedule.check(at: at(2.8)) == "eleventh")
    }

    @Test("movies-and-series-browsing/expanded-card-for-the-focused-title-on-apple-tv leaving the rows drops the pending title")
    func leaving() {
        var schedule = PreviewSchedule(shown: "a")
        schedule.focused("b", at: at(0))
        schedule.left()
        #expect(schedule.check(at: at(1)) == nil)
        #expect(schedule.shown == "a")
        schedule.focused("a", at: at(2))
        #expect(schedule.pending == nil, "back on the shown title, nothing is pending")
        schedule.start(on: "banner")
        #expect(schedule.shown == "a", "the banner's title is only the first one")
    }

    @Test("movies-and-series-browsing/expanded-card-for-the-focused-title-on-apple-tv back from a page the poster shows at once")
    func restored() {
        var schedule = PreviewSchedule(shown: "a")
        schedule.focused("b", at: at(0))
        #expect(schedule.restored("c") == "c")
        #expect(schedule.shown == "c")
        #expect(schedule.check(at: at(1)) == nil)
    }

    @Test("movies-and-series-browsing/title-details-are-asked-once-per-title one request at a time, the latest title waits")
    func oneAtATime() {
        var queue = OneAtATime()
        #expect(queue.ask("first") == "first")
        #expect(queue.ask("second") == nil)
        #expect(queue.ask("third") == nil)
        #expect(queue.waiting == "third", "the third replaces the second")
        #expect(queue.ask("first") == nil)
        #expect(queue.waiting == "third", "the title being asked about does not wait")
        #expect(queue.finished() == "third")
        #expect(queue.asking == "third")
        #expect(queue.finished() == nil)
        #expect(queue.asking == nil)
        #expect(queue.ask("fourth") == "fourth")
    }

    @Test("movies-and-series-browsing/expanded-card-for-the-focused-title-on-apple-tv the eyebrow is the category alone")
    func eyebrow() {
        let title = ShelfTitle(id: "xtream#h#vod#1", kind: .movie, sourceID: UUID(), name: "The Long Harbor", category: "Thriller")
        let text = BannerText(preview: title, details: ShelfDetails(year: 2024, plot: "A harbour pilot."), locale: .english)
        #expect(text.eyebrow == "Thriller")
        #expect(text.facts == ["2024"])
        #expect(text.description == "A harbour pilot.")
        let bare = ShelfTitle(id: "xtream#h#vod#2", kind: .movie, sourceID: UUID(), name: "Salt Road")
        #expect(BannerText(preview: bare, details: nil, locale: .english).eyebrow.isEmpty)
    }
}
