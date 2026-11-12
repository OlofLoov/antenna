import Foundation
import Testing

@testable import AntennaCore

@Suite struct GroupRulesTests {
    static let aSport = CatalogueGroup.named(sourceA, "Sport")
    static let aNews = CatalogueGroup.named(sourceA, "News")
    static let bKids = CatalogueGroup.named(sourceB, "Kids")
    static let bDocs = CatalogueGroup.named(sourceB, "Docs")
    static let bSport = CatalogueGroup.named(sourceB, "Sport")

    /// Source A: Sport 101 102, News 201. Source B: Kids 301, Docs 401, Sport 501.
    static func channels() -> [Channel] {
        Channel.tagged(
            [
                channel("as0", group: "Sport", number: 101), channel("as1", group: "Sport", number: 102),
                channel("an0", group: "News", number: 201),
            ], sourceID: sourceA)
            + Channel.tagged(
                [
                    channel("bk0", group: "Kids", number: 301), channel("bd0", group: "Docs", number: 401),
                    channel("bs0", group: "Sport", number: 501),
                ], sourceID: sourceB)
    }

    static func build(_ rules: GroupRules, favorites: [Snapshot] = [], recents: [LastChannelKey] = []) -> TestCatalogue {
        TestCatalogue(channels: channels(), groupOrder: [:], favorites: favorites, recents: recents, rules: rules)
    }

    static func key(_ catalogue: TestCatalogue, _ id: String) throws -> RowKey {
        try #require(catalogue.rows(in: .all).first { $0.id == id } ?? catalogue.searchRows(includingHidden: true).first { $0.id == id })
    }

    @Test("channel-catalogue/group-list-and-order with no group rules every query matches a catalogue without them")
    func noRules() throws {
        let favorites = [Snapshot(channelID: "bd0", sourceID: sourceB, sortOrder: 0)]
        let recents = [LastChannelKey(sourceID: sourceA, channelID: "as1")]
        let plain = TestCatalogue(channels: Self.channels(), groupOrder: [:], favorites: favorites, recents: recents)
        let ruled = Self.build(GroupRules(), favorites: favorites, recents: recents)
        #expect(plain.groups == ruled.groups)
        for group in plain.groups {
            #expect(plain.rows(in: group) == ruled.rows(in: group))
        }
        for key in plain.rows(in: .all) {
            #expect(plain.number(for: key) == ruled.number(for: key))
            #expect(ruled.position(of: key, in: .all)?.0 == plain.position(of: key, in: .all)?.0)
        }
        #expect(plain.match(digits: "4") == ruled.match(digits: "4"))
        #expect(ruled.orphanedGroups.isEmpty && ruled.lockedGroups.isEmpty)
    }

    @Test("channel-catalogue/group-list-and-order the user's order, hidden and locked groups")
    func orderHiddenLocked() {
        let rules = GroupRules(hidden: [Self.aNews], locked: [Self.bDocs], order: [Self.bKids: 0, Self.aSport: 1])
        let catalogue = Self.build(rules)
        #expect(catalogue.groups == [.favorites, .all, Self.bKids, Self.aSport, Self.bSport])
        #expect(catalogue.lockedGroups == [Self.bDocs])
        #expect(catalogue.managedGroups == [.all, Self.bKids, Self.aSport, Self.aNews, Self.bDocs, Self.bSport])
    }

    @Test("group-management/hide-groups-you-never-watch a hidden group leaves the lists, keeps favorites and numbers")
    func hidden() throws {
        let favorites = [Snapshot(channelID: "an0", sourceID: sourceA, sortOrder: 0)]
        let plain = TestCatalogue(channels: Self.channels(), groupOrder: [:], favorites: favorites)
        let catalogue = Self.build(GroupRules(hidden: [Self.aNews]), favorites: favorites)
        #expect(!catalogue.groups.contains(Self.aNews))
        #expect(catalogue.managedGroups.contains(Self.aNews) && catalogue.isHidden(Self.aNews))
        #expect(!catalogue.rows(in: .all).contains { $0.id == "an0" })
        #expect(catalogue.rows(in: .favorites).map(\.id) == ["an0"])
        for key in plain.rows(in: .all) {
            #expect(catalogue.number(for: key) == plain.number(for: key))
        }
        #expect(catalogue.count(of: .all) == 5)
        #expect(catalogue.memberCount(of: Self.aNews) == 1)
    }

    @Test("group-management/hide-groups-you-never-watch search leaves hidden channels out unless turned on")
    func hiddenSearch() {
        let catalogue = Self.build(GroupRules(hidden: [Self.aNews]))
        #expect(!SearchChannel.all(in: catalogue).contains { $0.key.id == "an0" })
        #expect(SearchChannel.all(in: catalogue, includingHidden: true).contains { $0.key.id == "an0" })
    }

    @Test("group-management/hide-groups-you-never-watch All channels can be hidden but not locked")
    func hideAll() {
        #expect(
            Self.build(GroupRules(hidden: [.all])).groups == [.favorites, Self.aSport, Self.aNews, Self.bKids, Self.bDocs, Self.bSport])
        let locked = Self.build(GroupRules(locked: [.all, .favorites]))
        #expect(locked.groups.prefix(2) == [.favorites, .all])
        #expect(locked.count(of: .all) == 6)
    }

    @Test("group-management/put-groups-in-your-order groups follow the user's order, channels keep provider numbering")
    func order() {
        let rules = GroupRules(order: [Self.bSport: 0, Self.aNews: 1, Self.aSport: 2])
        let catalogue = Self.build(rules)
        #expect(catalogue.groups == [.favorites, .all, Self.bSport, Self.aNews, Self.aSport, Self.bKids, Self.bDocs])
        #expect(catalogue.rows(in: Self.aSport).map(\.id) == ["as0", "as1"])
        #expect(catalogue.rows(in: .all).map(\.id) == ["as0", "as1", "an0", "bk0", "bd0", "bs0"])
    }

    @Test("group-management/give-a-group-your-own-name a custom name shows, a blank one falls back")
    func names() {
        let own = UUID()
        let rules = GroupRules(
            names: [Self.aSport: "Football", Self.aNews: "  "], ownGroups: [GroupRules.OwnGroup(id: own, name: "Weekend")])
        let catalogue = Self.build(rules)
        #expect(catalogue.customName(of: Self.aSport) == "Football")
        #expect(catalogue.customName(of: Self.aNews) == nil)
        #expect(catalogue.customName(of: .own(own)) == "Weekend")
        #expect(catalogue.rows(in: Self.aSport).count == 2)
    }

    @Test("group-management/settings-for-groups-that-are-gone rules for missing groups of loaded sources are listed")
    func orphans() {
        let gone = CatalogueGroup.named(sourceA, "Sports")
        let notLoaded = CatalogueGroup.named(UUID(), "Movies")
        let rules = GroupRules(hidden: [gone, notLoaded], names: [.ungrouped(sourceB): "Misc"], order: [Self.aSport: 0])
        let catalogue = Self.build(rules)
        #expect(catalogue.orphanedGroups == [gone, .ungrouped(sourceB)])
        #expect(catalogue.groups.contains(Self.aSport))
    }

    @Test("group-management/build-your-own-group-from-any-playlist an own group lists channels from two sources in the user's order")
    func ownGroup() throws {
        let id = UUID()
        let members = [
            GroupRules.Member(channelID: "bs0", sourceID: sourceB), GroupRules.Member(channelID: "missing", sourceID: sourceB),
            GroupRules.Member(channelID: "as1", sourceID: sourceA), GroupRules.Member(channelID: "as1", sourceID: sourceA),
            GroupRules.Member(channelID: "bk0", sourceID: UUID()),
        ]
        let catalogue = Self.build(GroupRules(ownGroups: [GroupRules.OwnGroup(id: id, name: "Weekend", members: members)]))
        #expect(catalogue.groups.last == .own(id))
        #expect(catalogue.rows(in: .own(id)).map(\.id) == ["bs0", "as1"])
        let key = try Self.key(catalogue, "as1")
        #expect(catalogue.position(of: key, in: .own(id))! == (2, 2))
        #expect(catalogue.count(of: .all) == 6)
        #expect(GroupRules.canSave(channelID: "1234"))
        #expect(!GroupRules.canSave(channelID: "news#http://host/user/pass/1.ts"))
    }

    @Test("group-management/build-your-own-group-from-any-playlist an own group whose playlist is gone stays, empty")
    func ownGroupWithoutSource() {
        let id = UUID()
        let members = [GroupRules.Member(channelID: "x", sourceID: UUID())]
        let catalogue = Self.build(GroupRules(ownGroups: [GroupRules.OwnGroup(id: id, name: "Old", members: members)]))
        #expect(catalogue.groups.contains(.own(id)))
        #expect(catalogue.rows(in: .own(id)).isEmpty)
    }

    @Test("group-management/locked-channels-stay-out-of-reach locked channels are not shown, counted, numbered or matched")
    func locked() throws {
        let own = UUID()
        let favorites = [
            Snapshot(channelID: "bd0", sourceID: sourceB, sortOrder: 0), Snapshot(channelID: "as0", sourceID: sourceA, sortOrder: 1),
        ]
        let recents = [LastChannelKey(sourceID: sourceB, channelID: "bd0")]
        let ownGroup = GroupRules.OwnGroup(id: own, name: "Mine", members: [GroupRules.Member(channelID: "bd0", sourceID: sourceB)])
        let rules = GroupRules(locked: [Self.bDocs], ownGroups: [ownGroup])
        let catalogue = Self.build(rules, favorites: favorites, recents: recents)
        let docs = try Self.key(catalogue.replacingRules(GroupRules(ownGroups: [ownGroup])), "bd0")
        #expect(catalogue.isLocked(Self.bDocs) && catalogue.isLocked(docs))
        #expect(catalogue.lockedGroups == [Self.bDocs])
        #expect(!catalogue.groups.contains(Self.bDocs) && !catalogue.groups.contains(.recents))
        #expect(catalogue.rows(in: .favorites).map(\.id) == ["as0"])
        #expect(catalogue.rows(in: .own(own)).isEmpty && catalogue.rows(in: Self.bDocs).isEmpty)
        #expect(catalogue.count(of: .all) == 5 && catalogue.count(of: Self.bDocs) == 0)
        #expect(catalogue.number(for: docs) == nil && catalogue.position(of: docs, in: .all) == nil)
        #expect(catalogue.match(digits: "4") == nil)
        #expect(catalogue.match(digits: "5")?.id == "bs0")
        let others = try Self.key(catalogue, "bs0")
        #expect(catalogue.number(for: others) == 501)
        #expect(!SearchChannel.all(in: catalogue, includingHidden: true).contains { $0.key.id == "bd0" })

        let open = catalogue.replacingRules(GroupRules(locked: [Self.bDocs], ownGroups: [ownGroup], locksOpen: true))
        #expect(open.groups.contains(Self.bDocs) && open.lockedGroups.isEmpty)
        #expect(open.number(for: docs) == 401 && open.rows(in: .favorites).count == 2)
    }

    @Test("group-management/locked-channels-stay-out-of-reach a locked own group locks its channels everywhere")
    func lockedOwnGroup() throws {
        let own = UUID()
        let ownGroup = GroupRules.OwnGroup(id: own, name: "Mine", members: [GroupRules.Member(channelID: "as1", sourceID: sourceA)])
        let catalogue = Self.build(GroupRules(locked: [.own(own)], ownGroups: [ownGroup]))
        #expect(catalogue.rows(in: Self.aSport).map(\.id) == ["as0"])
        #expect(!catalogue.rows(in: .all).contains { $0.id == "as1" })
        let key = try Self.key(catalogue, "as0")
        #expect(catalogue.position(of: key, in: Self.aSport)! == (1, 1))
        #expect(catalogue.lockedGroups == [.own(own)])
    }

    @Test("group-management/a-channel-that-gets-locked-stops-playing the fallback group is never one behind the passcode")
    func fallback() {
        #expect(Self.build(GroupRules(hidden: [.all], locked: [Self.aSport])).fallbackGroup == Self.aNews)
        let everything: Set<CatalogueGroup> = [.all, Self.aSport, Self.aNews, Self.bKids, Self.bDocs, Self.bSport]
        #expect(Self.build(GroupRules(hidden: everything)).fallbackGroup == .favorites)
    }

    @Test("group-management/give-a-group-your-own-name an own group survives a relaunch as the watched group")
    func ownSession() {
        let id = UUID()
        let session = LiveSession(data: LiveSession(tab: .live, group: .own(id)).data)
        #expect(session.group?.group == .own(id))
    }

    @Test("group-management/changes-follow-you-to-every-device group keys survive a round trip and refuse junk")
    func storageKeys() {
        let groups: [CatalogueGroup] = [.all, .favorites, .recents, .named(sourceA, "Sport. HD"), .ungrouped(sourceB), .own(sourceA)]
        for group in groups {
            #expect(CatalogueGroup(storageKey: group.storageKey) == group)
        }
        for junk in ["", "named.x.Sport", "own", "own.\(sourceA.uuidString).x", "other"] {
            #expect(CatalogueGroup(storageKey: junk) == nil)
        }
    }
}
