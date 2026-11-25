import AntennaCore
import Foundation
import Testing

/// The remote hints each Apple TV screen lists, where they sit, and the per-device switch.
@Suite struct ControlHintsTests {
    static let screens: [ControlHintScreen] = [
        .livePicture(swipe: .changesChannel), .livePicture(swipe: .showsZapBar), .infoBar(swipe: .changesChannel),
        .infoBar(swipe: .showsZapBar), .overlayGroups, .overlayChannels, .guide, .tabBar, .titleRows(.movie), .titleRows(.series),
        .titlePage, .titlePlayer(scrubbing: false), .titlePlayer(scrubbing: true), .titlePlayer(scrubbing: false, nextEpisode: true),
        .nextEpisodeButton, .upNext(asking: false), .upNext(asking: true), .settings,
    ]

    @Test("control-hints/remote-hints-show-what-the-buttons-do every screen lists between two and five controls, each once")
    func everyScreenHasALegend() {
        for screen in Self.screens {
            let controls = screen.hints(.english).map(\.control)
            #expect((2...5).contains(controls.count), "\(screen)")
            #expect(Set(controls).count == controls.count, "\(screen) names a control twice")
            #expect(screen.hints(.english).allSatisfy { !$0.action.isEmpty })
        }
    }

    @Test("control-hints/each-screen-lists-its-own-actions the overlay's groups and channels differ")
    func overlayColumns() {
        #expect(ControlHintScreen.overlayGroups.hints(.english).first == ControlHint(.swipeUpDown, "Choose a group"))
        #expect(ControlHintScreen.overlayGroups.hints(.english).contains(ControlHint(.back, "Close")))
        #expect(ControlHintScreen.overlayChannels.hints(.english).first == ControlHint(.click, "Watch"))
        #expect(ControlHintScreen.overlayChannels.hints(.english).contains(ControlHint(.hold, "Add to or remove from Favorites")))
    }

    @Test("control-hints/each-screen-lists-its-own-actions the swipe preference decides what up and down say")
    func swipePreference() {
        #expect(ControlHintScreen.livePicture(swipe: .changesChannel).hints(.english).contains(ControlHint(.swipeUpDown, "Change channel")))
        #expect(ControlHintScreen.livePicture(swipe: .showsZapBar).hints(.english).contains(ControlHint(.swipeUpDown, "Info bar")))
        #expect(ControlHintScreen.infoBar(swipe: .showsZapBar).hints(.english).allSatisfy { $0.control != .swipeUpDown })
        #expect(ControlHintScreen.live(swipe: .showsZapBar, infoBar: true) == .infoBar(swipe: .showsZapBar))
        #expect(ControlHintScreen.live(swipe: .changesChannel, infoBar: false) == .livePicture(swipe: .changesChannel))
        #expect(ControlHintScreen.infoBar(swipe: .changesChannel).hints(.english).contains(ControlHint(.back, "Hide the info bar")))
    }

    @Test("control-hints/each-screen-lists-its-own-actions a movie or series poster opens its page")
    func titleRows() {
        for kind in [ShelfTitle.Kind.movie, .series] {
            #expect(
                ControlHintScreen.titleRows(kind).hints(.english)
                    == [ControlHint(.click, "Open"), ControlHint(.hold, "My list"), ControlHint(.back, "Tab bar")])
        }
        #expect(ControlHintScreen.titlePlayer(scrubbing: false).hints(.english).contains(ControlHint(.hold, "Audio and subtitles")))
        #expect(ControlHintScreen.titlePlayer(scrubbing: false).hints(.english).first == ControlHint(.clickLeftRight, "Skip 10 seconds"))
        #expect(ControlHintScreen.titlePlayer(scrubbing: true).hints(.english).contains(ControlHint(.back, "Cancel")))
    }

    @Test("control-hints/each-screen-lists-its-own-actions the end of an episode names the next one")
    func upNext() {
        // up-next/up-next-on-the-siri-remote
        let near = ControlHintScreen.titlePlayer(scrubbing: false, nextEpisode: true).hints(.english)
        #expect(near.contains(ControlHint(.swipeDown, "Next episode")))
        #expect(!near.contains { $0.control == .swipeLeftRight })
        #expect(
            ControlHintScreen.nextEpisodeButton.hints(.english) == [
                ControlHint(.click, "Play the next episode"), ControlHint(.back, "Keep watching"),
            ])
        let card = ControlHintScreen.upNext(asking: false).hints(.english)
        #expect(card.first == ControlHint(.click, "Play now"))
        #expect(card.contains(ControlHint(.clickLeftRight, "Skip 10 seconds")))
        #expect(card.contains(ControlHint(.back, "Cancel")))
        #expect(
            ControlHintScreen.upNext(asking: true).hints(.english) == [ControlHint(.click, "Keep watching"), ControlHint(.back, "Cancel")])
    }

    @Test("control-hints/each-screen-lists-its-own-actions Back reads Tab bar where it reaches the bar, Home Screen in the bar")
    func backToTheTabBar() {
        // tvos-shell/back-from-a-tab-goes-to-the-tab-bar
        for screen in [ControlHintScreen.livePicture(swipe: .changesChannel), .guide, .titleRows(.movie), .titleRows(.series)] {
            #expect(screen.hints(.english).contains(ControlHint(.back, "Tab bar")), "\(screen)")
        }
        // tvos-shell/back-from-the-tab-bar-goes-to-the-home-screen
        #expect(ControlHintScreen.tabBar.hints(.english).contains(ControlHint(.back, "Home Screen")))
    }

    @Test("control-hints/hints-stay-out-of-the-way VoiceOver hears the legend as one sentence")
    func spoken() {
        #expect(ControlHintScreen.titlePage.spoken(.english) == "Remote: Click, Play or choose. Back, Back.")
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

    @Test("control-hints/hints-fade-and-come-back-on-a-new-screen switching between Live, Movies and Series always shows the legend")
    func sectionSwitch() {
        var schedule = ControlHintSchedule()
        var movies: [Bool] = []
        for _ in 0..<4 {
            movies.append(schedule.arrive(at: .titleRows(.movie)))
            _ = schedule.arrive(at: .tabBar)
        }
        #expect(movies == [true, true, true, false])
        let switches = [
            schedule.arrive(at: .titleRows(.series)),
            schedule.arrive(at: .tabBar),
            schedule.arrive(at: .titleRows(.movie)),
            schedule.arrive(at: .tabBar),
            schedule.arrive(at: .livePicture(swipe: .changesChannel)),
            schedule.arrive(at: .tabBar),
            schedule.arrive(at: .titleRows(.movie)),
        ]
        // The tab bar is past its three by now; each section shows anyway.
        #expect(switches == [true, false, true, false, true, false, true])
    }

    @Test("control-hints/hints-fade-and-come-back-on-a-new-screen a title page, a player, Settings or the guide is no switch")
    func noSwitch() {
        var schedule = ControlHintSchedule()
        for _ in 0..<3 {
            _ = schedule.arrive(at: .titleRows(.movie))
            _ = schedule.arrive(at: .titlePage)
        }
        let back = [
            schedule.arrive(at: .titleRows(.movie)),
            schedule.arrive(at: .settings),
            schedule.arrive(at: .titleRows(.movie)),
        ]
        #expect(back == [false, true, false])

        var live = ControlHintSchedule()
        for _ in 0..<3 {
            _ = live.arrive(at: .livePicture(swipe: .changesChannel))
            _ = live.arrive(at: .overlayChannels)
        }
        let guide = live.arrive(at: .guide)
        let picture = live.arrive(at: .livePicture(swipe: .changesChannel))
        #expect(guide)
        #expect(!picture, "the guide is part of Live")
    }

    @Test("control-hints/hints-fade-and-come-back-on-a-new-screen the first channel, movie or episode played since launch shows the legend")
    func firstPlayback() {
        var schedule = ControlHintSchedule()
        for _ in 0..<3 {
            _ = schedule.arrive(at: .titleRows(.series))
            _ = schedule.arrive(at: .titlePage)
        }
        let player = schedule.arrive(at: .titlePlayer(scrubbing: false))
        _ = schedule.arrive(at: .titlePage)
        let picture = schedule.arrive(at: .livePicture(swipe: .changesChannel))
        #expect(player)
        #expect(picture)
    }
}
