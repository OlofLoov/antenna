import Foundation
import Testing

@testable import AntennaCore

@Suite struct SourceStatusTextTests {
    let text = SourceStatusText(locale: Locale(identifier: "en-US"))
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func row(_ status: SourceStatus, television: Bool = false) -> [String] {
        SourceStatusText(locale: Locale(identifier: "en-US"), television: television).rowLines(status, now: now).map(\.text)
    }

    @Test("sources-and-settings/see-how-each-source-is-doing: one status line per state")
    func rowLines() {
        let twelve = now.addingTimeInterval(-12 * 60)
        let loaded = SourceStatus(load: .loaded, channels: 412, lastSuccess: twelve, guide: .loaded(days: 7, matched: 388, total: 412))
        #expect(row(loaded) == ["412 channels · Guide 7 days · 12 minutes ago"])
        #expect(row(SourceStatus(load: .loading)) == ["Loading…"])
        #expect(row(SourceStatus(load: .loading, lastSuccess: now.addingTimeInterval(-86_400))) == ["Loading… · last loaded yesterday"])
        #expect(row(SourceStatus(load: .loading, channels: 412)) == ["412 channels · Refreshing…"])
        #expect(
            row(SourceStatus(load: .failed("You're offline. Connect to the internet and try again."))) == [
                "You're offline. Connect to the internet and try again."
            ])
        var failed = loaded
        failed.load = .failed("You're offline. Connect to the internet and try again.")
        #expect(
            row(failed) == [
                "412 channels · Guide 7 days · 12 minutes ago", "Could not refresh: You're offline. Connect to the internet and try again.",
            ])
        #expect(row(SourceStatus(load: .waitingForLogin)) == ["Waiting for login from iCloud"])
        #expect(row(SourceStatus(load: .waitingForLogin), television: true) == ["Not signed in on this Apple TV"])
        #expect(row(SourceStatus(load: .waitingForICloud)) == ["Waiting for iCloud…"])
    }

    @Test("sources-and-settings/see-how-each-source-is-doing: the guide part of the loaded line")
    func guidePart() {
        #expect(text.guidePart(SourceStatus(guide: .none)) == "No guide")
        #expect(text.guidePart(SourceStatus(guide: .notStarted)) == "Loading guide…")
        #expect(text.guidePart(SourceStatus(guide: .downloading)) == "Downloading guide…")
        #expect(text.guidePart(SourceStatus(guide: .failed)) == "Guide failed")
        #expect(text.guidePart(SourceStatus(guide: .failed, lastGuideDays: 3)) == "Guide 3 days")
    }

    @Test("sources-and-settings/see-how-each-source-is-doing: the details status block")
    func details() {
        let status = SourceStatus(
            load: .loaded, channels: 412, groups: 18, lastSuccess: now.addingTimeInterval(-12 * 60),
            guide: .loaded(days: 7, matched: 388, total: 412))
        #expect(
            text.detailLines(status, account: "Account active until March 3, 2027 · 2 connections", now: now).map(\.text) == [
                "412 channels in 18 groups", "Guide for 7 days · 388 of 412 channels", "Refreshed 12 minutes ago",
                "Account active until March 3, 2027 · 2 connections",
            ])
        #expect(text.detailLines(SourceStatus(), account: nil, now: now).map(\.text) == ["Not loaded yet"])
        #expect(text.detailLines(SourceStatus(load: .failed("Nope.")), account: nil, now: now).map(\.text) == ["Nope."])
    }
}
