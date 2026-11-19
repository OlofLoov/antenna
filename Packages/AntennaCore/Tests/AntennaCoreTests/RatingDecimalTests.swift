import Foundation
import Testing

@testable import AntennaCore

/// The provider's rating and the IMDb score keep their one decimal in the
/// viewer's language: a comma where the language writes one, Arabic-Indic
/// digits and the Arabic decimal mark in Saudi Arabic.
@Suite struct RatingDecimalTests {
    private func check(_ identifier: String, rating: String, imdb: String, spoken: String) {
        let locale = Locale(identifier: identifier)
        #expect(TitleMetadata.rating(7.4, locale: locale) == rating)
        #expect(TitleMetadata.spokenRating(7.4, locale: locale)?.withoutIsolates == spoken)
        #expect(Score(site: .imdb, value: 7.8, scale: 10).text(locale) == imdb)
        #expect(Score(site: .imdb, value: 7.8, scale: 10).spoken(locale)?.contains(imdb) == true)
    }

    @Test("localization/numbers-use-the-region-s-digits-and-separators English rating keeps the period")
    func english() {
        check("en_US", rating: "★ 7.4", imdb: "7.8", spoken: "rated 7.4 out of 10")
    }

    @Test("localization/numbers-use-the-region-s-digits-and-separators Swedish rating takes a comma")
    func swedish() {
        check("sv_SE", rating: "★ 7,4", imdb: "7,8", spoken: "betyg 7,4 av 10")
    }

    @Test("localization/numbers-use-the-region-s-digits-and-separators German rating takes a comma")
    func german() {
        check("de_DE", rating: "★ 7,4", imdb: "7,8", spoken: "bewertet mit 7,4 von 10")
    }

    @Test("localization/numbers-use-the-region-s-digits-and-separators Spanish rating takes a comma")
    func spanish() {
        check("es_ES", rating: "★ 7,4", imdb: "7,8", spoken: "valoración de 7,4 sobre 10")
    }

    @Test("localization/numbers-use-the-region-s-digits-and-separators French rating takes a comma")
    func french() {
        check("fr_FR", rating: "★ 7,4", imdb: "7,8", spoken: "noté 7,4 sur 10")
    }

    @Test("localization/numbers-use-the-region-s-digits-and-separators Brazilian Portuguese rating takes a comma")
    func portuguese() {
        check("pt_BR", rating: "★ 7,4", imdb: "7,8", spoken: "nota 7,4 de 10")
    }

    @Test("localization/numbers-use-the-region-s-digits-and-separators Saudi Arabic rating uses Arabic-Indic digits")
    func arabic() {
        check("ar_SA", rating: "★ ٧٫٤", imdb: "٧٫٨", spoken: "التقييم ٧٫٤ من 10")
        let tmdb = Score(site: .tmdb, value: 7.4, scale: 10).text(Locale(identifier: "ar_SA"))
        #expect(tmdb?.hasPrefix("٧٤") == true)
    }

    @Test("localization/numbers-use-the-region-s-digits-and-separators the banner writes the rating in the viewer's language")
    func banner() {
        let title = ShelfTitle(id: "xtream#h#vod#1", kind: .movie, sourceID: UUID(), name: "The Long Harbor", rating: 6.25)
        #expect(TitleMetadata.rating(6.25, locale: Locale(identifier: "de_DE")) == "★ 6,3")
        #expect(BannerText(title, details: nil).rating == TitleMetadata.rating(6.25))
    }
}
