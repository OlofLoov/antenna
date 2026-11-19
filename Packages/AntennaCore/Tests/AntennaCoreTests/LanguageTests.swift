import Foundation
import Testing

@testable import AntennaCore

/// One example per language that the translated catalog resolves: a plural,
/// a grouped count and a time inside a sentence.
@Suite struct LanguageTests {
    static func utc() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }

    /// 22:00 UTC on a fixed day.
    static let ten = Date(timeIntervalSince1970: 1_799_971_200 + 22 * 3_600)

    static func reminder(at start: Date) -> Reminder {
        Reminder(
            id: UUID(), sourceID: UUID(), guideID: "s1", start: start, stop: nil, title: "Matchen",
            channelName: "Sport One", movedFrom: nil, notListed: false, createdAt: start)
    }

    @Test("localization/counts-use-the-language-s-plural-forms Swedish one and other")
    func swedishPlural() {
        let swedish = Locale(identifier: "sv_SE")
        #expect(SourceStatusText(locale: swedish).count(1) == "1 kanal")
        #expect(SourceStatusText(locale: swedish).count(2) == "2 kanaler")
        #expect(SetupText(locale: swedish).channels(ChannelTally(channels: 1, groups: ["News"])) == "1 livekanal i 1 grupp")
    }

    @Test("localization/numbers-use-the-region-s-digits-and-separators a Swedish count groups with a space")
    func swedishCount() {
        #expect(SetupText(locale: Locale(identifier: "sv_SE")).liveChannels(12_500) == "12\u{A0}500 livekanaler")
    }

    @Test("localization/times-and-dates-follow-the-user-s-region a Swedish sentence holds a 24-hour time")
    func swedishTime() {
        let text = ReminderText(calendar: Self.utc(), locale: Locale(identifier: "sv_SE"))
        #expect(text.notificationBody(Self.reminder(at: Self.ten), lead: .five) == "Börjar 22:00 på Sport One")
        #expect(text.day(Self.ten, now: Self.ten) == "I dag")
        #expect(CatalogueGroup.favorites.label(Locale(identifier: "sv_SE")) == "Favoriter")
    }
}
