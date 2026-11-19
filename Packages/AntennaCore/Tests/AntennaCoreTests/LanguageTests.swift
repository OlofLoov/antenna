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

    @Test("localization/counts-use-the-language-s-plural-forms German one and other")
    func germanPlural() {
        let german = SetupText(locale: Locale(identifier: "de_DE"))
        #expect(german.channels(ChannelTally(channels: 1, groups: ["News"])) == "1 Live-Sender in 1 Gruppe")
        #expect(german.channels(ChannelTally(channels: 2, groups: ["News", "Sport"])) == "2 Live-Sender in 2 Gruppen")
    }

    @Test("localization/numbers-use-the-region-s-digits-and-separators a German count groups with a period")
    func germanCount() {
        #expect(SetupText(locale: Locale(identifier: "de_DE")).liveChannels(12_500) == "12.500 Live-Sender")
        #expect(SourceStatusText(locale: Locale(identifier: "de_DE")).count(12_500) == "12.500 Sender")
    }

    @Test("localization/durations-follow-the-user-s-language a German programme length")
    func germanDuration() {
        let german = Locale(identifier: "de_DE")
        #expect(GuidePanelText.length(from: Self.ten, to: Self.ten.addingTimeInterval(90 * 60), locale: german) == "1 Std. 30 Min.")
        #expect(GuidePanelText.length(from: Self.ten, to: Self.ten.addingTimeInterval(45 * 60), locale: german) == "45 Min.")
    }

    @Test("localization/counts-use-the-language-s-plural-forms Spanish one and other, Mexico reads the same table")
    func spanishPlural() {
        let spanish = SetupText(locale: Locale(identifier: "es_ES"))
        #expect(spanish.channels(ChannelTally(channels: 1, groups: ["News"])) == "1 canal en directo en 1 grupo")
        #expect(spanish.channels(ChannelTally(channels: 2, groups: ["News", "Sport"])) == "2 canales en directo en 2 grupos")
        #expect(SetupText(locale: Locale(identifier: "es_MX")).liveChannels(12_500) == "12,500 canales en directo")
    }

    @Test("localization/durations-follow-the-user-s-language a Spanish programme length")
    func spanishDuration() {
        let spanish = Locale(identifier: "es_ES")
        #expect(GuidePanelText.length(from: Self.ten, to: Self.ten.addingTimeInterval(90 * 60), locale: spanish) == "1 h 30 min")
        #expect(SourceStatusText(locale: spanish).count(1) == "1 canal")
    }

    @Test("localization/counts-use-the-language-s-plural-forms French one and other")
    func frenchPlural() {
        let french = SetupText(locale: Locale(identifier: "fr_FR"))
        #expect(french.channels(ChannelTally(channels: 1, groups: ["News"])) == "1 chaîne en direct dans 1 groupe")
        #expect(french.channels(ChannelTally(channels: 2, groups: ["News", "Sport"])) == "2 chaînes en direct dans 2 groupes")
        #expect(SourceStatusText(locale: Locale(identifier: "fr_CA")).count(1) == "1 chaîne")
    }
}
