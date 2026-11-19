import Foundation
import Testing

@testable import AntennaCore

@Suite struct XtreamRatingTests {
    private let host = "H"

    private func movie(_ fields: String) throws -> VODItem {
        let list = try XtreamClient.decodeVODList(Data("[{\"name\":\"Dune\",\"stream_id\":55\(fields)}]".utf8), host: host)
        return try #require(list.items.first)
    }

    private func series(_ fields: String) throws -> Series {
        let list = try XtreamClient.decodeSeriesList(Data("[{\"name\":\"Dark\",\"series_id\":7\(fields)}]".utf8), host: host)
        return try #require(list.items.first)
    }

    private func info(_ fields: String) throws -> VODInfo {
        try XtreamClient.decodeVODInfo(Data("{\"info\":{\"plot\":\"x\"\(fields)}}".utf8), host: host)
    }

    @Test("xtream-vod-client/ratings-on-a-ten-point-scale both fields: rating wins")
    func bothFields() throws {
        #expect(try movie(#","rating":"7.4","rating_5based":3.7"#).rating == 7.4)
        let fixture = try XtreamClient.decodeVODList(try xtreamFixture("vod_streams.json"), host: host)
        #expect(fixture.items.first?.rating == 7.4)
    }

    @Test("xtream-vod-client/ratings-on-a-ten-point-scale only the five-point field is doubled")
    func fivePoint() throws {
        #expect(try movie(#","rating_5based":"3.6""#).rating == 7.2)
        #expect(try series(#","rating_5based":"3.6""#).rating == 7.2)
        #expect(try info(#","rating_5based":"3.6""#).rating == 7.2)
        let body = Data(#"{"info":{"rating":"","rating_5based":3.6},"episodes":[]}"#.utf8)
        #expect(try XtreamClient.decodeSeriesInfo(body, host: host).rating == 7.2)
    }

    @Test("xtream-vod-client/ratings-on-a-ten-point-scale a series row reads its rating")
    func seriesRow() throws {
        #expect(try series(#","rating":"8.1""#).rating == 8.1)
        let list = try XtreamClient.decodeSeriesList(try xtreamFixture("series.json"), host: host)
        let dark = try #require(list.items.first)
        #expect(dark.rating == 8)
        #expect(ShelfTitle(series: dark, sourceID: UUID(), categories: [:]).rating == 8)
    }

    @Test("xtream-vod-client/ratings-on-a-ten-point-scale values above their scale or 0 give none")
    func outOfScale() throws {
        #expect(try movie(#","rating":74"#).rating == nil)
        #expect(try movie(#","rating_5based":7"#).rating == nil)
        #expect(try movie(#","rating":0,"rating_5based":0"#).rating == nil)
        #expect(try movie(#","rating":"N/A""#).rating == nil)
        #expect(try movie(#","rating":74,"rating_5based":3.7"#).rating == 7.4)
    }
}

@Suite struct BannerRatingTests {
    private let one = UUID()

    private func movie(rating: Double? = nil) -> ShelfTitle {
        ShelfTitle(id: "xtream#h#vod#1", kind: .movie, sourceID: one, name: "The Long Harbor", rating: rating)
    }

    @Test("movies-and-series-browsing/rating-and-trailer-on-the-banner a rated movie ends its facts with the star")
    func ratedMovie() {
        let text = BannerText(movie(), details: ShelfDetails(year: 2024, duration: 128 * 60, rating: 7.4))
        #expect(text.facts == ["2024", "2 h 08 min", "★ 7.4"])
        #expect(text.facts.joined(separator: " · ") == "2024 · 2 h 08 min · ★ 7.4")
        #expect(text.rating == "★ 7.4")
        #expect(text.spokenRating == "rated 7.4 out of 10")
    }

    @Test("movies-and-series-browsing/rating-and-trailer-on-the-banner the row's rating shows before the info call answers")
    func ratingBeforeDetails() {
        #expect(BannerText(movie(rating: 6.25), details: nil).facts == ["★ 6.3"])
        let answered = BannerText(movie(rating: 6.2), details: ShelfDetails(year: 2024, rating: 7.4))
        #expect(answered.facts == ["2024", "★ 7.4"])
        #expect(BannerText(movie(rating: 6.2), details: ShelfDetails(year: 2024)).facts == ["2024", "★ 6.2"])
    }

    @Test("movies-and-series-browsing/rating-and-trailer-on-the-banner no rating, no star")
    func noRating() {
        let text = BannerText(movie(rating: 0), details: ShelfDetails(year: 2024, rating: nil))
        #expect(text.facts == ["2024"])
        #expect(text.rating == nil && text.spokenRating == nil)
    }

    @Test("movies-and-series-browsing/rating-and-trailer-on-the-banner details carry the info call's rating and trailer")
    func detailsFromInfo() {
        let trailer = URL(string: "https://h/t.m3u8")
        let details = ShelfDetails(movie: VODInfo(rating: 7.4, trailerURL: trailer))
        #expect(details.rating == 7.4 && details.trailerURL == trailer)
        let series = ShelfDetails(series: SeriesInfo(rating: 8.1, trailerURL: trailer))
        #expect(series.rating == 8.1 && series.trailerURL == trailer)
        #expect(TitleMetadata.spokenRating(8.05, locale: Locale(identifier: "en_US")) == "rated 8.1 out of 10")
        #expect(TitleMetadata.spokenRating(0, locale: Locale(identifier: "en_US")) == nil)
    }
}
