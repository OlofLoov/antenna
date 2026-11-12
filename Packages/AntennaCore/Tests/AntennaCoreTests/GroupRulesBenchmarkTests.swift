import Foundation
import Testing

@testable import AntennaCore

/// The group policy's budget: applying rules to 50 000 channels takes at
/// most half again the catalogue build. Run with `ANTENNA_BENCHMARKS=1 swift test`.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["ANTENNA_BENCHMARKS"] == "1"))
struct GroupRulesBenchmarkTests {
    @Test("channel-catalogue/group-list-and-order the group policy over 50 000 channels costs at most 1.5 times the build")
    func fiftyThousand() {
        let source = UUID()
        let channels = Channel.tagged(
            (0..<50_000).map { index in
                Channel(
                    id: "\(index)", name: "Channel \(index)", streamURL: URL(filePath: "/\(index)"), group: "G\(index % 400)",
                    number: index + 1)
            }, sourceID: source)
        let own = GroupRules.OwnGroup(
            id: UUID(), name: "Mine", members: (0..<200).map { GroupRules.Member(channelID: "\($0 * 7)", sourceID: source) })
        let rules = GroupRules(
            hidden: Set((0..<40).map { CatalogueGroup.named(source, "G\($0)") }),
            locked: Set((40..<80).map { CatalogueGroup.named(source, "G\($0)") }).union([.own(own.id)]),
            names: [.named(source, "G1"): "One"],
            order: Dictionary(uniqueKeysWithValues: (0..<400).map { (CatalogueGroup.named(source, "G\($0)"), 400 - $0) }),
            ownGroups: [own])
        let clock = ContinuousClock()
        var catalogue = Catalogue<Int>(channels: [], groupOrder: [:], favorites: [])
        let build = clock.measure { catalogue = Catalogue<Int>(channels: channels, groupOrder: [:], favorites: []) }
        let policy = clock.measure { _ = catalogue.replacingRules(rules) }
        #expect(policy <= build * 1.5, "build took \(build), policy took \(policy)")
    }
}
