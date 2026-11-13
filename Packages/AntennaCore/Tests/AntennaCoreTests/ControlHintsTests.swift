import AntennaCore
import Foundation
import Testing

/// The remote hints each Apple TV screen lists, where they sit, and the per-device switch.
@Suite struct ControlHintsTests {
    static let screens: [ControlHintScreen] = [
        .livePicture(swipe: .changesChannel), .livePicture(swipe: .showsZapBar), .infoBar(swipe: .changesChannel),
        .infoBar(swipe: .showsZapBar), .overlayGroups, .overlayChannels, .guide, .tabBar, .titleRows(.movie), .titleRows(.series),
        .titlePage, .titlePlayer(scrubbing: false), .titlePlayer(scrubbing: true), .settings,
    ]

    @Test("control-hints/remote-hints-show-what-the-buttons-do every screen lists between two and five controls, each once")
    func everyScreenHasALegend() {
        for screen in Self.screens {
            let controls = screen.hints.map(\.control)
            #expect((2...5).contains(controls.count), "\(screen)")
            #expect(Set(controls).count == controls.count, "\(screen) names a control twice")
            #expect(screen.hints.allSatisfy { !$0.action.isEmpty })
        }
    }

    @Test("control-hints/each-screen-lists-its-own-actions the overlay's groups and channels differ")
    func overlayColumns() {
        #expect(ControlHintScreen.overlayGroups.hints.first == ControlHint(.swipeUpDown, "Choose a group"))
        #expect(ControlHintScreen.overlayGroups.hints.contains(ControlHint(.back, "Close")))
        #expect(ControlHintScreen.overlayChannels.hints.first == ControlHint(.click, "Watch"))
        #expect(ControlHintScreen.overlayChannels.hints.contains(ControlHint(.hold, "Add to or remove from Favorites")))
    }

    @Test("control-hints/each-screen-lists-its-own-actions the swipe preference decides what up and down say")
    func swipePreference() {
        #expect(ControlHintScreen.livePicture(swipe: .changesChannel).hints.contains(ControlHint(.swipeUpDown, "Change channel")))
        #expect(ControlHintScreen.livePicture(swipe: .showsZapBar).hints.contains(ControlHint(.swipeUpDown, "Info bar")))
        #expect(ControlHintScreen.infoBar(swipe: .showsZapBar).hints.allSatisfy { $0.control != .swipeUpDown })
        #expect(ControlHintScreen.live(swipe: .showsZapBar, infoBar: true) == .infoBar(swipe: .showsZapBar))
        #expect(ControlHintScreen.live(swipe: .changesChannel, infoBar: false) == .livePicture(swipe: .changesChannel))
        #expect(ControlHintScreen.infoBar(swipe: .changesChannel).hints.contains(ControlHint(.back, "Hide the info bar")))
    }

    @Test("control-hints/each-screen-lists-its-own-actions a movie poster plays and a series poster opens")
    func titleRows() {
        #expect(ControlHintScreen.titleRows(.movie).hints.first == ControlHint(.click, "Play"))
        #expect(ControlHintScreen.titleRows(.series).hints.first == ControlHint(.click, "Open"))
        #expect(ControlHintScreen.titlePlayer(scrubbing: false).hints.contains(ControlHint(.hold, "Audio and subtitles")))
        #expect(ControlHintScreen.titlePlayer(scrubbing: false).hints.first == ControlHint(.clickLeftRight, "Skip 10 seconds"))
        #expect(ControlHintScreen.titlePlayer(scrubbing: true).hints.contains(ControlHint(.back, "Cancel")))
    }

    @Test("control-hints/hints-stay-out-of-the-way the legend goes top right over full-screen video and the info bar")
    func corners() {
        #expect(ControlHintScreen.infoBar(swipe: .changesChannel).corner == .topTrailing)
        #expect(ControlHintScreen.livePicture(swipe: .changesChannel).corner == .topTrailing)
        #expect(ControlHintScreen.titlePlayer(scrubbing: false).corner == .topTrailing)
        #expect(ControlHintScreen.guide.corner == .bottomTrailing)
        #expect(ControlHintScreen.overlayChannels.corner == .bottomTrailing)
    }

    @Test("control-hints/hints-stay-out-of-the-way VoiceOver hears the legend as one sentence")
    func spoken() {
        #expect(ControlHintScreen.titlePage.spoken == "Remote: Click, Play or choose. Back, Back.")
    }

    @Test("control-hints/turn-remote-hints-off hints are on until switched off, and an unreadable value reads as on")
    func setting() throws {
        #expect(ControlHintsSetting.decode(nil).shows)
        #expect(ControlHintsSetting.decode(Data("not json".utf8)).shows)
        let off = try #require(ControlHintsSetting(shows: false).encoded())
        #expect(ControlHintsSetting.decode(off) == ControlHintsSetting(shows: false))
        #expect(ControlHintsSetting.key == "hints.remote")
    }

    @Test("control-hints/hints-fade-and-come-back-on-a-new-screen the legend shows on a new place, not on the info bar coming and going")
    func schedule() {
        var schedule = ControlHintSchedule()
        let arrivals = [
            schedule.arrive(at: .infoBar(swipe: .changesChannel)),
            // The info bar hiding is the same place.
            schedule.arrive(at: .livePicture(swipe: .changesChannel)),
            // Focus in between screens changes nothing.
            schedule.arrive(at: nil),
            schedule.arrive(at: .livePicture(swipe: .changesChannel)),
            schedule.arrive(at: .overlayGroups),
            // Groups and channels are one overlay.
            schedule.arrive(at: .overlayChannels),
            // Back from the overlay.
            schedule.arrive(at: .livePicture(swipe: .changesChannel)),
        ]
        #expect(arrivals == [true, false, false, false, true, false, true])
        let player = [
            schedule.arrive(at: .titlePlayer(scrubbing: false)),
            // A slide starting a scrub is the same place.
            schedule.arrive(at: .titlePlayer(scrubbing: true)),
        ]
        #expect(player == [true, false])
        #expect(ControlHintSchedule.visibleFor == .seconds(6))
    }

    @Test("control-hints/hints-fade-and-come-back-on-a-new-screen a place shows its legend three times per launch")
    func showingsPerLaunch() {
        var schedule = ControlHintSchedule()
        var shown = 0
        for _ in 0..<5 {
            if schedule.arrive(at: .guide) { shown += 1 }
            _ = schedule.arrive(at: .tabBar)
        }
        #expect(shown == 3)
        var nextLaunch = ControlHintSchedule()
        let again = nextLaunch.arrive(at: .guide)
        #expect(again, "a new launch starts again")
    }
}
