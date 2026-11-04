import Foundation
import Testing

@testable import AntennaCore

/// Loads a file from `Fixtures/Xtream`.
func xtreamFixture(_ name: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures/Xtream"))
    return try Data(contentsOf: url)
}

@Suite struct XtreamVODDecodingTests {
    private let host = "H"

    private func vodRow(_ fields: String) throws -> VODItem {
        let list = try XtreamClient.decodeVODList(Data("[{\"name\":\"Dune\",\"stream_id\":55\(fields)}]".utf8), host: host)
        return try #require(list.items.first)
    }

    @Test("0016/AC-2 VOD item fields")
    func vodItemFields() throws {
        let list = try XtreamClient.decodeVODList(try xtreamFixture("vod_streams.json"), host: host)
        let item = try #require(list.items.first)
        #expect(item.streamID == 55)
        #expect(item.id == "xtream#H#vod#55")
        #expect(item.name == "Dune")
        #expect(item.posterURL == URL(string: "http://h/p.jpg"))
        #expect(item.added == Date(timeIntervalSince1970: 1_730_600_000))
        #expect(item.rating == 7.4)
        #expect(item.containerExtension == "mkv")
        #expect(item.categoryID == "12")
        #expect(list.items.count == 2)
        #expect(list.skipped == 0)
    }

    @Test(
        "0016/AC-2a ids accept number or string",
        arguments: [
            (#""stream_id":55,"category_id":12"#), (#""stream_id":"55","category_id":"12""#),
            (#""stream_id":55,"category_id":"12""#), (#""stream_id":"55","category_id":12"#),
        ])
    func looseIDs(fields: String) throws {
        let list = try XtreamClient.decodeVODList(Data("[{\"name\":\"Dune\",\(fields)}]".utf8), host: host)
        let item = try #require(list.items.first)
        #expect(item.streamID == 55)
        #expect(item.categoryID == "12")
    }

    @Test(
        "0016/AC-2a added and rating loose forms",
        arguments: [
            (#"1730600000"#, #"7.4"#, true), (#""1730600000""#, #""7.4""#, true), (#""N/A""#, #""N/A""#, false),
            (#""""#, #""""#, false), ("null", "null", false),
        ])
    func looseAddedAndRating(added: String, rating: String, present: Bool) throws {
        let item = try vodRow(",\"added\":\(added),\"rating\":\(rating)")
        #expect(item.added == (present ? Date(timeIntervalSince1970: 1_730_600_000) : nil))
        #expect(item.rating == (present ? 7.4 : nil))
    }

    @Test("0016/AC-2a rating 0 is nil", arguments: ["0", #""0""#])
    func zeroRating(rating: String) throws {
        #expect(try vodRow(",\"rating\":\(rating)").rating == nil)
    }

    @Test(
        "0016/AC-2b only http and https URLs with a host",
        arguments: [
            ("http://h/p.jpg", true), ("https://h/p.jpg", true), ("ftp://h/p", false), ("//h/p", false), ("p.jpg", false),
            ("", false), ("http://", false),
        ])
    func posterURLRule(icon: String, valid: Bool) throws {
        let item = try vodRow(",\"stream_icon\":\"\(icon)\"")
        #expect(item.posterURL == (valid ? URL(string: icon) : nil))

        let series = try XtreamClient.decodeSeriesList(Data(#"[{"name":"Dark","series_id":7,"cover":"\#(icon)"}]"#.utf8), host: host)
        #expect(try #require(series.items.first).posterURL == (valid ? URL(string: icon) : nil))

        let info = try XtreamClient.decodeVODInfo(Data(#"{"info":{"backdrop_path":["\#(icon)"]}}"#.utf8), host: host)
        #expect(info.backdropURLs == (valid ? [try #require(URL(string: icon))] : []))
    }

    @Test(
        "0016/AC-3 unparseable added is nil and never traps",
        arguments: [#""0""#, #""""#, "null", #""abc""#, #""nan""#, #""inf""#, #""-inf""#, #""1e400""#, "1e400", "99999999999999999999"])
    func unparseableAdded(added: String) throws {
        #expect(try vodRow(",\"added\":\(added)").added == nil)
    }

    @Test("0016/AC-4 broken and duplicate rows are skipped and counted")
    func brokenRows() throws {
        let list = try XtreamClient.decodeVODList(try xtreamFixture("vod_streams_broken.json"), host: host)
        #expect(list.items.map(\.name) == ["First", "Second", "Third"])
        #expect(list.items.map(\.streamID) == [1, 2, 4])
        #expect(list.skipped == 6)
        let second = list.items[1]
        #expect(second.rating == nil)
        #expect(second.added == nil)
        #expect(second.posterURL == nil)
        #expect(second.categoryID == nil)
    }

    @Test(
        "0016/AC-4 series rows skip on series_id", arguments: [#"{"name":"A"}"#, #"{"name":"A","series_id":"nan"}"#, #"{"series_id":2}"#])
    func brokenSeriesRows(row: String) throws {
        let list = try XtreamClient.decodeSeriesList(Data("[{\"name\":\"Dark\",\"series_id\":7},\(row)]".utf8), host: host)
        #expect(list.items.map(\.seriesID) == [7])
        #expect(list.skipped == 1)
    }

    @Test(
        "0016/AC-4a non-array list body throws decoding with an empty path",
        arguments: [#"{"error":"Invalid request","detail":"ask your provider"}"#, #""unexpected text from the panel""#, "true", "html"])
    func nonArrayListBody(body: String) throws {
        let data = body == "html" ? try xtreamFixture("html_login.html") : Data(body.utf8)
        for decode in [
            { _ = try XtreamClient.decodeVODList(data, host: host) }, { _ = try XtreamClient.decodeSeriesList(data, host: host) },
        ] as [() throws -> Void] {
            let error = #expect(throws: XtreamClient.XtreamError.self) { try decode() }
            #expect(error == .decoding(path: ""))
            #expect(!sharesEightBytes(String(reflecting: try #require(error)), with: data))
        }
    }

    @Test("0016/AC-4a nested failures name the dotted coding path")
    func nestedPath() throws {
        let body = Data(#"[{"category_id":1,"category_name":"A"},{"category_id":2,"category_name":"B"}, {"category_id":3}]"#.utf8)
        let error = #expect(throws: XtreamClient.XtreamError.self) {
            _ = try XtreamClient.decode([XtreamCategory].self, from: body)
        }
        #expect(error == .decoding(path: "[2].category_name"))
    }

    @Test("0016/AC-5 VOD info fields")
    func vodInfoFields() throws {
        let info = try XtreamClient.decodeVODInfo(try xtreamFixture("vod_info.json"), host: host)
        #expect(info.plot == "A desert")
        #expect(info.year == 2024)
        #expect(info.duration == 7680)
        #expect(info.genre == "Sci-Fi")
        #expect(info.ageRating == "15")
        #expect(info.backdropURLs == [try #require(URL(string: "http://h/b1.jpg"))])
        #expect(info.containerExtension == "mkv")
    }

    @Test(
        "0016/AC-5 duration rule",
        arguments: [
            (#""duration_secs":7680"#, 7680.0), (#""duration_secs":"7680""#, 7680), (#""duration":"02:08:00""#, 7680),
            (#""duration_secs":0,"duration":"02:08:00""#, 7680), (#""duration_secs":"N/A","duration":"128:00""#, 7680),
            (#""duration":"00:00:00""#, nil), (#""duration":"2h""#, nil), (#""duration_secs":-5"#, nil), ("", nil),
        ] as [(String, TimeInterval?)])
    func durationRule(fields: String, expected: TimeInterval?) throws {
        let info = try XtreamClient.decodeVODInfo(Data("{\"info\":{\(fields)}}".utf8), host: host)
        #expect(info.duration == expected)
    }

    @Test(
        "0016/AC-5 year rule",
        arguments: [
            (#""releasedate":"2024-03-01""#, 2024), (#""release_date":"1999""#, 1999), (#""releaseDate":"2001-01-01""#, 2001),
            (#""releasedate":"","release_date":"2010-05-05""#, 2010), (#""releasedate":"0000-00-00""#, nil),
            (#""releasedate":"March 2024","releaseDate":"2024""#, nil), (#""releasedate":2024"#, nil),
        ] as [(String, Int?)])
    func yearRule(fields: String, expected: Int?) throws {
        let info = try XtreamClient.decodeVODInfo(Data("{\"info\":{\(fields)}}".utf8), host: host)
        #expect(info.year == expected)
    }

    @Test(
        "0016/AC-5 info shapes, single backdrop and numeric age",
        arguments: [
            #"{"movie_data":{"container_extension":"mkv"}}"#, #"{"info":{},"movie_data":{"container_extension":"mkv"}}"#,
            #"{"info":[],"movie_data":{"container_extension":"mkv"}}"#,
        ])
    func infoShapes(body: String) throws {
        let info = try XtreamClient.decodeVODInfo(Data(body.utf8), host: host)
        #expect(info == VODInfo(containerExtension: "mkv"))
        #expect(try XtreamClient.decodeVODInfo(Data(#"{"info":{}}"#.utf8), host: host).containerExtension == nil)
        let other = try XtreamClient.decodeVODInfo(Data(#"{"info":{"age":12,"backdrop_path":"https://h/b.jpg"}}"#.utf8), host: host)
        #expect(other.ageRating == "12")
        #expect(other.backdropURLs == [try #require(URL(string: "https://h/b.jpg"))])
    }

    @Test("0016/AC-12 empty list and info shapes", arguments: ["[]", "{}", "false", "null"])
    func emptyShapes(body: String) throws {
        let data = Data(body.utf8)
        #expect(try XtreamClient.decodeVODList(data, host: host) == XtreamClient.DecodedList(items: [], skipped: 0))
        #expect(try XtreamClient.decodeSeriesList(data, host: host) == XtreamClient.DecodedList(items: [], skipped: 0))
        #expect(try XtreamClient.decodeVODInfo(data, host: host) == VODInfo())
        let series = try XtreamClient.decodeSeriesInfo(data, host: host)
        #expect(series == SeriesInfo())
        #expect(series.episodes.isEmpty && series.seasonCount == 0 && series.skippedEpisodes == 0)
    }

    @Test("0016/AC-12 other non-object info bodies throw", arguments: ["[1]", #""text""#, "true", "42", "html"])
    func nonObjectInfo(body: String) throws {
        let data = body == "html" ? try xtreamFixture("html_login.html") : Data(body.utf8)
        #expect(throws: XtreamClient.XtreamError.decoding(path: "")) { _ = try XtreamClient.decodeVODInfo(data, host: host) }
        #expect(throws: XtreamClient.XtreamError.decoding(path: "")) { _ = try XtreamClient.decodeSeriesInfo(data, host: host) }
    }

    /// Benchmark, not CI-gated. Run with `ANTENNA_BENCHMARKS=1`.
    /// Reference machine: Apple M1, 16 GB, debug build (the 0013/AC-14 baseline).
    @Test(
        "0016/AC-9 50 000 VOD rows decode within 500 ms",
        .enabled(if: ProcessInfo.processInfo.environment["ANTENNA_BENCHMARKS"] == "1"))
    func decodeSpeed() throws {
        let template = (0..<20).map { i in
            #"{"num":\#(i),"name":"Movie \#(i)","stream_type":"movie","stream_id":ID,"#
                + #""stream_icon":"http://img.example/p\#(i).jpg","rating":"\#(i % 10).5","rating_5based":3.2,"#
                + #""added":"17306\#(i)0000","category_id":"\#(i % 7)","container_extension":"mkv","custom_sid":"","direct_source":""}"#
        }
        let rows = (0..<50_000).map { template[$0 % 20].replacingOccurrences(of: "ID", with: String($0)) }
        let data = Data(("[" + rows.joined(separator: ",") + "]").utf8)

        var list = XtreamClient.DecodedList<VODItem>(items: [], skipped: 0)
        let elapsed = try ContinuousClock().measure { list = try XtreamClient.decodeVODList(data, host: host) }
        #expect(list.items.count == 50_000)
        #expect(elapsed < .milliseconds(500), "took \(elapsed)")
    }
}

/// True when `text` contains any run of eight or more bytes from `body`.
func sharesEightBytes(_ text: String, with body: Data) -> Bool {
    let haystack = Data(text.utf8)
    guard body.count >= 8 else { return false }
    return (0...(body.count - 8)).contains { start in
        haystack.range(of: body.subdata(in: start..<(start + 8))) != nil
    }
}
