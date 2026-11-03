import Foundation
import Testing
@testable import AntennaCore

@Suite struct XMLTVParserTests {
    @Test func parsesProgrammesAndDropsInvalid() throws {
        let url = try #require(Bundle.module.url(forResource: "sample.xmltv", withExtension: nil, subdirectory: "Fixtures"))
        let result = try XMLTVParser().parse(try Data(contentsOf: url))

        #expect(result.channelNames["SkySportsF1.uk"] == "Sky Sports F1")
        #expect(result.programmes.count == 1, "programme with stop before start is dropped")

        let gp = try #require(result.programmes.first)
        #expect(gp.title == "Grand Prix Live")
        #expect(gp.subtitle == "São Paulo")
        #expect(gp.category == "Sport")
        #expect(gp.iconURL?.absoluteString == "http://img/gp.jpg")
        #expect(gp.stop.timeIntervalSince(gp.start) == 7200)
        #expect(gp.isAiring(at: gp.start.addingTimeInterval(60)))
    }
}
