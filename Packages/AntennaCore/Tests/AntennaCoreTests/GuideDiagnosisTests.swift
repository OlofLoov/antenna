import Foundation
import Testing

@testable import AntennaCore

@Suite struct GuideDiagnosisTests {
    let source = UUID()
    let now = guideTime(20, 30)

    private func channel(_ id: String, _ name: String, epgID: String? = nil, number: Int? = nil) -> Channel {
        Channel(id: id, name: name, streamURL: URL(filePath: "/\(id)"), epgID: epgID, number: number, sourceID: source)
    }

    private func row(_ reference: GuideReference, _ status: GuideStatus, enabled: Bool = true, loaded: Bool = false) -> GuideRow {
        GuideRow(reference: reference, enabled: enabled, status: status, hasGuide: loaded)
    }

    /// One loaded guide: "on" airs now, "ended" ended at 19:00, "listed" has
    /// a channel element and no programmes.
    private func index(matches: [String: GuideMatch] = [:]) -> GuideIndex {
        let guide = SourceGuide(
            [programme("on", guideTime(20), guideTime(21)), programme("ended", guideTime(18), guideTime(19))],
            names: ["on": "On Air", "ended": "Ended", "listed": "Listed"])
        return GuideIndex(sources: [
            source: GuideIndex.SourceEntry(layers: [GuideIndex.Layer(reference: .saved, guide: guide)], state: .loading, matches: matches)
        ])
    }

    private var loaded: GuideSourceStatus {
        GuideSourceStatus(rows: [row(.saved, .loaded(guideTime(19)), loaded: true)])
    }

    @Test("guide-sources-and-channel-mapping/see-why-a-channel-has-no-guide reasons that hold for the whole source")
    func sourceReasons() {
        let any = channel("a", "A", epgID: "on")
        func reason(_ status: GuideSourceStatus) -> GuideReason {
            GuideDiagnosis.reason(for: any, rows: status, index: GuideIndex(), now: now)
        }
        #expect(reason(GuideSourceStatus(rows: [row(.saved, .pending)], playlistLoading: true)) == .playlistLoading)
        #expect(reason(GuideSourceStatus(rows: [row(.provider, .off, enabled: false)])) == .noGuide)
        #expect(
            reason(GuideSourceStatus(rows: [row(.provider, .failed(.credentialMissing)), row(.saved, .failed(.timeout))]))
                == .waitingForLogin)
        #expect(
            reason(GuideSourceStatus(rows: [row(.provider, .failed(.credentialMissing)), row(.saved, .downloading(bytes: 12))]))
                == .notDownloaded(bytes: 12))
        #expect(reason(GuideSourceStatus(rows: [row(.saved, .failed(.offline)), row(.playlist(0), .failed(.offline))])) == .offline)
        #expect(
            reason(GuideSourceStatus(rows: [row(.saved, .failed(.offline)), row(.playlist(0), .failed(.httpStatus(404)))]))
                == .everyGuideFailed)
    }

    @Test("guide-sources-and-channel-mapping/see-why-a-channel-has-no-guide reasons for one channel")
    func channelReasons() {
        let matches = ["picked": GuideMatch(entryID: "missing", origin: .user), "named": GuideMatch(entryID: "on", origin: .name)]
        let index = index(matches: matches)
        func reason(_ channel: Channel) -> GuideReason {
            GuideDiagnosis.reason(for: channel, rows: loaded, index: index, now: now)
        }
        #expect(reason(channel("x", "X")) == .noGuideID)
        #expect(reason(channel("picked", "Picked", epgID: "on")) == .matchNotFound(id: "missing"))
        #expect(reason(channel("y", "Y", epgID: "nowhere")) == .idNotFound(id: "nowhere"))
        #expect(reason(channel("z", "Z", epgID: "listed")) == .noProgrammes(id: "listed"))
        #expect(reason(channel("w", "W", epgID: "ended")) == .guideEnded(id: "ended"))
        #expect(reason(channel("v", "V", epgID: "on")) == .hasGuide(id: "on"))
        #expect(reason(channel("named", "On Air")) == .hasGuide(id: "on"))
    }

    @Test("guide-sources-and-channel-mapping/see-why-a-channel-has-no-guide the cards' words")
    func cards() {
        let text = GuideSourcesText(locale: Locale(identifier: "en_US"))
        let index = index(matches: ["named": GuideMatch(entryID: "on", origin: .name)])
        let status = GuideSourceStatus(rows: [
            row(.saved, .loaded(guideTime(19)), loaded: true), row(.playlist(0), .failed(.httpStatus(404))), row(.added("a"), .pending),
        ])
        func card(_ channel: Channel, _ kind: SourceKind = .m3u) -> GuideSourcesText.Card {
            let context = GuideSourcesText.CardContext(
                channel: channel, source: "Sport Pack", kind: kind, status: status, index: index, now: now,
                guideName: { $0 == .saved ? "Guide URL" : "Other" })
            return text.card(GuideDiagnosis.reason(for: channel, rows: status, index: index, now: now), context)
        }
        let missing = card(channel("s", "Sport One", epgID: "sport1"))
        #expect(missing.title.text == "Guide id “sport1” is not in the guide")
        #expect(
            missing.body == [
                "“Guide URL” does not list “sport1”. Pick an entry below.", "1 of 3 guides could not be downloaded.",
                "1 guide is still downloading.",
            ])
        #expect(
            card(channel("x", "Arena", number: 2), .xtream).body.first?.hasPrefix("The provider sends no epg_channel_id for Arena") == true)
        let named = card(channel("named", "On Air HD"))
        #expect(named.title.text == "Guide from Guide URL")
        #expect(named.body.first == "“On Air” (on) · 1 day · Matched by name")
        #expect(GuideSourcesText.label(.idNotFound(id: "x")) == "Id not found")
    }

    @Test("guide-sources-and-channel-mapping/matches-survive-a-playlist-refresh a renamed or renumbered channel keeps its match")
    func matchSurvives() {
        let index = index(matches: ["xtream.4711": GuideMatch(entryID: "on", origin: .user)])
        let before = channel("xtream.4711", "Sport One", epgID: "sport1", number: 4)
        let after = channel("xtream.4711", "Sport One Extra", epgID: "sport1", number: 40)
        #expect(index.key(for: before) == GuideKey(sourceID: source, epgID: "on"))
        #expect(index.key(for: after) == GuideKey(sourceID: source, epgID: "on"))
        #expect(index.key(for: channel("xtream.9", "Other", epgID: "sport1")) == GuideKey(sourceID: source, epgID: "sport1"))
    }

    @Test("guide-sources-and-channel-mapping/undo-a-hand-picked-match removing a match goes back to the playlist's id")
    func undo() {
        var settings = GuideSettings()
        _ = settings.setMatch("on", for: "c", at: guideTime(1), present: [])
        settings.removeMatch(for: "c", at: guideTime(2))
        #expect(settings.activeMatches.isEmpty)
        let channel = channel("c", "C", epgID: "nowhere")
        #expect(GuideDiagnosis.reason(for: channel, rows: loaded, index: index(), now: now) == .idNotFound(id: "nowhere"))
    }
}

@Suite struct GuideEntrySearchTests {
    private func entry(_ id: String, _ name: String, programmes: Int = 10, position: Int = 0) -> GuideEntry {
        GuideEntry(id: id, name: name, programmes: programmes, guide: .saved, position: position)
    }

    @Test("guide-sources-and-channel-mapping/pick-the-right-guide-entry-by-hand the design's ranking example")
    func ranking() {
        let search = GuideEntrySearch([
            entry("sport1.se", "Sport One HD"), entry("sportone", "Sport One"), entry("eurosport1", "Eurosport One"),
            entry("one.sport", "One Sport"), entry("nyheter.se", "News One"),
        ])
        let result = search.search("Sport One")
        #expect(result.entries.map(\.name) == ["Sport One", "Sport One HD", "Eurosport One", "One Sport"])
        #expect(result.total == 4)
        #expect(search.search("").entries.isEmpty)
        #expect(search.search("nyheter").entries.map(\.id) == ["nyheter.se"])
    }

    @Test("guide-sources-and-channel-mapping/pick-the-right-guide-entry-by-hand at most 200 rows, with the total")
    func cap() {
        let search = GuideEntrySearch((0..<250).map { entry("id\($0)", "Channel \($0)") })
        let result = search.search("channel")
        #expect(result.entries.count == 200)
        #expect(result.total == 250)
    }

    @Test("guide-sources-and-channel-mapping/pick-the-right-guide-entry-by-hand one row per id, named by the guide that wins")
    func entries() {
        let source = UUID()
        let top = SourceGuide([], names: ["x": "Top name"])
        let lower = SourceGuide([programme("x", guideTime(20), guideTime(21))], names: ["x": "Lower name", "y": "Only listed"])
        let index = GuideIndex(sources: [
            source: GuideIndex.SourceEntry(
                layers: [GuideIndex.Layer(reference: .playlist(0), guide: top), GuideIndex.Layer(reference: .saved, guide: lower)],
                state: .loading)
        ])
        let found = index.entries(sourceID: source).sorted { $0.id < $1.id }
        #expect(found.map(\.id) == ["x", "y"])
        #expect(found.first?.name == "Lower name")
        #expect(found.first?.guide == .saved)
        #expect(found.first?.programmes == 1)
        #expect(found.last?.programmes == 0)
    }
}
