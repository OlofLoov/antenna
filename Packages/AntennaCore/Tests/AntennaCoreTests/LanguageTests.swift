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
        #expect(spanish.channels(ChannelTally(channels: 1, groups: ["News"])) == "1 canal en vivo en 1 grupo")
        #expect(spanish.channels(ChannelTally(channels: 2, groups: ["News", "Sport"])) == "2 canales en vivo en 2 grupos")
        #expect(SetupText(locale: Locale(identifier: "es_MX")).liveChannels(12_500) == "12,500 canales en vivo")
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
        #expect(SourceStatusText(locale: Locale(identifier: "fr_FR")).count(0) == "0 chaîne")
    }

    @Test("localization/the-app-speaks-the-user-s-language Portugal reads the Brazilian table")
    func portuguese() {
        #expect(SourceStatusText(locale: Locale(identifier: "pt_BR")).count(2) == "2 canais")
        #expect(SourceStatusText(locale: Locale(identifier: "pt_PT")).count(1) == "1 canal")
        #expect(CatalogueGroup.favorites.label(Locale(identifier: "pt_PT")) == "Favoritos")
    }

    static let arabic = Locale(identifier: "ar_SA")

    @Test("localization/counts-use-the-language-s-plural-forms Arabic zero, one, two, few, many and other")
    func arabicPlural() {
        let text = SourceStatusText(locale: Self.arabic)
        #expect(text.count(0) == "٠ قناة")
        #expect(text.count(1) == "قناة واحدة")
        #expect(text.count(2) == "قناتان")
        #expect(text.count(3) == "٣ قنوات")
        #expect(text.count(11) == "١١ قناة")
        #expect(text.count(100) == "١٠٠ قناة")
        let setup = SetupText(locale: Self.arabic)
        #expect(setup.channels(ChannelTally(channels: 2, groups: ["News", "Sport"])) == "قناتان مباشرتان في مجموعتين")
        #expect(setup.channels(ChannelTally(channels: 11, groups: ["News"])) == "١١ قناة مباشرة في مجموعة واحدة")
        #expect(KeyCommand.skipTitle(forward: false, seconds: 10, locale: Self.arabic) == "رجوع ١٠ ثوانٍ")
        #expect(KeyCommand.skipTitle(forward: true, seconds: 30, locale: Self.arabic) == "تقديم ٣٠ ثانية")
    }

    @Test("localization/numbers-use-the-region-s-digits-and-separators Saudi Arabia writes Arabic-Indic digits")
    func arabicDigits() {
        #expect(ChannelNumber(major: 1001).text(Self.arabic) == "١٠٠١")
        #expect(ChannelNumber(major: 6, minor: 1).text(Self.arabic) == "٦.١")
        #expect(SetupText(locale: Self.arabic).liveChannels(12_500) == "١٢٬٥٠٠ قناة مباشرة")
    }

    @Test("localization/mixed-scripts-keep-their-own-direction a Latin name inside an Arabic sentence is isolated")
    func arabicIsolatesLatinName() {
        let reply = IntentFailure.alreadyFavorite(channel: "BBC One").description(Self.arabic)
        #expect(reply == "\u{2068}BBC One\u{2069} موجودة بالفعل في المفضلة.")
        #expect(reply.withoutIsolates == "BBC One موجودة بالفعل في المفضلة.")
        let english = IntentFailure.alreadyFavorite(channel: "BBC One").description(Locale(identifier: "en_US"))
        #expect(english == "BBC One is already a favorite.")
    }

    @Test("localization/the-app-speaks-the-user-s-language a one-unit intro offer reads in French and Swedish")
    func oneUnitOffer() {
        let week = IntroOffer(payment: .freeTrial, displayPrice: "0", unit: .week)
        let month = IntroOffer(payment: .payUpFront, displayPrice: "19 kr", unit: .month)
        let monthly = IntroOffer(payment: .payAsYouGo, displayPrice: "9 kr", unit: .month, periodCount: 3)
        let french = Locale(identifier: "fr_FR")
        let swedish = Locale(identifier: "sv_SE")
        #expect(
            PaywallCopy.yearlyLine(offer: week, displayPrice: "9,99 €", locale: french).text
                == "Essai gratuit\u{A0}: 1 semaine, puis 9,99 € par an")
        #expect(
            PaywallCopy.yearlyLine(offer: month, displayPrice: "9,99 €", locale: french).text == "19 kr pendant 1 mois, puis 9,99 € par an")
        #expect(PaywallCopy.yearlyLine(offer: week, displayPrice: "99 kr", locale: swedish).text == "Gratis i 1 vecka, sedan 99 kr per år")
        #expect(
            PaywallCopy.yearlyLine(offer: monthly, displayPrice: "99 kr", locale: swedish).text
                == "9 kr per period om 1 månad i 3 månader, sedan 99 kr per år")
        #expect(
            PaywallCopy.yearlyLine(offer: month, displayPrice: "$9.99", locale: Locale(identifier: "en_US")).text
                == "19 kr for the first month, then $9.99 per year")
    }

    @Test("localization/the-app-speaks-the-user-s-language what VoiceOver reads for scores and the player position")
    func spokenInSwedish() {
        let swedish = Locale(identifier: "sv_SE")
        #expect(Score(site: .tmdb, value: 7.4, scale: 10).spoken(swedish) == "TMDB-användarbetyg 74 procent")
        #expect(TitleMetadata.spokenRating(7.4, locale: swedish) == "betyg 7.4 av 10")
        #expect(TitleTimeline(time: .zero, length: nil).spokenText(locale: swedish) == "0 sekunder")
    }

    @Test("localization/numbers-use-the-region-s-digits-and-separators Arabic detail lines use a bullet, not a middle dot")
    func arabicDetailSeparator() {
        #expect(["Sport One", "١٠٤"].joinedAsDetail(Self.arabic) == "Sport One • ١٠٤")
        #expect(SearchText.chip(.channels, count: 3, locale: Self.arabic).hasSuffix(" • 3"))
        #expect(["Sport One", "104"].joinedAsDetail(Locale(identifier: "en_US")) == "Sport One · 104")
        #expect(["Sport One", "104"].joinedAsDetail(Locale(identifier: "sv_SE")) == "Sport One · 104")
    }

    @Test(
        "localization/the-app-speaks-the-user-s-language the live badge stays the live badge in every language",
        arguments: ["en_US", "sv_SE", "de_DE", "es_ES", "fr_FR", "pt_BR", "ar_SA"])
    func liveBadgeKind(identifier: String) {
        let locale = Locale(identifier: identifier)
        let live = ZapBarText.badges(state: .playing, presentation: nil, locale: locale)
        #expect(live.map(\.kind) == [.live])
        let catchUp = ZapBarText.badges(state: .playing, presentation: nil, catchUp: true, locale: locale)
        #expect(catchUp.map(\.kind) == [.catchUp])
    }

    @Test("localization/the-app-speaks-the-user-s-language the live badge reads in Spanish")
    func spanishLiveBadge() {
        let badges = ZapBarText.badges(state: .playing, presentation: nil, locale: Locale(identifier: "es_ES"))
        #expect(badges == [.init(kind: .live, text: "EN VIVO")])
    }
}
