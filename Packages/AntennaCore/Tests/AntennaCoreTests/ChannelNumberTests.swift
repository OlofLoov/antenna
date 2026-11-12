import Foundation
import Testing

@testable import AntennaCore

@Suite struct ChannelNumberTests {
    private func numbered(_ id: String, _ major: Int, _ minor: Int? = nil) -> Channel {
        var made = channel(id, group: "Antenna", number: major)
        made.minorNumber = minor
        return made
    }

    @Test("channel-catalogue/numbers-with-a-part-after-the-dot ordering over-the-air numbers")
    func ordersMajorThenMinor() {
        let input = Channel.tagged(
            [numbered("six-two", 6, 2), numbered("six-one", 6, 1), numbered("seven", 7), numbered("six", 6)], sourceID: sourceA)
        let catalogue = TestCatalogue(channels: input, groupOrder: [:], favorites: [])
        let all = catalogue.rows(in: .all)
        #expect(all.map(\.id) == ["six", "six-one", "six-two", "seven"])
        #expect(all.compactMap { catalogue.channelNumber(for: $0)?.description } == ["6", "6.1", "6.2", "7"])
        #expect(catalogue.rows(in: .named(sourceA, "Antenna")).map(\.id) == ["six", "six-one", "six-two", "seven"])
        #expect(catalogue.match(digits: "6")?.id == "six")
    }

    @Test("channel-catalogue/numbers-with-a-part-after-the-dot typing the major number finds the first minor")
    func numberEntryUsesMajor() {
        let input = Channel.tagged([numbered("six-two", 6, 2), numbered("six-one", 6, 1), numbered("eight", 8)], sourceID: sourceA)
        let catalogue = TestCatalogue(channels: input, groupOrder: [:], favorites: [])
        #expect(catalogue.match(digits: "6")?.id == "six-one")
        #expect(catalogue.number(for: catalogue.rows(in: .all)[1]) == 6)
    }

    @Test("channel-catalogue/numbers-with-a-part-after-the-dot a minor number counts only with its provider number")
    func minorNeedsProviderNumber() throws {
        var outOfRange = numbered("big", 200_000, 1)
        outOfRange.name = "Big"
        let input = Channel.tagged([numbered("one", 1), outOfRange], sourceID: sourceA)
        let catalogue = TestCatalogue(channels: input, groupOrder: [:], favorites: [])
        let big = try #require(catalogue.rows(in: .all).last)
        #expect(catalogue.channelNumber(for: big) == ChannelNumber(major: 2))
    }

    @Test("channel-catalogue/numbers-with-a-part-after-the-dot shown with and without the part after the dot")
    func description() {
        #expect(ChannelNumber(major: 6, minor: 1).description == "6.1")
        #expect(ChannelNumber(major: 6000).description == "6000")
        #expect(ChannelNumber(major: 6) < ChannelNumber(major: 6, minor: 0))
        #expect(ChannelNumber(major: 6, minor: 9) < ChannelNumber(major: 7))
    }
}
