import AntennaCore
import Foundation
import Testing

@Suite struct GuideGridTextTests {
    @Test("tv-guide-grid/channels-without-a-guide-say-so each guide state has its wording")
    func placeholders() {
        #expect(GuidePlaceholder(state: .loaded) == nil)
        #expect(GuidePlaceholder(state: .loading)?.text == "Loading guide…")
        #expect(GuidePlaceholder(state: .noData)?.text == "No programme information")
        #expect(GuidePlaceholder(state: .unavailable)?.text == "No programme information")
        #expect(GuidePlaceholder(state: .failed(.timeout))?.text == "Guide unavailable")
    }

    @Test("tv-guide-grid/the-panel-describes-the-highlighted-programme lengths read as the info bar's without left")
    func lengths() {
        func length(_ minutes: Double) -> String {
            GuidePanelText.length(from: march(22, 20), to: march(22, 20).addingTimeInterval(minutes * 60))
        }
        #expect(length(120) == "2 h")
        #expect(length(90) == "1 h 30 min")
        #expect(length(30) == "30 min")
        #expect(length(29.5) == "30 min")
        #expect(length(0) == "1 min")
    }

    @Test("tv-guide-grid/the-panel-describes-the-highlighted-programme a programme with no title reads Untitled")
    func untitled() {
        let blank = Programme(channelID: "a", start: march(22, 20), stop: march(22, 21), title: "  ")
        #expect(GuidePanelText.title(blank) == "Untitled")
        #expect(GuidePanelText.title(Programme(channelID: "a", start: march(22, 20), stop: march(22, 21), title: "News")) == "News")
        #expect(GuidePanelText.line(["20:00 – 22:00", "2 h", nil, "", "1080p"]) == "20:00 – 22:00 · 2 h · 1080p")
    }
}
